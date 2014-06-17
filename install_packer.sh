#!/bin/bash


export AWS_DEFAULT_REGION=ap-southeast-2
export USER_HOME="$(echo $HOME)"
export WORKING_DIR="$(pwd)"

echo "User home - $USER_HOME"
echo "Working directory - $WORKING_DIR"

if [ "$(uname)" == "Darwin" ]; then
    packer_file_name=0.6.0_darwin_amd64
else
    packer_file_name=0.6.0_linux_amd64
fi

packer_config=../config/packer_config.json

rm -rf work
mkdir work
cd work

install_package_file="../.installpackages/$packer_file_name.zip"
echo "Install package file - $install_package_file"

if [ -f "$install_package_file" ]; then
    echo "Copying install package file stored locally"
    cp $install_package_file .
else
    echo "Downloading install package file"
    curl -LOk https://dl.bintray.com/mitchellh/packer/$packer_file_name.zip
fi

rm -rf extracted_packer
mkdir extracted_packer

unzip "$packer_file_name.zip" -d ./extracted_packer
export PATH=$PATH:$WORKING_DIR/work/extracted_packer/
echo "Running Packer"
packer --version
packer validate $packer_config

if [ "$?" == "1" ]; then
    exit 1;
fi

echo "Building image for config given below ..."
cat $packer_config
packer build $packer_config