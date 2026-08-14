# Use Bash for all recipes

set dotenv-load := true
set shell := ["bash", "-c"]

jammy_tpl := "builds/linux/ubuntu/jammy-cloudimg.pkr.hcl"
noble_tpl := "builds/linux/ubuntu/noble-cloudimg.pkr.hcl"
resolute_tpl := "builds/linux/ubuntu/resolute-cloudimg.pkr.hcl"
ubuntu_qemu_desktop_tpl := "builds/linux/ubuntu/linux-ubuntu-qemu-desktop-cloudimg.pkr.hcl"
ubuntu_aws_tpl := "builds/linux/ubuntu/linux-ubuntu-aws.pkr.hcl"
ubuntu_gcp_tpl := "builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl"
rocky_qemu_tpl := "builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl"
rocky_aws_tpl := "builds/linux/rocky/linux-rocky-aws.pkr.hcl"
freebsd_gcp_tpl := "builds/bsd/freebsd/freebsd-15-gcp.pkr.hcl"


ubuntu_cloudinit_user_data := "builds/linux/ubuntu/data/user-data.pkrtpl.hcl"
rocky_cloudinit_user_data := "builds/linux/rocky/data/user-data.pkrtpl.hcl"

# Initialize
init-jammy:
    packer init {{ jammy_tpl }}
init-noble:
    packer init {{ noble_tpl }}
init-resolute:
    packer init {{ resolute_tpl }}

init-ubuntu-qemu-desktop:
    packer init {{ ubuntu_qemu_desktop_tpl }}

init-ubuntu-aws:
    packer init {{ ubuntu_aws_tpl }}

init-ubuntu-gcp:
    packer init {{ ubuntu_gcp_tpl }}

init-rocky-qemu:
    packer init {{ rocky_qemu_tpl }}

init-rocky-aws:
    packer init {{ rocky_aws_tpl }}

init-all: init-jammy init-noble init-resolute init-ubuntu-qemu-desktop init-ubuntu-aws init-ubuntu-gcp init-rocky-qemu init-rocky-aws
    @echo "PACKER: All templates initialized."
init-freebsd-gcp:
    packer init {{ freebsd_gcp_tpl }}

# Ubuntu QEMU requires an iso_checksum
validate-ubuntu-qemu-desktop iso_checksum: init-ubuntu-qemu-desktop
    @echo "PACKER: Validating Ubuntu QEMU DESKTOP template"
    [[ -n "{{ iso_checksum }}" ]] || (echo "ERROR: iso_checksum is required for Ubuntu Desktop (e.g. sha256:...)" >&2; exit 1)
    packer validate -var "iso_checksum={{ iso_checksum }}" {{ ubuntu_qemu_desktop_tpl }}

validate-ubuntu-aws: init-ubuntu-aws
    @echo "PACKER: Validating Ubuntu AWS template"
    packer validate {{ ubuntu_aws_tpl }}

# Default empty; if provided, pass it through
validate-ubuntu-gcp project_id='': init-ubuntu-gcp
    @echo "PACKER: Validating Ubuntu GCP template (project_id={{ project_id }})"
    [[ -n "{{ project_id }}" ]] && packer validate -var "gcp_project_id={{ project_id }}" {{ ubuntu_gcp_tpl }} || packer validate {{ ubuntu_gcp_tpl }}

