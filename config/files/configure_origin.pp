class { 'openshift_origin' :
  roles                      => ['broker','named','activemq','datastore','node'],
  bind_key                   => $bindkey,
  domain                     => $domain,
  broker_auth_plugin         => 'htpasswd',
  jenkins_repo_base          => 'http://pkg.jenkins-ci.org/redhat',
  development_mode           => false,
  nameserver_ip_addr         => '127.0.0.1',
  repos_base                 => "http://mirror.openshift.com/pub/origin-server/release/3/rhel-6",
  install_cartridges         => ['ruby']
}