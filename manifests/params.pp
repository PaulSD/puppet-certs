# Certs Parameters
class certs::params {

  $log_dir = '/var/log/certs'
  $pki_dir = '/etc/pki/katello'
  $ssl_build_dir = '/root/ssl-build'

  $node_fqdn = $facts['fqdn']
  $cname = []

  $custom_repo = false

  $ca_common_name = $facts['fqdn']  # we need fqdn as CA common name as candlepin uses it as a ssl cert
  $generate      = true
  $regenerate    = false
  $regenerate_ca = false
  $deploy        = true

  $default_ca_name = 'katello-default-ca'
  $server_ca_name  = 'katello-server-ca'

  $country       = 'US'
  $state         = 'North Carolina'
  $city          = 'Raleigh'
  $org           = 'Katello'
  $org_unit      = 'SomeOrgUnit'
  $expiration    = '7300' # 20 years
  $ca_expiration = '36500' # 100 years

  $keystore_password_file = 'keystore_password-file'

  $user = 'root'
  $group = 'root'

  $server_cert      = undef
  $server_key       = undef
  $server_cert_req  = undef
  $server_ca_cert   = undef

  $repomd_gpg                  = undef
  $repomd_gpg_name             = 'Repository Metadata Signing Key'
  $repomd_gpg_comment          = undef
  $repomd_gpg_email            = undef
  # primary key type is used as a gpg Key-Type batch parameter:
  # https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
  $repomd_gpg_key_type         = 'RSA'
  $repomd_gpg_key_length       = '4096'
  $repomd_gpg_expire_date      = '0'
  $repomd_gpg_use_subkeys      = false
  $repomd_gpg_sub              = undef
  # If more than one subkey is used (as is necessary for this use case), then
  # gpg batch parameters cannot be used for subkeys, and the subkey type must be
  # entered into the gpg interactive prompt:
  #   Please select what kind of key you want:
  #   (3) DSA (sign only)
  #   (4) RSA (sign only)
  #   (5) Elgamal (encrypt only)
  #   (6) RSA (encrypt only)
  # Unfortunately, this means that repomd_gpg_key_type and
  # repomd_gpg_sub_key_type require different inputs to select the same type.
  $repomd_gpg_sub_key_type     = '4'
  $repomd_gpg_sub_key_length   = '4096'
  $repomd_gpg_sub_expire_date  = '0'
  $repomd_gpg_dir              = '/usr/share/httpd/.gnupg'
  $repomd_gpg_user             = 'apache'
  $repomd_gpg_group            = 'apache'
  $repomd_gpg_pub_file         = 'repomd.gpg'

  $foreman_client_cert    = '/etc/foreman/client_cert.pem'
  $foreman_client_key     = '/etc/foreman/client_key.pem'
  # for verifying the foreman proxy https
  $foreman_ssl_ca_cert    = '/etc/foreman/proxy_ca.pem'

  $foreman_proxy_cert    = '/etc/foreman-proxy/ssl_cert.pem'
  $foreman_proxy_key     = '/etc/foreman-proxy/ssl_key.pem'
  # for verifying the foreman client certs at the proxy side
  $foreman_proxy_ca_cert = '/etc/foreman-proxy/ssl_ca.pem'

  $foreman_proxy_foreman_ssl_cert    = '/etc/foreman-proxy/foreman_ssl_cert.pem'
  $foreman_proxy_foreman_ssl_key     = '/etc/foreman-proxy/foreman_ssl_key.pem'
  # for verifying the foreman https
  $foreman_proxy_foreman_ssl_ca_cert = '/etc/foreman-proxy/foreman_ssl_ca.pem'

  $puppet_client_cert = "${pki_dir}/puppet/puppet_client.crt"
  $puppet_client_key  = "${pki_dir}/puppet/puppet_client.key"
  # for verifying the foreman https
  $puppet_ssl_ca_cert = "${pki_dir}/puppet/puppet_client_ca.crt"

  $candlepin_certs_dir              = '/etc/candlepin/certs'
  $candlepin_keystore               = "${candlepin_certs_dir}/keystore"
  $candlepin_ca_cert                = "${candlepin_certs_dir}/candlepin-ca.crt"
  $candlepin_ca_key                 = "${candlepin_certs_dir}/candlepin-ca.key"
  $candlepin_amqp_store_dir         = "${candlepin_certs_dir}/amqp"
  $candlepin_amqp_truststore        = "${candlepin_amqp_store_dir}/candlepin.truststore"
  $candlepin_amqp_keystore          = "${candlepin_amqp_store_dir}/candlepin.jks"

  # Settings for uploading packages to Katello
  $katello_user           = undef
  $katello_password       = undef
  $katello_org            = 'Katello Infrastructure'
  $katello_repo_provider  = 'node-installer'
  $katello_product        = 'node-certs'
  $katello_activation_key = undef

  $pulp_pki_dir = '/etc/pki/pulp'

  $qpid_client_cert = "${pulp_pki_dir}/qpid/client.crt"
  $qpid_client_ca_cert = "${pulp_pki_dir}/qpid/ca.crt"

  $qpid_router_server_cert = "${pki_dir}/qpid_router_server.crt"
  $qpid_router_client_cert = "${pki_dir}/qpid_router_client.crt"
  $qpid_router_server_key  = "${pki_dir}/qpid_router_server.key"
  $qpid_router_client_key  = "${pki_dir}/qpid_router_client.key"
  $qpid_router_owner       = 'qdrouterd'
  $qpid_router_group       = 'root'

  $pulp_server_ca_cert   = '/etc/pki/pulp/server_ca.crt'
  # Pulp expects the node certificate to be located on this very location
  $nodes_cert_dir        = '/etc/pki/pulp/nodes'
  $nodes_cert_name       = 'node.crt'

  $qpidd_group = 'qpidd'

  $tar_file = undef
}
