SHELL := /bin/bash
.PHONY: build-jammy validate-packer validate-cloudinit validate build-aws-jammy validate-aws-jammy

# Template files
QEMU_TEMPLATE_FILE := ./templates/qemu-jammy-winter.pkr.hcl
AWS_TEMPLATE_FILE := ./templates/aws-jammy.pkr.hcl
JAMMY_VARS_FILE := ./vars/jammy.pkrvars.hcl
AWS_JAMMY_VARS_FILE := ./vars/aws-jammy.pkrvars.hcl

init-qemu:
	packer init ${QEMU_TEMPLATE_FILE}

init-aws:
	packer init ${AWS_TEMPLATE_FILE}

build-jammy: validate-jammy
	source /etc/os-release; PACKER_LOG=1 packer build -force -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${QEMU_TEMPLATE_FILE}

build-aws-jammy: validate-aws-jammy
	PACKER_LOG=1 packer build -force -var-file=${AWS_JAMMY_VARS_FILE} ${AWS_TEMPLATE_FILE}

validate-jammy: init-qemu
	$(info PACKER: Validating QEMU Template with Ubuntu 22.04 (Jammy Jellyfish) Packer Variables)
	source /etc/os-release; packer validate -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${QEMU_TEMPLATE_FILE}

validate-aws-jammy: init-aws
	$(info PACKER: Validating AWS Template with Ubuntu 22.04 (Jammy Jellyfish) Packer Variables)
	packer validate -var-file=${AWS_JAMMY_VARS_FILE} ${AWS_TEMPLATE_FILE}

validate-cloudinit-jammy:
	$(info CLOUD-INIT: Validating Ubuntu 22.04 (Jammy Jellyfish) Cloud-Config File)
	@if command -v cloud-init >/dev/null 2>&1; then \
		cloud-init schema -c http/jammy/user-data; \
	else \
		echo "cloud-init command not found, skipping cloud-init validation"; \
	fi

# This target includes both QEMU and AWS validation
validate-packer: validate-jammy validate-aws-jammy
	$(info Packer validation for both QEMU and AWS templates completed successfully)

validate-cloudinit: validate-cloudinit-jammy

validate: validate-packer
	@echo "Validation completed. For cloud-init validation, run 'make validate-cloudinit' separately."
