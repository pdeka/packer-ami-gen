#!/bin/bash

echo "Image Configuration"
echo "================================================================="
cat /etc/*-release
echo "SELinux running in $(getenforce) mode"
echo "================================================================="
yum -y install ruby ruby-devel rubygems ruby193-ruby
cd /var/tmp

echo "Install EPEL yum repository"
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -Uvh epel-release-6*.rpm

echo "Install ruby 193 Software collection"
cat > /etc/yum.repos.d/openshift-origin-deps.repo <<"EOF"
[openshift-origin-deps]
name=OpenShift Origin Dependencies - EL6
baseurl=http://mirror.openshift.com/pub/origin-server/release/3/rhel-6/dependencies/$basearch/
gpgcheck=0
EOF
#echo "Installing Open Shift Origin"
#sh <(curl -s https://install.openshift.com/)