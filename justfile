# Use Bash for all recipes
set shell := ["bash", "-c"]

# ─── Files ───────────────────────────────────────────────────────────────────
qemu_template_file := "./templates/qemu-jammy-winter.pkr.hcl"
aws_template_file  := "./templates/aws-jammy.pkr.hcl"
gcp_template_file  := "./templates/gcp-jammy.pkr.hcl"
jammy_vars_file    := "./vars/jammy.pkrvars.hcl"
aws_jammy_vars_file:= "./vars/aws-jammy.pkrvars.hcl"
gcp_jammy_vars_file:= "./vars/gcp-jammy.pkrvars.hcl"

# ─── Init ────────────────────────────────────────────────────────────────────
init-qemu:
  packer init {{qemu_template_file}}

init-aws:
  packer init {{aws_template_file}}

init-gcp:
  packer init {{gcp_template_file}}

# ─── Validate ────────────────────────────────────────────────────────────────
validate-jammy: init-qemu
  @echo "PACKER: Validating QEMU Template (Jammy)"
  packer validate \
    -var-file={{jammy_vars_file}} \
    {{qemu_template_file}}

validate-aws-jammy: init-aws
  @echo "PACKER: Validating AWS Template (Jammy)"
  packer validate \
    -var-file={{aws_jammy_vars_file}} \
    {{aws_template_file}}

validate-gcp-jammy: init-gcp
  @echo "PACKER: Validating GCP Template (Jammy)"
  packer validate \
    -var-file={{gcp_jammy_vars_file}} \
    {{gcp_template_file}}

validate-packer: validate-jammy validate-aws-jammy validate-gcp-jammy
  @echo "All Packer templates validated."

validate-cloudinit:
  @echo "CLOUD-INIT: Validating user-data for Jammy"
  if command -v cloud-init >/dev/null; then \
    cloud-init schema -c http/jammy/user-data; \
  else \
    echo "cloud-init not installed, skipping."; \
  fi

validate: validate-packer
  @echo "Done. For cloud-init, run: `just validate-cloudinit`"

# ─── Builds ─────────────────────────────────────────────────────────────────
# Build with optional debug flag
build-jammy debug="false": validate-jammy
  #!/usr/bin/env bash
  if [ "{{debug}}" == "true" ]; then
    echo "Running in DEBUG mode"
    PACKER_LOG=1 packer build -debug -force \
      -var-file={{jammy_vars_file}} \
      {{qemu_template_file}}
  else
    echo "Running in normal mode"
    PACKER_LOG=1 packer build -force \
      -var-file={{jammy_vars_file}} \
      {{qemu_template_file}}
  fi

# Debug-specific recipe
build-jammy-debug: validate-jammy
  @echo "Running QEMU build in DEBUG mode"
  PACKER_LOG=1 packer build -debug -force \
    -var-file={{jammy_vars_file}} \
    {{qemu_template_file}}

build-aws-jammy debug="false": validate-aws-jammy
  #!/usr/bin/env bash
  if [ "{{debug}}" = "true" ]; then
    echo "Running AWS build in DEBUG mode"
    PACKER_LOG=1 packer build -debug -force \
      -var-file={{aws_jammy_vars_file}} \
      {{aws_template_file}}
  else
    echo "Running AWS build in normal mode"
    PACKER_LOG=1 packer build -force \
      -var-file={{aws_jammy_vars_file}} \
      {{aws_template_file}}
  fi

build-gcp-jammy debug="false": validate-gcp-jammy
  #!/usr/bin/env bash
  if [ "{{debug}}" = "true" ]; then
    echo "Running GCP build in DEBUG mode"
    PACKER_LOG=1 packer build -debug -force \
      -var-file={{gcp_jammy_vars_file}} \
      {{gcp_template_file}}
  else
    echo "Running GCP build in normal mode"
    PACKER_LOG=1 packer build -force \
      -var-file={{gcp_jammy_vars_file}} \
      {{gcp_template_file}}
  fi
