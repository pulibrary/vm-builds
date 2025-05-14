SHELL := /bin/bash
.PHONY: init-qemu init-aws init-gcp \
        validate-qemu-jammy validate-aws-jammy validate-gcp-jammy \
        validate-packer validate-cloudinit build-qemu-jammy build-aws-jammy build-gcp-jammy

# Template files
QEMU_TEMPLATE_FILE       := ./templates/qemu-jammy-winter.pkr.hcl
AWS_TEMPLATE_FILE        := ./templates/aws-jammy.pkr.hcl
GCP_TEMPLATE_FILE        := ./templates/gcp-jammy.pkr.hcl
JAMMY_VARS_FILE          := ./vars/jammy.pkrvars.hcl
AWS_JAMMY_VARS_FILE      := ./vars/aws-jammy.pkrvars.hcl
GCP_JAMMY_VARS_FILE      := ./vars/gcp-jammy.pkrvars.hcl

init-qemu:
	packer init ${QEMU_TEMPLATE_FILE}

init-aws:
	packer init ${AWS_TEMPLATE_FILE}

init-gcp:
	packer init ${GCP_TEMPLATE_FILE}

validate-qemu-jammy: init-qemu
	$(info PACKER: Validating QEMU template with Ubuntu 22.04 (Jammy Jellyfish) variables)
	source /etc/os-release; packer validate -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${QEMU_TEMPLATE_FILE}

validate-aws-jammy: init-aws
	$(info PACKER: Validating AWS template with Ubuntu 22.04 (Jammy Jellyfish) variables)
	packer validate -var-file=${AWS_JAMMY_VARS_FILE} ${AWS_TEMPLATE_FILE}

validate-gcp-jammy: init-gcp
	$(info PACKER: Validating GCP template with Ubuntu 22.04 (Jammy Jellyfish) variables)
	packer validate -var-file=${GCP_JAMMY_VARS_FILE} ${GCP_TEMPLATE_FILE}

# Validate all Packer templates
validate-packer: validate-qemu-jammy validate-aws-jammy validate-gcp-jammy
	$(info All Packer templates validated successfully)

# Validate cloud-init separately
validate-cloudinit-jammy:
	$(info CLOUD-INIT: Validating Ubuntu 22.04 (Jammy Jellyfish) user-data)
	@if command -v cloud-init >/dev/null 2>&1; then \
		cloud-init schema -c http/jammy/user-data; \
	else \
		echo "cloud-init not installed, skipping validation"; \
	fi

# Shorthand for full validation
validate: validate-packer
	@echo "Packer and template validation complete. For cloud-init: make validate-cloudinit-jammy"

# Build targets
build-qemu-jammy: validate-qemu-jammy
	source /etc/os-release; PACKER_LOG=1 packer build -force -var host_distro=$${ID} -var-file=${JAMMY_VARS_FILE} ${QEMU_TEMPLATE_FILE}

build-aws-jammy: validate-aws-jammy
	PACKER_LOG=1 packer build -force -var-file=${AWS_JAMMY_VARS_FILE} ${AWS_TEMPLATE_FILE}

build-gcp-jammy: validate-gcp-jammy
	PACKER_LOG=1 packer build -force -var-file=${GCP_JAMMY_VARS_FILE} ${GCP_TEMPLATE_FILE}

