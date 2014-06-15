#!/bin/bash


export AWS_DEFAULT_REGION=ap-southeast-2
export USER_HOME="$(echo $HOME)"

echo "User home - $USER_HOME"

packer_file_name=0.6.0_darwin_amd64
working_dir="$(pwd)"
packer_config=../config/packer_config.json

cd work
#rm -rf ./*
#curl -LOk https://dl.bintray.com/mitchellh/packer/$packer_file_name.zip

rm -rf extracted_packer

mkdir extracted_packer

unzip "$packer_file_name.zip" -d ./extracted_packer
export PATH=$PATH:$working_dir/work/extracted_packer/
echo "Running Packer"
packer --version
packer validate $packer_config

if [ "$?" == "1" ]; then
    exit 1;
fi

echo "Building image for config given below ..."
cat $packer_config
packer build $packer_config