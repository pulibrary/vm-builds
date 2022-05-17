# vm-builds
Build our Virtual Machines

## Overview

This repository uses [Packer](https://www.packer.io/) to build a virtual machines for
VSphere, Google Cloud, Azure or AWS AMI.

### Prerequisite software

The following software programs need to be installed:

1. [asdf](https://github.com/asdf-vm/asdf)
1. Builders (not all may be needed):
    1. [AWS command line interface](https://github.com/MetricMike/asdf-awscli)
    1. [GCP command line interface](https://github.com/jthegedus/asdf-gcloud)
    1. [Packer](https://github.com/asdf-community/asdf-hashicorp)
    1. [Python](https://github.com/danhper/asdf-python)

### Running a packer file

1. Get into the pip shell
   ```
   pipenv sync
   pipenv shell
   ```

1. set up aws keys
   ```
   aws configure
   ```

3. Update the packer file if needed
   1. test your packer file
      ```
      packer validate <packer file name>
      ```

   1. Format the file to make sure it looks consistant
      ```
      packer fmt <packer file name>
      ```

1. run you packer file
   ```
   packer build <packer file name>
   ```
    

