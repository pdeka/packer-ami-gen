# AMI generation for Open Shift
Generates an AMI with [OpenShift](http://www.openshift.com/). Note that base AMI image is an RHEL image.

## How to run

    #!/bin/bash
    export AWS_ACCESS_KEY_ID=<Your access key>
    export AWS_SECRET_ACCESS_KEY=<Secret Secret! Shhh!>
    export DOMAIN_NAME=foobarxyz.com
    ./install_packer.sh