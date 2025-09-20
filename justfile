# Use Bash for all recipes
set shell := ["bash", "-c"]

# ─── Paths (match your repo) ────────────────────────────────────────────────
ubuntu_qemu_tpl := "builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl"
ubuntu_aws_tpl  := "builds/linux/ubuntu/linux-ubuntu-aws.pkr.hcl"
ubuntu_gcp_tpl  := "builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl"

rocky_qemu_tpl  := "builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl"
rocky_aws_tpl   := "builds/linux/rocky/linux-rocky-aws.pkr.hcl"

# Optional cloud-init files (for schema validation)
ubuntu_cloudinit_user_data := "builds/linux/ubuntu/data/user-data.pkrtpl.hcl"
rocky_cloudinit_user_data  := "builds/linux/rocky/data/user-data.pkrtpl.hcl"

# ─── Init ───────────────────────────────────────────────────────────────────
init-ubuntu-qemu:
  packer init {{ubuntu_qemu_tpl}}

init-ubuntu-aws:
  packer init {{ubuntu_aws_tpl}}

init-ubuntu-gcp:
  packer init {{ubuntu_gcp_tpl}}

init-rocky-qemu:
  packer init {{rocky_qemu_tpl}}

init-rocky-aws:
  packer init {{rocky_aws_tpl}}

init-all: init-ubuntu-qemu init-ubuntu-aws init-ubuntu-gcp init-rocky-qemu init-rocky-aws
  @echo "PACKER: All templates initialized."

# ─── Validate (syntax + required vars checks) ───────────────────────────────
validate-ubuntu-qemu: init-ubuntu-qemu
  @echo "PACKER: Validating Ubuntu QEMU template"
  packer validate {{ubuntu_qemu_tpl}}

validate-ubuntu-aws: init-ubuntu-aws
  @echo "PACKER: Validating Ubuntu AWS template"
  packer validate {{ubuntu_aws_tpl}}

# Default empty; if provided, pass it through
validate-ubuntu-gcp project_id='': init-ubuntu-gcp
  @echo "PACKER: Validating Ubuntu GCP template (project_id={{project_id}})"
  if [[ -n "{{project_id}}" ]]; then
  packer validate -var "gcp_project_id={{project_id}}" {{ubuntu_gcp_tpl}}
  else
  packer validate {{ubuntu_gcp_tpl}}
  fi

# Rocky QEMU requires iso_checksum at validate time
validate-rocky-qemu iso_checksum='': init-rocky-qemu
  @echo "PACKER: Validating Rocky QEMU template"
  if [[ -z "{{iso_checksum}}" ]]; then
  echo "ERROR: iso_checksum is required for Rocky (e.g. sha256:...)" >&2; exit 1;
  fi
  packer validate -var "iso_checksum={{iso_checksum}}" {{rocky_qemu_tpl}}

validate-rocky-aws: init-rocky-aws
  @echo "PACKER: Validating Rocky AWS template"
  packer validate {{rocky_aws_tpl}}

validate-all: validate-ubuntu-qemu validate-ubuntu-aws validate-ubuntu-gcp validate-rocky-qemu validate-rocky-aws
  @echo "PACKER: All templates validated."

# ─── Cloud-Init schema checks (optional) ────────────────────────────────────
validate-cloudinit-ubuntu:
  @echo "CLOUD-INIT: Validating Ubuntu user-data (best-effort)"
  if command -v cloud-init >/dev/null; then
  cloud-init schema -c {{ubuntu_cloudinit_user_data}} || echo "Skip: template rendering may be required"
  else
  echo "cloud-init not installed, skipping."
  fi

validate-cloudinit-rocky:
  @echo "CLOUD-INIT: Validating Rocky user-data (best-effort)"
  if command -v cloud-init >/dev/null; then
  cloud-init schema -c {{rocky_cloudinit_user_data}} || echo "Skip: template rendering may be required"
  else
  echo "cloud-init not installed, skipping."
  fi

