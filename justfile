# Use Bash for all recipes

set dotenv-load := true
set shell := ["bash", "-c"]

# ─── Paths (match repo) ────────────────────────────────────────────────

ubuntu_qemu_tpl := "builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl"
ubuntu_aws_tpl := "builds/linux/ubuntu/linux-ubuntu-aws.pkr.hcl"
ubuntu_gcp_tpl := "builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl"
rocky_qemu_tpl := "builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl"
rocky_aws_tpl := "builds/linux/rocky/linux-rocky-aws.pkr.hcl"

# Optional cloud-init files (for schema validation)

ubuntu_cloudinit_user_data := "builds/linux/ubuntu/data/user-data.pkrtpl.hcl"
rocky_cloudinit_user_data := "builds/linux/rocky/data/user-data.pkrtpl.hcl"

# ─── Init ───────────────────────────────────────────────────────────────────
init-ubuntu-qemu:
    packer init {{ ubuntu_qemu_tpl }}

init-ubuntu-aws:
    packer init {{ ubuntu_aws_tpl }}

init-ubuntu-gcp:
    packer init {{ ubuntu_gcp_tpl }}

init-rocky-qemu:
    packer init {{ rocky_qemu_tpl }}

init-rocky-aws:
    packer init {{ rocky_aws_tpl }}

init-all: init-ubuntu-qemu init-ubuntu-aws init-ubuntu-gcp init-rocky-qemu init-rocky-aws
    @echo "PACKER: All templates initialized."

# ─── Validate (syntax + required vars checks) ───────────────────────────────

# Ubuntu QEMU requires an iso_checksum
validate-ubuntu-qemu iso_checksum: init-ubuntu-qemu
    @echo "PACKER: Validating Ubuntu QEMU template"
    [[ -n "{{ iso_checksum }}" ]] || (echo "ERROR: iso_checksum is required for Ubuntu (e.g. sha256:...)" >&2; exit 1)
    packer validate -var "iso_checksum={{ iso_checksum }}" {{ ubuntu_qemu_tpl }}

validate-ubuntu-aws: init-ubuntu-aws
    @echo "PACKER: Validating Ubuntu AWS template"
    packer validate {{ ubuntu_aws_tpl }}

# Default empty; if provided, pass it through
validate-ubuntu-gcp project_id='': init-ubuntu-gcp
    @echo "PACKER: Validating Ubuntu GCP template (project_id={{ project_id }})"
    [[ -n "{{ project_id }}" ]] && packer validate -var "gcp_project_id={{ project_id }}" {{ ubuntu_gcp_tpl }} || packer validate {{ ubuntu_gcp_tpl }}

# Rocky QEMU requires an iso_checksum
validate-rocky-qemu iso_checksum: init-rocky-qemu
    @echo "PACKER: Validating Rocky QEMU template"
    [[ -n "{{ iso_checksum }}" ]] || (echo "ERROR: iso_checksum is required for Rocky (e.g. sha256:...)" >&2; exit 1)
    packer validate -var "iso_checksum={{ iso_checksum }}" {{ rocky_qemu_tpl }}

validate-rocky-aws: init-rocky-aws
    @echo "PACKER: Validating Rocky AWS template"
    packer validate {{ rocky_aws_tpl }}

# For validate-all, require you to provide both checksums explicitly
validate-all ubuntu_iso_checksum rocky_iso_checksum:
    just validate-ubuntu-qemu {{ ubuntu_iso_checksum }}
    just validate-rocky-qemu {{ rocky_iso_checksum }}
    just validate-ubuntu-aws
    just validate-ubuntu-gcp
    just validate-rocky-aws
    @echo "PACKER: All templates validated."