# FreeBSD GCP: require project id + subnetwork; allow zone/machine type/network overrides
build-freebsd-gcp project_id zone='us-east1-b' machine_type='e2-standard-2' network='default' subnetwork='' network_tags='' debug='false':
    just validate-freebsd-gcp {{ project_id }}
    @echo "PACKER: Building FreeBSD GCP (project_id={{ project_id }}, zone={{ zone }}, type={{ machine_type }}, network={{ network }}, subnetwork={{ subnetwork }}, tags={{ network_tags }}, debug={{ debug }})"
    [[ -n "{{ project_id }}" ]] || (echo "ERROR: project_id is required." >&2; exit 1)
    [[ -n "{{ subnetwork }}" ]] || (echo "ERROR: subnetwork is required for custom-mode networks." >&2; exit 1)
    TAGS_HCL=$(if [[ -n "{{ network_tags }}" ]]; then echo "[\"{{ network_tags }}\"]" | sed 's/,/","/g'; else echo "[]"; fi); \
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "gcp_project_id={{ project_id }}" -var "gcp_zone={{ zone }}" -var "gcp_machine_type={{ machine_type }}" -var "gcp_network={{ network }}" -var "gcp_subnetwork={{ subnetwork }}" -var "gcp_network_tags=$TAGS_HCL" {{ freebsd_gcp_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "gcp_project_id={{ project_id }}" -var "gcp_zone={{ zone }}" -var "gcp_machine_type={{ machine_type }}" -var "gcp_network={{ network }}" -var "gcp_subnetwork={{ subnetwork }}" -var "gcp_network_tags=$TAGS_HCL" {{ freebsd_gcp_tpl }}

# FreeBSD GCP: require project id; allow zone/machine type override
validate-freebsd-gcp project_id='': init-freebsd-gcp
    @echo "PACKER: Validating FreeBSD GCP template (project_id={{ project_id }})"
    if [[ -n "{{ project_id }}" ]]; then \
      packer validate -var "gcp_project_id={{ project_id }}" {{ freebsd_gcp_tpl }}; \
    else \
      packer validate {{ freebsd_gcp_tpl }}; \
    fi


validate-rocky-aws: init-rocky-aws
    @echo "PACKER: Validating Rocky AWS template"
    packer validate {{ rocky_aws_tpl }}

# For validate-all, require you to provide both checksums explicitly
validate-all ubuntu_iso_checksum rocky_iso_checksum:
    just validate-ubuntu-qemu-desktop {{ ubuntu_iso_checksum }}
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

# Builds 

# Ubuntu QEMU: requires iso_checksum; optionally export OVF (export_ovf=true) and toggle debug
build-jammy export_ovf='true' debug='false' VARS='':
    @echo "PACKER: Building Ubuntu QEMU (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ jammy_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ jammy_tpl }}

build-noble export_ovf='true' debug='false' VARS='':
    @echo "PACKER: Building Ubuntu QEMU (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ noble_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ noble_tpl }}

build-resolute export_ovf='true' debug='false' VARS='':
    @echo "PACKER: Building Ubuntu QEMU (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ resolute_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ resolute_tpl }}

build-ubuntu-qemu-desktop iso_checksum export_ovf='false' debug='false' VARS='':
    just validate-ubuntu-qemu-desktop {{ iso_checksum }}
    @echo "PACKER: Building Ubuntu QEMU (DESKTOP) (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ ubuntu_qemu_desktop_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "iso_checksum={{ iso_checksum }}" -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ ubuntu_qemu_desktop_tpl }}

build-rocky-qemu export_ovf='true' debug='false' VARS='':
    @echo "PACKER: Building Rocky QEMU (export_ovf={{ export_ovf }}, debug={{ debug }})"
    [[ "{{ debug }}" == "true" ]] \
      && env PACKER_LOG=1 packer build -debug -force -var "export_ovf={{ export_ovf }}" {{ VARS }}  {{ rocky_qemu_tpl }} \
      || env PACKER_LOG=1 packer build -force        -var "export_ovf={{ export_ovf }}" {{ VARS }} {{ rocky_qemu_tpl }}

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

build-all-cloud project_id ubuntu_iso_checksum rocky_iso_checksum:
    just build-ubuntu-aws
    just build-rocky-aws
    just build-ubuntu-gcp {{ project_id }}
    @echo "PACKER: All cloud builds (AWS+GCP) complete."

# All images are tagged into GitHub Container Registry under this namespace
DOCKER_NAMESPACE := "ghcr.io/pulibrary/vm-builds"

# Login helper.
# Uses (in order): GHCR_PAT, GITHUB_TOKEN, GH_TOKEN
ghcr-login:
    @user="${GITHUB_ACTOR:-pulibrary}"; \
     token="${GHCR_PAT:-${GITHUB_TOKEN:-$GH_TOKEN}}"; \
     if [ -z "$token" ]; then \
       echo "ERROR: Set GHCR_PAT (or GITHUB_TOKEN / GH_TOKEN) before running this." >&2; \
       exit 1; \
     fi; \
     echo "$token" | docker login ghcr.io -u "$user" --password-stdin

# Default Ubuntu release used by the docker recipes
UBUNTU_DOCKER_VERSION := "22.04"

# Build an Ubuntu systemd-capable Ansible control image
# Uses docker/ubuntu/Dockerfile; version selects the Ubuntu release (22.04, 24.04, ...)
build-ubuntu-docker tag="dev" version=UBUNTU_DOCKER_VERSION:
    docker build \
      -f docker/ubuntu/Dockerfile \
      --build-arg UBUNTU_VERSION={{ version }} \
      -t {{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:{{tag}} \
      .

# Multi-arch build & push for Ubuntu
build-ubuntu-docker-multi tag="dev" version=UBUNTU_DOCKER_VERSION:
    docker buildx build \
      --platform linux/amd64,linux/arm64/v8 \
      -f docker/ubuntu/Dockerfile \
      --build-arg UBUNTU_VERSION={{ version }} \
      -t {{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:{{tag}} \
      --push \
      .

# Push Ubuntu image to GHCR
push-ubuntu-docker tag="dev" version=UBUNTU_DOCKER_VERSION:
    just ghcr-login
    docker push {{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:{{tag}}

# Release-named shortcuts
build-jammy-docker tag="dev":
    just build-ubuntu-docker {{ tag }} 22.04

build-noble-docker tag="dev":
    just build-ubuntu-docker {{ tag }} 24.04

build-jammy-docker-multi tag="dev":
    just build-ubuntu-docker-multi {{ tag }} 22.04

build-noble-docker-multi tag="dev":
    just build-ubuntu-docker-multi {{ tag }} 24.04

push-jammy-docker tag="dev":
    just push-ubuntu-docker {{ tag }} 22.04

push-noble-docker tag="dev":
    just push-ubuntu-docker {{ tag }} 24.04

# Build both supported Ubuntu releases
build-ubuntu-docker-all tag="dev":
    just build-jammy-docker {{ tag }}
    just build-noble-docker {{ tag }}
    @echo "DOCKER: Built Ubuntu 22.04 and 24.04 images tagged {{ tag }}."

# Alias a built Ubuntu image so the short local name, the fully
# qualified GHCR name, and the GHCR :latest tag all point at it
link-ubuntu-docker tag="dev" version=UBUNTU_DOCKER_VERSION:
    @short="ubuntu-{{ version }}:{{ tag }}"; \
     full="{{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:{{ tag }}"; \
     if ! docker image inspect "$full" >/dev/null 2>&1 \
        && ! docker image inspect "$short" >/dev/null 2>&1; then \
       echo "DOCKER: $full not found locally, building it first."; \
       just build-ubuntu-docker {{ tag }} {{ version }}; \
     fi; \
     if docker image inspect "$full" >/dev/null 2>&1; then \
       src="$full"; \
     else \
       src="$short"; \
     fi; \
     docker tag "$src" "$short"; \
     docker tag "$src" "$full"; \
     docker tag "$src" "{{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:latest"; \
     echo "DOCKER: linked $src -> $short, $full, {{DOCKER_NAMESPACE}}/ubuntu-{{ version }}:latest"

link-jammy-docker tag="dev":
    just link-ubuntu-docker {{ tag }} 22.04

link-noble-docker tag="dev":
    just link-ubuntu-docker {{ tag }} 24.04

# Link both supported Ubuntu releases
link-ubuntu-docker-all tag="dev":
    just link-jammy-docker {{ tag }}
    just link-noble-docker {{ tag }}

# Multi-arch build & push for Rocky
build-rocky-docker-multi tag="dev":
    docker buildx build \
      --platform linux/amd64,linux/arm64/v8 \
      -f docker/rocky/Dockerfile \
      -t {{DOCKER_NAMESPACE}}/rocky-9:{{tag}} \
      --push \
      .

# Build Rocky 9 systemd-capable Ansible control image
# Uses docker/rocky/Dockerfile
build-rocky-docker tag="dev":
    docker build \
      -f docker/rocky/Dockerfile \
      -t {{DOCKER_NAMESPACE}}/rocky-9:{{tag}} \
      .

# Push Rocky image to GHCR
push-rocky-docker tag="dev":
    just ghcr-login
    docker push {{DOCKER_NAMESPACE}}/rocky-9:{{tag}}
