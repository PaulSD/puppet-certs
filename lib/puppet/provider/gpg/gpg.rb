require 'fileutils'
Puppet::Type.type(:gpg).provide(:gpg) do

  initvars

  commands :rpm => 'rpm'
  commands :yum => 'yum'
  commands :gpg => 'gpg'
  commands :katello_certs_gen_rpm => 'katello-certs-gen-rpm'

  def exists?
    ! generate? && ! deploy?
  end

  def create
    generate! if generate?
    deploy!   if deploy?
  end

  protected

  def generate?
    return false unless resource[:generate]
    return true if resource[:regenerate_ca]
    return true if resource[:subkey] and resource[:regenerate]
    return !existing_rpms.any?
  end

  def generate!
    if !gpg_exists?(build_pri_gpg) or resource[:regenerate_ca]
      if resource[:existing_gpg] and gpg_exists?(existing_gpg)
        copy_gpg(existing_gpg, build_pri_gpg)
      else
        # Generate GPG primary key
        prep_new_gpg(build_pri_gpg)
        gpg_batch_script = \
         "Key-Type: #{resource[:gpg_key_type]}\n" \
         "Key-Length: #{resource[:gpg_key_length]}\n" \
         "Expire-Date: #{resource[:gpg_expire_date]}\n" \
         "#{(resource[:gpg_name] ? "Name-Real: #{resource[:gpg_name]}\n" : '')}" \
         "#{(resource[:gpg_comment] ? "Name-Comment: #{resource[:gpg_comment]}\n" : '')}" \
         "#{(resource[:gpg_email] ? "Name-Email: #{resource[:gpg_email]}\n" : '')}" \
         "%no-protection\n" \
         "%commit\n"
        gpg.execpipe('--homedir', build_pri_gpg, '--batch', '--gen-key') do |stdin|
          stdin.write(gpg_batch_script)
          stdin.close
        end
      end
    end

    pub_file = File.join(build_pri_gpg, resource[:deploy_pub_file])
    # pub_file is deleted by copy_gpg() or prep_new_gpg() if :regenerate_ca
    unless File.exist?(pub_file)
      # Export public GPG primary key
      gpg('--homedir', build_pri_gpg, '--armor', '--export', pri_gpg_id, '--output', pub_file)
    end

    regen_sub = resource[:regenerate_ca] or resource[:regenerate]
    if resource[:subkey] and (!gpg_exists?(build_sub_gpg) or regen_sub)
      if resource[:existing_sub] and gpg_exists?(existing_sub)
        copy_gpg(existing_sub, build_sub_gpg)
      else
        # Generate GPG subkey in the primary keyring
        gpg_args = [
         '--homedir', build_pri_gpg,
         '--batch',
         '--command-fd', '0',
         # To view notations: `gpg --list-sigs --list-options show-notations`
         '--cert-notation', "comment_en@openpgp-notations.org=#{resource[:hostname]}",
         '--edit-key', pri_gpg_id,
         'addkey',
         'save',
        ]
        gpg_input = \
         "#{resource[:sub_key_type]}\n" \
         "#{resource[:sub_key_length]}\n" \
         "#{resource[:sub_expire_date]}\n"
        gpg.execpipe(*args) do |stdin|
          stdin.write(gpg_input)
          stdin.close
        end

        # Export public/private subkey and public primary key
        exec_options = {:failonfail => true, :combine => false}
        gpg_args = [
         '--homedir', build_pri_gpg,
         '--export-secret-subkeys', "#{sub_gpg_id}!",
        ]
        exported_subkey = gpg(*args, options=exec_options)
        if exported_subkey.empty?
          # gpg < 2.1.13 cannot export unprotected keys.  To work around this,
          # create a temporary copy of the keyring with a passphrase.
          # See: https://dev.gnupg.org/T2324
          copy_gpg(build_pri_gpg, build_sub_gpg)
          gpg_args = [
           '--homedir', build_sub_gpg,
           '--batch',
           '--passphrase', 'x',
           '--passwd', pri_gpg_id
          ]
          gpg(*args)
          gpg_args = [
           '--homedir', build_sub_gpg,
           '--export-options', 'export-reset-subkey-passwd',
           '--export-secret-subkeys', "#{sub_gpg_id}!",
          ]
          exported_subkey = gpg(*args, options=exec_options)
        end

        # Import subkey into a host-specific keyring
        prep_new_gpg(build_sub_gpg)
        gpg.execpipe('--homedir', build_sub_gpg, '--import') do |stdin|
          stdin.write(exported_subkey)
          stdin.close
        end
      end
    end

    # Generate a host-specific RPM
    # (Containing either the primary keyring or the host-specific keyring
    # depending on the value of :subkey)
    build_gpg = (resource[:subkey] ? build_sub_gpg : build_pri_gpg)
    rpm_args = [
     '--name', rpm_base_filename,
     '--version', (existing_rpms.map { |r| version_from_rpm_filename(r) }.max || 1),
     '--summary', "#{resource[:name]} for #{resource[:hostname]}",
     '--description', "#{resource[:name]} for #{resource[:hostname]}",
     gpg_rpm_filespec(build_gpg, [], '0700'),
     gpg_rpm_filespec(build_gpg, ['*'], '0600'),
    ]
    if resource[:subkey]
      # Include public GPG key file from primary keyring directory
      rpm_args << [
       gpg_rpm_filespec(build_pri_gpg, [resource[:deploy_pub_file]], '0600'),
      ]
    end
    if File.exist?(File.join(build_gpg, 'private-keys-v1.d'))
      rpm_args << [
       gpg_rpm_filespec(build_gpg, ['private-keys-v1.d'], '0700'),
       gpg_rpm_filespec(build_gpg, ['private-keys-v1.d', '*'], '0600'),
      ]
    end
    Dir.chdir(rpm_path) do
      katello_certs_gen_rpm(*rpm_args)
    end
  end

  def prep_new_gpg(gpg)
    prep_gpg(gpg)
    FileUtils.mkdir_p(File.dirname(gpg), mode=0700)
    config_gpg(gpg)
  end

  def copy_gpg(source_gpg, dest_gpg)
    prep_gpg(dest_gpg)
    FileUtils.cp_r(source_gpg, dest_gpg, true)
    parent_dir = File.stat(File.dirname(dest_gpg))
    FileUtils.chown_R(parent_dir.uid, parent_dir.gid, dest_gpg)
    FileUtils.chmod_R('go-rwx', dest_gpg)
    config_gpg(dest_gpg)
  end

  def prep_gpg(gpg)
    begin
      FileUtils.remove_dir(gpg)
    rescue Errno::ENOENT
      # Ignore non-existent path errors
    end
    FileUtils.mkdir_p(File.dirname(gpg))
  end

  def config_gpg(gpg)
    config_file = File.join(gpg, 'gpg.conf')
    File.delete(config_file)
    gpg_config = <<~END
      # Digest algorithm used for creating and signing (certifying) keys
      cert-digest-algo SHA512
      # Default "setpref" setting for new keys
      default-preference-list SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed
      # Digest algorithm preferences for signing/encrypting data
      personal-digest-preferences SHA512 SHA384 SHA256
      # Cipher algorithm preferences for signing/encrypting data
      personal-cipher-preferences AES256 AES192 AES
    END
    File.open(config_file, 'w', 0600) { |f| f.write(gpg_config) }
  end

  def gpg_rpm_filespec(source, file_components, mode)
    dest = resource[:deploy_gpg]
    dest = File.join(dest, *file_components) unless file_components.empty?
    user = resource[:deploy_user]
    group = resource[:deploy_group]
    src = File.join(source, *file_components) unless file_components.empty?
    "#{dest}:#{mode},#{user},#{group}=#{src}"
  end

  def deploy?
    return false unless resource[:deploy]
    return true if resource[:regenerate_ca]
    return true if resource[:subkey] and resource[:regenerate]
    return true unless gpg_exists?(resource[:deploy_gpg])
    pub_file = File.join(resource[:deploy_gpg], resource[:deploy_pub_file])
    return true unless File.exist?(pub_file)
    rpm_file = latest_rpm
    if rpm_file
      !system("rpm --verify -p #{rpm_file} &>/dev/null")
    else
      `yum check-update #{rpm_base_filename} &>/dev/null`
      $?.exitstatus == 100
    end
  end

  def deploy!
    if(system("rpm -q #{rpm_base_filename} &>/dev/null"))
      rpm('-e', rpm_base_filename)
    end
    rpm_file = latest_rpm
    if File.exist?(rpm_file)
      rpm('-Uvh', '--force', rpm_file)
    else
      yum('install', '-y', rpm_base_filename)
    end
  end

  def build_pri_gpg
    File.join(resource[:build_dir], resource[:name])
  end

  def build_sub_gpg
    File.join(resource[:build_dir], resource[:hostname], resource[:name])
  end

  def gpg_exists?(gpg)
    File.exist?(File.join(gpg, 'pubring.gpg')) and \
    (File.exist?(File.join(gpg, 'secring.gpg')) or \
     File.exist?(File.join(gpg, 'private-keys-v1.d')))
  end

  def pri_gpg_id
    output = gpg('--homedir', build_pri_gpg, '--list-secret-keys', '--with-colons')
    # If the keyring contains multiple primary keys (highly unlikely, and only
    # possible with user-supplied keyrings), use the last one listed in the
    # output (the last one should be the newest one)
    /.*^sec:[^:]*:[^:]*:[^:]*:(?<id>[^:]+):/m =~ output
    return id
  end

  def sub_gpg_id
    output = gpg('--homedir', build_pri_gpg, '--list-secret-keys', '--with-colons')
    # The last subkey in the list should be the newest one
    /.*^ssb:[^:]*:[^:]*:[^:]*:(?<id>[^:]+):/m =~ output
    return id
  end

  def latest_rpm
    existing_rpms.max_by { |f| version_from_rpm_filename(f) }
  end

  def version_from_rpm_filename(rpm_file)
    rpm_file.scan(/\d+/).map(&:to_i)
  end

  def existing_rpms
    Dir[File.join(rpm_path, rpm_base_filename) + '-[0-9].*noarch.rpm']
  end

  def rpm_path
    File.join(resource[:build_dir], resource[:hostname])
  end

  def rpm_base_filename
    "#{resource[:hostname]}-#{resource[:name]}"
  end

end