# ─── Cloud-Init schema checks (optional useful debugging) ────────────────────────────────────
validate-cloudinit-ubuntu:
    @echo "CLOUD-INIT: Validating Ubuntu user-data (best-effort)"
    if command -v cloud-init >/dev/null; then cloud-init schema -c {{ ubuntu_cloudinit_user_data }} || echo "Skip: template rendering may be required"; else echo "cloud-init not installed, skipping."; fi

validate-cloudinit-rocky:
    @echo "CLOUD-INIT: Validating Rocky user-data (best-effort)"
    if command -v cloud-init >/dev/null; then cloud-init schema -c {{ rocky_cloudinit_user_data }} || echo "Skip: template rendering may be required"; else echo "cloud-init not installed, skipping."; fi

validate-cloudinit: validate-cloudinit-ubuntu validate-cloudinit-rocky
    @echo "CLOUD-INIT: Done."

# ─── Builds ────────────────────────────────────────────────────────────────

# Ubuntu QEMU: requires iso_checksum; optionally export OVF (export_ovf=true) and toggle debug
build-ubuntu-qemu iso_checksum export_ovf='false' debug='false' VARS='':
    just validate-ubuntu-qemu {{ iso_checksum }}
    @echo "PACKER: Building Ubuntu QEMU (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ ubuntu_qemu_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ ubuntu_qemu_tpl }}

build-rocky-qemu iso_checksum export_ovf='false' debug='false' VARS='':
    just validate-rocky-qemu {{ iso_checksum }}
    @echo "PACKER: Building Rocky QEMU (debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }}  {{ rocky_qemu_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ rocky_qemu_tpl }}

# Ubuntu AWS
build-ubuntu-aws debug='false':
    just validate-ubuntu-aws
    @echo "PACKER: Building Ubuntu AWS (debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force {{ ubuntu_aws_tpl }} \
      || env PACKER_LOG=1 packer build -force {{ ubuntu_aws_tpl }}

# Rocky AWS
build-rocky-aws debug='false':
    just validate-rocky-aws
    @echo "PACKER: Building Rocky AWS (debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force {{ rocky_aws_tpl }} \
      || env PACKER_LOG=1 packer build -force {{ rocky_aws_tpl }}

# Ubuntu GCP: require project id; allow zone/machine type override
build-ubuntu-gcp project_id zone='us-east1-b' machine_type='e2-standard-2' debug='false':
    just validate-ubuntu-gcp {{ project_id }}
    @echo "PACKER: Building Ubuntu GCP (project_id={{ project_id }}, zone={{ zone }}, type={{ machine_type }}, debug={{ debug }})"
    [[ -n "{{ project_id }}" ]] || (echo "ERROR: project_id is required. Example: just build-ubuntu-gcp project_id=my-gcp-project" >&2; exit 1)
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "gcp_project_id={{ project_id }}" -var "gcp_zone={{ zone }}" -var "gcp_machine_type={{ machine_type }}" {{ ubuntu_gcp_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "gcp_project_id={{ project_id }}" -var "gcp_zone={{ zone }}" -var "gcp_machine_type={{ machine_type }}" {{ ubuntu_gcp_tpl }}

# Convenience bundles
build-all-qemu ubuntu_iso_checksum rocky_iso_checksum:
    just build-ubuntu-qemu {{ ubuntu_iso_checksum }}
    just build-rocky-qemu {{ rocky_iso_checksum }}
    @echo "PACKER: All QEMU builds complete."

build-all-cloud project_id ubuntu_iso_checksum rocky_iso_checksum:
    just build-ubuntu-aws
    just build-rocky-aws
    just build-ubuntu-gcp {{ project_id }}
    @echo "PACKER: All cloud builds (AWS+GCP) complete."

build-everything project_id ubuntu_iso_checksum rocky_iso_checksum:
    just build-all-qemu {{ ubuntu_iso_checksum }} {{ rocky_iso_checksum }}
    just build-all-cloud {{ project_id }} {{ ubuntu_iso_checksum }} {{ rocky_iso_checksum }}
    @echo "PACKER: Everything built."
