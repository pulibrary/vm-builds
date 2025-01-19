
.PHONY: build-jammy validate-packer validate-cloudinit validate

TEMPLATE_FILE:=./templates/ubuntu.pkr.hcl
JAMMY_VARS_FILE:=./vars/jammy.pkrvars.hcl
TEST_TEMPLATE_FILE:=./templates/test.pkr.hcl

init:
        packer init ${TEMPLATE_FILE}

test-jammy: validate-jammy
        source /etc/os-release; PACKER_LOG=1 packer build -force -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${TEST_TEMPLATE_FILE}

build-jammy: validate-jammy
        source /etc/os-release; PACKER_LOG=1 packer build -force -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${TEMPLATE_FILE}

validate-jammy: init
        $(info PACKER: Validating Template with Ubuntu 22.04 (Jammy Jellyfish) Packer Variables)
        source /etc/os-release; packer validate -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${TEMPLATE_FILE}

validate-cloudinit-jammy:
        $(info CLOUD-INIT: Validating Ubuntu 22.04 (Jammy Jellyfish) Cloud-Config File)
        cloud-init schema -c http/jammy/user-data

validate-packer: validate-jammy

validate-cloudinit: validate-cloudinit-jammy

validate: validate-cloudinit validate-packer
