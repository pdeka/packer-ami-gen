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
echo "Configure bind to point to local"
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


keyfile=/var/named/${domain}.key

logIt "Creating the key for bind"

pushd /var/named
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
assertFileExists "/var/named/dynamic/${domain}.db"
assertFileHas "/var/named/dynamic/${domain}.db" "${domain}"

logIt "This is the named DB"
cat /var/named/dynamic/${domain}.db

cat <<EOF > /var/named/${domain}.key
key ${domain} {
  algorithm HMAC-MD5;
  secret "${KEY}";
};
EOF

assertFileExists "/var/named/${domain}.key"
assertFileHas "/var/named/${domain}.key" "${domain}"

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
assertFileExists "/etc/named.conf"
assertFileHas "/etc/named.conf" "${domain}"

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
assertFileExists "/etc/resolv.conf"

logIt $(cat /etc/resolv.conf)

lokkit --service=dns
chkconfig named on


logIt "Adding broker.${domain} to the config. To add others do an nsupdate and add to the DHCP client config in /etc/dhcp/dhclient-eth0.conf. You have to do both!"

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
assertFileExists "/etc/dhcp/dhclient-eth0.conf"
assertFileHas "/etc/dhcp/dhclient-eth0.conf" "${domain}"

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
assertFileExists "/etc/sysconfig/network-scripts/ifcfg-eth0"

cat > /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=broker.${domain}
NETWORKING_IPV6=no
NOZEROCONF=yes
EOF
assertFileExists "/etc/sysconfig/network"
assertFileHas "/etc/sysconfig/network" "${domain}"

hostname broker.${domain}

