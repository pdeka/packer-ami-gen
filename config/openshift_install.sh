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

echo "============================================================================================================="
echo "Installs image with openshift"
cat /etc/*-release
echo "SELinux running in $(getenforce) mode"
echo "Note that this script is customised for a RHEL image"
echo "This script will install the prerequisites, create a local DNS server and install openshift"
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

yum install -y --nogpgcheck http://mirror.as24220.net/pub/epel/6/i386/epel-release-6-8.noarch.rpm


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
exclude=*mcollective* activemq
EOF

logIt "Setting up /etc/yum.repos.d/openshift-origin-deps.repo"

cat > /etc/yum.repos.d/openshift-origin-deps.repo <<EOF
[openshift-origin-deps]
name=openshift-origin-deps
baseurl=http://mirror.openshift.com/pub/origin-server/release/3/rhel-6/dependencies/x86_64/
gpgcheck=0
enabled=1
EOF

logIt "Setting up /etc/yum.repos.d/openshift-origin.repo"

cat <<EOF> /etc/yum.repos.d/openshift-origin.repo
[openshift-origin]
name=openshift-origin
baseurl=http://mirror.openshift.com/pub/origin-server/release/3/rhel-6/packages/x86_64/
gpgcheck=0
enabled=1
EOF

logIt "Setting up /etc/yum.repos.d/epel.repo"

cat > /etc/yum.repos.d/epel.repo <<EOF
[epel]
name=Extra Packages for Enterprise Linux 6 - x86_64
#baseurl=http://download.fedoraproject.org/pub/epel/6/x86_64
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=x86_64
exclude=*passenger* nodejs*
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 6 - x86_64 - Debug
#baseurl=http://download.fedoraproject.org/pub/epel/6/x86_64/debug
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-debug-6&arch=x86_64
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
gpgcheck=1

[epel-source]
name=Extra Packages for Enterprise Linux 6 - x86_64
#baseurl=http://download.fedoraproject.org/pub/epel/6/x86_64
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=x86_64
exclude=*passenger* nodejs*
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
EOF

logIt "Clean and update the yum repo before start"

yum clean all
yum -y update
yum -y install ruby ruby-devel rubygems puppet ruby193 ntpdate ntp

logIt "Set the clock using clock.redhat.com"

ntpdate clock.redhat.com
chkconfig ntpd on
service ntpd start

logIt "Setting up /etc/profile.d/scl193.sh"

cat > /etc/profile.d/scl193.sh <<EOF
# Setup PATH, LD_LIBRARY_PATH and MANPATH for ruby-1.9
export PATH=$(dirname `scl enable ruby193 "which ruby"`):$PATH
export LD_LIBRARY_PATH=$(scl enable ruby193 "printenv LD_LIBRARY_PATH"):$LD_LIBRARY_PATH
export MANPATH=$(scl enable ruby193 "printenv MANPATH"):$MANPATH
EOF

cp -f /etc/profile.d/scl193.sh /etc/sysconfig/mcollective
chmod 0644 /etc/profile.d/scl193.sh /etc/sysconfig/mcollective

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
logIt "Setting up named context"

rndc-confgen -a -r /dev/urandom
restorecon -v /etc/rndc.* /etc/named.*
chown -v root:named /etc/rndc.key
chmod -v 640 /etc/rndc.key
echo "forwarders { 8.8.8.8; 8.8.4.4; } ;" >> /var/named/forwarders.conf
restorecon -v /var/named/forwarders.conf
chmod -v 640 /var/named/forwarders.conf

rm -rvf /var/named/dynamic
mkdir -vp /var/named/dynamic

logIt "This is the domain - $domain"
if [ "$domain" == "" ]; then
    exitIt "Domain name not set"
fi

logIt "Setting up the named DB"

cat <<EOF > /var/named/dynamic/${domain}.db
\$ORIGIN .
\$TTL 1 ; 1 seconds (for testing only)
${domain}       IN SOA  ns1.${domain}. hostmaster.${domain}. (
            2011112904 ; serial
            60         ; refresh (1 minute)
            15         ; retry (15 seconds)
            1800       ; expire (30 minutes)
            10         ; minimum (10 seconds)
            )
        NS  ns1.${domain}.
        MX  10 mail.${domain}.
\$ORIGIN ${domain}.
ns1         A   127.0.0.1
EOF

logIt "This is the named DB"
cat /var/named/dynamic/${domain}.db

cat <<EOF > /var/named/${domain}.key
key ${domain} {
  algorithm HMAC-MD5;
  secret "${KEY}";
};
EOF

chown -Rv named:named /var/named
restorecon -rv /var/named

logIt "This is the domain $domain"
if [ "$domain" == "" ]; then
    exitIt "Domain name not set"
fi


logIt "Setting up /etc/named.conf"

cat <<EOF > /etc/named.conf
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//

options {
    listen-on port 53 { any; };
    directory   "/var/named";
    dump-file   "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     { any; };
    recursion yes;

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.iscdlv.key";

    // set forwarding to the next nearest server (from DHCP response
    forward only;
    include "forwarders.conf";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

// use the default rndc key
include "/etc/rndc.key";

controls {
    inet 127.0.0.1 port 953
    allow { 127.0.0.1; } keys { "rndc-key"; };
};

include "/etc/named.rfc1912.zones";

include "${domain}.key";

zone "${domain}" IN {
    type master;
    file "dynamic/${domain}.db";
    allow-update { key ${domain} ; } ;
};
EOF

chown -v root:named /etc/named.conf
restorecon /etc/named.conf

service named start
if [ "$?" == "1" ]; then
    exitIt "Named did not start properly!"
fi

logIt "Setting up /etc/resolv.conf"

cat > /etc/resolv.conf <<EOF
nameserver 127.0.0.1
EOF

logIt $(cat /etc/resolv.conf)

lokkit --service=dns
chkconfig named on

nsupdate -k ${keyfile} <<EOF
server 127.0.0.1
update delete broker.${domain} A
update add broker.${domain} 180 A 127.0.0.1
send
EOF

cat > /etc/dhcp/dhclient-eth0.conf <<EOF
prepend domain-name-servers 127.0.0.1;
supersede host-name "broker";
supersede domain-name ${domain};
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
USERCTL="yes"
PEERDNS="no"
IPV6INIT="no"
PERSISTENT_DHCLIENT="1"
DNS1=127.0.0.1
EOF

cat > /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=broker.${domain}
NETWORKING_IPV6=no
NOZEROCONF=yes
EOF

hostname broker.${domain}

logIt "Installing puppet openshift"

puppet module install openshift/openshift_origin

logIt "Copying the config class to puppet open shift"

cp /tmp/configure_origin.pp /etc/puppet/modules/openshift_origin/configure_origin.pp

export FACTER_DOMAIN=$(echo $domain)
export FACTER_BINDKEY=$(echo $KEY)
export FACTER_IPADDRESS="127.0.0.1"
export FACTER_AWS_ACCESS_KEY=$(echo $aws_access_key)
export FACTER_AWS_SECRET_KEY=$(echo $aws_secret_key)
export FACTER_AWS_REGION=$(echo $aws_region)

logIt "Here are the facter variables set"

facter | grep 'domain'
facter | grep 'bindkey'
facter | grep 'ipaddress'
facter | grep 'aws_region'

logIt "Doing assertions before running puppet openshift"

ping -q -c5 broker.${domain} > /dev/null
if [ $? -eq 0 ]; then
	logIt "Local DNS is running properly"
else
    exitIt "Local DNS is not running. Perhaps the DHCP process over wrote your config. Check /etc/resolv.conf, /etc/dhcp/dhclient-eth0.conf"
fi

if [[ $(cat /etc/profile.d/scl193.sh) != */opt/rh/ruby193* ]]
then
  exitIt "Path for ruby 19 not set. Check /etc/profile.d/scl193.sh. PATH, LD_LIBRARY_PATH and MANPATH should be set.";
fi

#puppet apply --noop --debug --verbose /etc/puppet/modules/openshift_origin/configure_origin.pp