# Use Bash for all recipes
set shell := ["bash", "-c"]

# ─── Templates ────────────────────────────────────────────────────────────────
qemu_ubuntu_template := "./builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl"
aws_ubuntu_template  := "./builds/linux/ubuntu/linux-ubuntu-aws.pkr.hcl"
gcp_ubuntu_template  := "./builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl"

qemu_rocky_template  := "./builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl"
aws_rocky_template   := "./builds/linux/rocky/linux-rocky-aws.pkr.hcl"

# ─── Init ────────────────────────────────────────────────────────────────────
init-qemu-ubuntu:
  packer init {{qemu_ubuntu_template}}

init-aws-ubuntu:
  packer init {{aws_ubuntu_template}}

init-gcp-ubuntu:
  packer init {{gcp_ubuntu_template}}

init-qemu-rocky:
  packer init {{qemu_rocky_template}}

init-aws-rocky:
  packer init {{aws_rocky_template}}

init-all: init-qemu-ubuntu init-aws-ubuntu init-gcp-ubuntu init-qemu-rocky init-aws-rocky
  @echo "All packer plugins initialized."

# ─── Validate ────────────────────────────────────────────────────────────────
validate-qemu-ubuntu: init-qemu-ubuntu
  @echo "PACKER: Validating QEMU Ubuntu template"
  packer validate {{qemu_ubuntu_template}}

validate-aws-ubuntu: init-aws-ubuntu
  @echo "PACKER: Validating AWS Ubuntu template"
  packer validate {{aws_ubuntu_template}}

# Pass project/zone/machine as params (change defaults as you like)
validate-gcp-ubuntu project_id="pul-gcdc" zone="us-east1-b" machine_type="e2-standard-2": init-gcp-ubuntu
  @echo "PACKER: Validating GCP Ubuntu template (project={{project_id}}, zone={{zone}}, type={{machine_type}})"
  packer validate \
    -var "gcp_project_id={{project_id}}" \
    -var "gcp_zone={{zone}}" \
    -var "gcp_machine_type={{machine_type}}" \
    {{gcp_ubuntu_template}}

validate-qemu-rocky: init-qemu-rocky
  @echo "PACKER: Validating QEMU Rocky template"
  packer validate {{qemu_rocky_template}}

validate-aws-rocky: init-aws-rocky
  @echo "PACKER: Validating AWS Rocky template"
  packer validate {{aws_rocky_template}}

validate: validate-qemu-ubuntu validate-aws-ubuntu validate-gcp-ubuntu validate-qemu-rocky validate-aws-rocky
  @echo "All packer templates validated."

# ─── Builds ─────────────────────────────────────────────────────────────────
# Use debug="true" to add -debug; PACKER_LOG=1 always on for easier troubleshooting
_build cmd template:
  #!/usr/bin/env bash
  if [ "{{cmd}}" = "debug" ]; then
    echo "Running in DEBUG mode"
    PACKER_LOG=1 packer build -debug -force {{template}}
  else
    echo "Running in normal mode"
    PACKER_LOG=1 packer build -force {{template}}
  fi

build-qemu-ubuntu debug="false": validate-qemu-ubuntu
  just _build {{ if debug == "true" { "debug" } else { "run" } }} {{qemu_ubuntu_template}}

build-aws-ubuntu debug="false": validate-aws-ubuntu
  just _build {{ if debug == "true" { "debug" } else { "run" } }} {{aws_ubuntu_template}}

# GCP: pass in project/zone/machine; you can also override image family/size, etc.
build-gcp-ubuntu project_id="pul-gcdc" zone="us-east1-b" machine_type="e2-standard-2" debug="false": validate-gcp-ubuntu
  #!/usr/bin/env bash
  if [ "{{debug}}" = "true" ]; then
    echo "Running GCP build in DEBUG mode"
    PACKER_LOG=1 packer build -debug -force \
      -var "gcp_project_id={{project_id}}" \
      -var "gcp_zone={{zone}}" \
      -var "gcp_machine_type={{machine_type}}" \
      {{gcp_ubuntu_template}}
  else
    echo "Running GCP build in normal mode"
    PACKER_LOG=1 packer build -force \
      -var "gcp_project_id={{project_id}}" \
      -var "gcp_zone={{zone}}" \
      -var "gcp_machine_type={{machine_type}}" \
      {{gcp_ubuntu_template}}
  fi

build-qemu-rocky debug="false": validate-qemu-rocky
  just _build {{ if debug == "true" { "debug" } else { "run" } }} {{qemu_rocky_template}}

build-aws-rocky debug="false": validate-aws-rocky
  just _build {{ if debug == "true" { "debug" } else { "run" } }} {{aws_rocky_template}}

# Convenience meta targets
build-all: build-qemu-ubuntu build-aws-ubuntu build-gcp-ubuntu build-qemu-rocky build-aws-rocky
  @echo "All builds complete."

build-ubuntu: build-qemu-ubuntu build-aws-ubuntu build-gcp-ubuntu
  @echo "All Ubuntu builds complete."

build-rocky: build-qemu-rocky build-aws-rocky
  @echo "All Rocky builds complete."