validate-cloudinit: validate-cloudinit-ubuntu validate-cloudinit-rocky
  @echo "CLOUD-INIT: Done."

# ─── Builds ────────────────────────────────────────────────────────────────
# Ubuntu QEMU: optionally export OVF (export_ovf=true) and toggle debug
build-ubuntu-qemu export_ovf='false' debug='false': validate-ubuntu-qemu
  @echo "PACKER: Building Ubuntu QEMU (export_ovf={{export_ovf}}, debug={{debug}})"
  if [[ "{{debug}}" == "true" ]]; then
  PACKER_LOG=1 packer build -debug -force -var "export_ovf={{export_ovf}}" {{ubuntu_qemu_tpl}}
  else
  PACKER_LOG=1 packer build -force -var "export_ovf={{export_ovf}}" {{ubuntu_qemu_tpl}}
  fi

# Rocky QEMU: checksum required from the Rocky cloud image you downloaded
build-rocky-qemu iso_checksum='' debug='false': validate-rocky-qemu
  @echo "PACKER: Building Rocky QEMU (debug={{debug}})"
  if [[ -z "{{iso_checksum}}" ]]; then
  echo "ERROR: iso_checksum is required (e.g. sha256:...)" >&2; exit 1;
  fi
  if [[ "{{debug}}" == "true" ]]; then
  PACKER_LOG=1 packer build -debug -force -var "iso_checksum={{iso_checksum}}" {{rocky_qemu_tpl}}
  else
  PACKER_LOG=1 packer build -force -var "iso_checksum={{iso_checksum}}" {{rocky_qemu_tpl}}
  fi

# Ubuntu AWS
build-ubuntu-aws debug='false': validate-ubuntu-aws
  @echo "PACKER: Building Ubuntu AWS (debug={{debug}})"
  if [[ "{{debug}}" == "true" ]]; then
  PACKER_LOG=1 packer build -debug -force {{ubuntu_aws_tpl}}
  else
  PACKER_LOG=1 packer build -force {{ubuntu_aws_tpl}}
  fi

# Rocky AWS
build-rocky-aws debug='false': validate-rocky-aws
  @echo "PACKER: Building Rocky AWS (debug={{debug}})"
  if [[ "{{debug}}" == "true" ]]; then
  PACKER_LOG=1 packer build -debug -force {{rocky_aws_tpl}}
  else
  PACKER_LOG=1 packer build -force {{rocky_aws_tpl}}
  fi

# Ubuntu GCP: require project id; allow zone/machine type override
build-ubuntu-gcp project_id='' zone='us-east1-b' machine_type='e2-standard-2' debug='false': validate-ubuntu-gcp
  @echo "PACKER: Building Ubuntu GCP (project_id={{project_id}}, zone={{zone}}, type={{machine_type}}, debug={{debug}})"
  if [[ -z "{{project_id}}" ]]; then
  echo "ERROR: project_id is required. Example: just build-ubuntu-gcp project_id=my-gcp-project" >&2; exit 1;
  fi
  if [[ "{{debug}}" == "true" ]]; then
  PACKER_LOG=1 packer build -debug -force -var "gcp_project_id={{project_id}}" -var "gcp_zone={{zone}}" -var "gcp_machine_type={{machine_type}}" {{ubuntu_gcp_tpl}}
  else
  PACKER_LOG=1 packer build -force -var "gcp_project_id={{project_id}}" -var "gcp_zone={{zone}}" -var "gcp_machine_type={{machine_type}}" {{ubuntu_gcp_tpl}}
  fi

# Convenience bundles
build-all-qemu: build-ubuntu-qemu build-rocky-qemu
  @echo "PACKER: All QEMU builds complete."

build-all-cloud: build-ubuntu-aws build-rocky-aws build-ubuntu-gcp
  @echo "PACKER: All cloud builds (AWS+GCP) complete."

build-everything: build-all-qemu build-all-cloud
  @echo "PACKER: Everything built."

