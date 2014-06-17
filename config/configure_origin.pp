class { 'openshift_origin' :
  roles                      => ['broker','named','activemq','datastore','node'],
  bind_key                   => $bindkey,
  domain                     => $domain,
  broker_auth_plugin         => 'htpasswd',
  openshift_user1            => 'openshift',
  openshift_password1        => 'password',
  install_method             => 'yum',
  jenkins_repo_base          => 'http://pkg.jenkins-ci.org/redhat',
  development_mode           => true,
  nameserver_ip_addr         => $ipaddress,
  conf_nameserver_upstream_dns => $ipaddress,
  aws_access_key_id          => $aws_access_key,
  aws_secret_key             => $aws_secret_key
}