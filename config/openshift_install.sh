#!/bin/bash

function logIt()
{
    echo "============================================================================================================="
    echo "$@"
    echo "============================================================================================================="
}

function exitIt()
{
    logIt "$@"
    exit 1
}

function assertFileExists()
{
    if [ -f "$@" ]
    then
        logIt "$@ exists."
    else
        exitIt "$@ not found."
    fi
}

function assertFileHas()
{
    thisFile=$1
    shift

    if [[ $(cat "$thisFile") != *$@* ]]
    then
      exitIt "File $thisFile does not have the right content.";
    fi
}

echo "============================================================================================================="
echo "Installs image with openshift"
cat /etc/*-release
echo "SELinux running in $(getenforce) mode"
echo "Note that this script is customised for a RHEL image"
echo "This script will install the prerequisites, create a local DNS server and install openshift"
echo "Please review - http://openshift.github.io/documentation/oo_deployment_guide_comprehensive.html"
echo "Please review - http://openshift.github.io/documentation/oo_deployment_guide_puppet.html"
echo "It would probably become a puppet class in the future"
echo "Domain name is $domain"
echo "AWS region is $aws_region"
echo "============================================================================================================="

cd /tmp

if [ "$domain" == "" ]; then
    exitIt "Domain name not set"
fi

if [ "$aws_region" == "" ]; then
    exitIt "AWS region not set"
fi

if [ "$aws_access_key" == "" ]; then
    exitIt "AWS access key not set"
fi

if [ "$aws_secret_key" == "" ]; then
    exitIt "AWS access key secret not set"
fi


logIt "Install EPEL yum repository"

yum install -y --nogpgcheck http://mirror.as24220.net/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

logIt "Setting up /etc/yum.repos.d/Puppetlabs.repo"

cat > /etc/yum.repos.d/Puppetlabs.repo <<EOF
[puppetdeps]
name=puppetdeps
baseurl=http://yum.puppetlabs.com/el/6/dependencies/x86_64/
gpgcheck=0
#released updates
[puppet]
name=puppet
baseurl=http://yum.puppetlabs.com/el/6/products/x86_64/
gpgcheck=0
exclude=*mcollective* activemq *v8314*
EOF
assertFileExists "/etc/yum.repos.d/Puppetlabs.repo"

logIt "Install ruby and puppet"

yum install -y puppet facter
mkdir -p /etc/puppet/modules

logIt "Installing bind and bind utils"

yum install -y bind bind-utils

keyfile=/var/named/${domain}.key

logIt "Creating the key for bind"

pushd /var/named
rm K${domain}*
dnssec-keygen -a HMAC-MD5 -b 512 -n USER -r /dev/urandom ${domain}
KEY="$(grep Key: K${domain}*.private | cut -d ' ' -f 2)"
popd

logIt "This is the key - $KEY"


cat > /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=broker.${domain}
NETWORKING_IPV6=no
NOZEROCONF=yes
EOF
assertFileExists "/etc/sysconfig/network"
assertFileHas "/etc/sysconfig/network" "${domain}"

hostname broker.${domain}

puppet module install openshift/openshift_origin

logIt "Copying the config class to puppet open shift"

cp -f /tmp/files/configure_origin.pp /etc/puppet/modules/openshift_origin/configure_origin.pp
assertFileExists "/etc/puppet/modules/openshift_origin/configure_origin.pp"
assertFileHas "/etc/puppet/modules/openshift_origin/configure_origin.pp" "class { 'openshift_origin'"

cp -f /tmp/files/configure_openshift_instance.sh /etc/init.d/configure_openshift_instance.sh
chmod +x /etc/init.d/configure_openshift_instance.sh
assertFileExists "/etc/init.d/configure_openshift_instance.sh"

cp -rf /tmp/files/yum_plugin_puppet /etc/puppet/modules/yum_plugin_puppet

export FACTER_DOMAIN=$(echo $domain)
export FACTER_FQDN=$(echo $domain)
export FACTER_BINDKEY=$(echo $KEY)
export FACTER_IPADDRESS="127.0.0.1"

logIt "Here are the facter variables set"

facter | grep 'domain'
facter | grep 'bindkey'
facter | grep 'ipaddress'

logIt "Check if the local DNS is running."


puppet apply --verbose /etc/puppet/modules/openshift_origin/configure_origin.pp