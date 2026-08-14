# VM Builds

Infrastructure-as-Code repository for building standardized virtual machine images and systemd-capable Docker images using Packer, Docker, and Ansible.

## Overview

This repository contains Packer templates, Dockerfiles, and Ansible playbooks for creating consistent, secure golden images for Princeton University Library infrastructure. Currently supports:

- **VM Images**: Ubuntu 22.04 LTS and Rocky Linux 9.4
- **Docker Images**: systemd-capable containers published to GHCR

## Prerequisites

### Using Devbox (Recommended)

```bash
# Install Devbox from https://www.jetbox.io/devbox
# Then simply run:
devbox shell
```

This will automatically install all required tools:

- Packer
- Ansible
- Python
- AWS CLI v2
- Google Cloud SDK
- QEMU
- Docker
- Git
- Just

### Manual Installation

If not using Devbox, (you know what you're doing :wink:) manually install:

- Packer >= 1.12.0
- Ansible >= 2.9
- Python >= 3.8
- Docker >= 20.10
- QEMU (for local testing)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/pulibrary/vm-builds.git
cd vm-builds

# Enter the Devbox environment
devbox shell

# (One-time) Initialize packer plugins for all templates
just init-all
```

Download [Ubuntu Cloud Image](https://cloud-images.ubuntu.com/releases/) ISO and place it at [build/linux/ubuntu/isos](build/linux/ubuntu/isos) and/or [Rocky Generic Cloud Base Image](https://dl.rockylinux.org/pub/rocky/9/images/x86_64/) (uses Rocky-9-GenericCloud-Base.latest.x86_64.qcow2 format) and place it at [build/linux/rocky/isos](build/linux/rocky/isos) Note the checksums for any you plan to use, which will be needed in the steps below.

## Quick Start: Build something with `just`

### VM Images

```bash
# Ubuntu QEMU
just build-jammy

# Rocky QEMU (requires checksum)
just build-rocky'sha256:<rocky_cloud_image_sha256_here>'

# Ubuntu AWS AMI
just build-ubuntu-aws

# Rocky AWS AMI
just build-rocky-aws

# Ubuntu GCP image (failing for now)
just build-ubuntu-gcp pul-gcdc zone=us-east1-b machine_type=e2-standard-2
```

### Docker Images

```bash
# Ubuntu 22.04 (jammy) systemd + Ansible image
just build-jammy-docker           # builds ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev
just push-jammy-docker            # pushes ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev

# Ubuntu 24.04 (noble) systemd + Ansible image
just build-noble-docker           # builds ghcr.io/pulibrary/vm-builds/ubuntu-24.04:dev
just push-noble-docker            # pushes ghcr.io/pulibrary/vm-builds/ubuntu-24.04:dev

# Ubuntu 26.04 (resolute) systemd + Ansible image
just build-resolute-docker        # builds ghcr.io/pulibrary/vm-builds/ubuntu-26.04:dev
just push-resolute-docker         # pushes ghcr.io/pulibrary/vm-builds/ubuntu-26.04:dev

# All Ubuntu releases in one go
just build-ubuntu-docker-all

# Rocky 9 systemd + Ansible image
just build-rocky-docker           # builds ghcr.io/pulibrary/vm-builds/rocky-9:dev
just push-rocky-docker            # pushes ghcr.io/pulibrary/vm-builds/rocky-9:dev
```

## Secrets & Config

Copy `.env.example` to `.env` and fill in values. Get these from the [Prancible](https://github.com/pulibrary/princeton_ansible) Vault. The will be read by Packer:

- `BIGFIX_MASTHEAD_URL`
- `RAPID7_TOKEN`
- `RAPID7_ATTRIBUTES`
- `FALCON_CID`

### Build

```bash
set -a; source .env; set +a
just build-ubuntu-aws
# or
just build-rocky-qemu 'sha256:<rocky sha256>' true
```

## Project Structure

```text
.
├── ansible/                   # Ansible provisioning
│   ├── roles/
│   │   ├── base/            # OS updates and packages
│   │   ├── users/           # User and SSH key management
│   │   ├── configure/       # System configuration
│   │   ├── clean/           # Image cleanup
│   │   ├── mirrors/         # Repository mirror configuration
│   │   └── security_firstboot/  # First-boot security setup
│   ├── collections.yaml     # Ansible Galaxy collections
│   └── linux-playbook.yml   # Main playbook
├── builds/
│   └── linux/
│       ├── rocky/           # Rocky Linux Packer configs
│       │   ├── data/        # Cloud-init templates
│       │   ├── isos/        # Rocky base images
│       │   ├── linux-rocky-aws.pkr.hcl
│       │   └── linux-rocky-qemu-cloudimg.pkr.hcl
│       └── ubuntu/          # Ubuntu Packer configs
│           ├── data/        # Cloud-init templates
│           ├── isos/        # Ubuntu base images
│           ├── linux-ubuntu-aws.pkr.hcl
│           ├── linux-ubuntu-gcp.pkr.hcl
│           └── linux-ubuntu-qemu-cloudimg.pkr.hcl
├── docker/                  # Docker image definitions
│   ├── rocky/
│   │   └── Dockerfile       # Rocky 9 systemd + Ansible
│   └── ubuntu/
│       └── Dockerfile       # Ubuntu 22.04 systemd + Ansible
├── justfile                 # Command shortcuts
└── devbox.json             # Development environment
```

Note: Build outputs are stored in `artifacts/` and `manifests/` directories (git-ignored).

## Supported Builds

### VM Images

| OS | Version | Platform | Status |
|---|---------|----------|---------|
| Ubuntu | 22.04 LTS | QEMU | Working |
| Ubuntu | 22.04 LTS | GCP | Template exists |
| Ubuntu | 22.04 LTS | AWS | Working |
| Rocky Linux | 9.4 | QEMU | Working |
| Rocky Linux | 9.4 | AWS | Working |

### Docker Images

| OS | Version | Registry | Status |
|---|---------|----------|---------|
| Ubuntu | 22.04 LTS | GHCR | Working |
| Rocky Linux | 9.4 | GHCR | Working |

## Building VM Images

### Build Images (Local Testing)

```bash
# Ubuntu QEMU build
packer build builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl

# Rocky Linux QEMU build
packer build builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl
```

### GCP Build

```bash
# Requires: gcloud auth application-default login
packer build -var "gcp_project_id=pul-gcdc" \
  builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl
```

### Build Outputs

- QEMU builds: `artifacts/qemu/[os-version]/`
  - `.qcow2` - QEMU image
  - `.vmdk` - VMware disk
  - `.vhd` - Hyper-V disk
  - `.ovf` - Open Virtualization Format

## Docker Images (systemd-capable, on GHCR)

In addition to VM images, this repo builds **systemd-capable** Docker images that double as Ansible control hosts. Images are published to **GitHub Container Registry (GHCR)** under:

- `ghcr.io/pulibrary/vm-builds/ubuntu-22.04:<tag>` (jammy)
- `ghcr.io/pulibrary/vm-builds/ubuntu-24.04:<tag>` (noble)
- `ghcr.io/pulibrary/vm-builds/ubuntu-26.04:<tag>` (resolute)
- `ghcr.io/pulibrary/vm-builds/rocky-9:<tag>`

These images:

- Run `systemd` as PID 1 (for testing services with units)
- Include `pulsys` with passwordless sudo
- Have Python + Ansible core installed in a `/opt/ansible` virtualenv, plus the collections in `ansible/collections.yaml`

### 1. Creating a Token for GHCR

GHCR uses **GitHub Packages**, which currently requires a **personal access token (classic)** for CLI access.  
You need:

- `read:packages` to pull images
- `write:packages` to push images (and optionally `delete:packages` if you want to delete packages)

Steps:

1. Log in to GitHub and go to  
   **Settings → Developer settings → Personal access tokens → Tokens (classic)**.
2. Click **"Generate new token (classic)"**.
3. Give it a descriptive name, e.g. `vm-builds-ghcr`.
4. Set an **expiration**.
5. Under **Scopes**, select at least:
   - `read:packages`
   - `write:packages`
6. Click **Generate token**, then copy the token somewhere safe (you won't be able to see it again).

Export it as an environment variable:

```bash
export GHCR_PAT=ghp_your_token_here
```

**Note**: In GitHub Actions, you usually don't need a PAT; use `GITHUB_TOKEN` with `packages: write` instead.

### 2. Logging in to GHCR

From your shell:

```bash
echo "$GHCR_PAT" | docker login ghcr.io -u "<your-github-username>" --password-stdin
# e.g.:
# echo "$GHCR_PAT" | docker login ghcr.io -u "kayiwa" --password-stdin
```

You should see `Login Succeeded`.

Or, using just:

```bash
just ghcr-login
```

(Uses `GHCR_PAT` / `GITHUB_TOKEN` / `GH_TOKEN` under the hood. If no token is
set but you are already logged in to `ghcr.io`, the existing login is reused.)

### 3. Building and Pushing Images (Local)

From the repo root:

```bash
# Ubuntu 22.04 (jammy) systemd + Ansible image
just build-jammy-docker           # builds ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev
just push-jammy-docker            # pushes ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev

# Ubuntu 24.04 (noble) systemd + Ansible image
just build-noble-docker           # builds ghcr.io/pulibrary/vm-builds/ubuntu-24.04:dev
just push-noble-docker            # pushes ghcr.io/pulibrary/vm-builds/ubuntu-24.04:dev

# Ubuntu 26.04 (resolute) systemd + Ansible image
just build-resolute-docker        # builds ghcr.io/pulibrary/vm-builds/ubuntu-26.04:dev
just push-resolute-docker         # pushes ghcr.io/pulibrary/vm-builds/ubuntu-26.04:dev

# Rocky 9 systemd + Ansible image
just build-rocky-docker           # builds ghcr.io/pulibrary/vm-builds/rocky-9:dev
just push-rocky-docker            # pushes ghcr.io/pulibrary/vm-builds/rocky-9:dev

# Push all Ubuntu releases at once
just push-ubuntu-docker-all
```

Each Ubuntu `push-*` recipe builds and links the image if needed, then
publishes both `:<tag>` and `:latest`, so an untagged pull resolves:

```bash
docker pull ghcr.io/pulibrary/vm-builds/ubuntu-24.04
```

### Using these images as Ansible targets

These images are built to be driven by an external Ansible controller (for
example Prancible's Molecule suite), so a few things are guaranteed:

- **`apt`/`dnf` metadata is kept in the image.** Package tasks work without
  `update_cache: true`; dropping the lists makes tasks fail with
  `No package matching '<name>' is available`.
- **Nothing sweeps `/tmp`.** The distro ships a systemd-tmpfiles rule that
  empties `/tmp` during boot. A controller connecting while the container is
  still booting could have its staged module deleted mid-task, failing with
  `can't open file .../AnsiballZ_setup.py: No such file or directory`. These
  images override that rule so `/tmp` contents are never removed.
- **No `VOLUME` declarations.** `/run`, `/tmp` and `/sys/fs/cgroup` are left to
  the caller to mount. Declaring them as volumes creates anonymous volumes that
  shadow the caller's mounts and makes copying files into those paths behave
  differently under Docker and Podman.
- **`python3` resolves to the system interpreter**, so modules that need
  system packages such as `python3-apt` work. Ansible itself lives in a
  `/opt/ansible` virtualenv that is deliberately kept off `PATH`.
- `/root/.ansible/tmp` (Ansible's default `remote_tmp`) and `/var/tmp/ansible`
  are pre-created and are ordinary directories, never mount points.
- **`pip3` accepts `--break-system-packages` on every release.** Ubuntu 22.04
  ships a pip too old to know that flag, while 24.04 and later require it to
  install into the system environment, so the same `ansible.builtin.pip` task
  would fail on 22.04 only. The 22.04 image upgrades its system pip to close
  that gap; newer releases keep their distro-managed pip.

### Architecture matters

Downstream consumers (Prancible's molecule suite on GitHub Actions) run on
**amd64**, while developer laptops are usually **arm64**. A container image
only runs on the architecture it was built for; publishing an arm64-only image
makes every command inside it fail with `Exec format error`, which surfaces
downstream as misleading Ansible errors such as "Failed to create temporary
directory".

Because of this, **all Ubuntu and Rocky build recipes produce a multi-arch
(amd64 + arm64) manifest by default**, and the `push-*` recipes refuse to
publish anything that does not include amd64.

```bash
# multi-arch (default)
just build-jammy-docker
just build-rocky-docker

# host architecture only: fast local iteration, never publish this
just build-jammy-docker-native
just build-rocky-docker-native
```

Multi-arch builds need working cross-architecture emulation. The recipes
check this up front and fail in seconds rather than minutes:

```bash
just check-emulation
# install emulation if it is missing:
docker run --privileged --rm docker.io/tonistiigi/binfmt --install all
```

If emulation is unavailable, let CI publish instead: the **container-images**
GitHub Actions workflow builds every Ubuntu release and Rocky 9 on a native
amd64 and arm64 runner, so no emulation is involved.

All Ubuntu releases share `docker/ubuntu/Dockerfile`; the release is chosen
with the `UBUNTU_VERSION` build argument, so any future release can be built
without editing the Dockerfile:

```bash
just build-ubuntu-docker dev 26.04
just push-ubuntu-docker  dev 26.04
```

You can override the tag (e.g., use a date or git SHA):

```bash
just build-jammy-docker 2025-11-13
just push-jammy-docker  2025-11-13

just build-noble-docker 2025-11-13
just push-noble-docker  2025-11-13

just build-resolute-docker 2025-11-13
just push-resolute-docker  2025-11-13
```

Resulting tags:

- `ghcr.io/pulibrary/vm-builds/ubuntu-22.04:2025-11-13`
- `ghcr.io/pulibrary/vm-builds/ubuntu-24.04:2025-11-13`
- `ghcr.io/pulibrary/vm-builds/ubuntu-26.04:2025-11-13`
- `ghcr.io/pulibrary/vm-builds/rocky-9:2025-11-13`

To alias a built image so the short local name, the fully qualified GHCR
name, and the GHCR `:latest` tag all point at the same image (the image is
built first if it is not present locally):

```bash
# ubuntu-22.04:dev <-> ghcr.io/pulibrary/vm-builds/ubuntu-22.04
just link-jammy-docker

# ubuntu-24.04:dev <-> ghcr.io/pulibrary/vm-builds/ubuntu-24.04
just link-noble-docker

# ubuntu-26.04:dev <-> ghcr.io/pulibrary/vm-builds/ubuntu-26.04
just link-resolute-docker

# all releases at once
just link-ubuntu-docker-all
```

### 4. Pulling and Running the Images

Pull:

```bash
docker pull ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev
docker pull ghcr.io/pulibrary/vm-builds/ubuntu-24.04:dev
docker pull ghcr.io/pulibrary/vm-builds/ubuntu-26.04:dev
docker pull ghcr.io/pulibrary/vm-builds/rocky-9:dev
```

To run with systemd inside the container (requires `--privileged` and cgroup mounts):

```bash
# Ubuntu
docker run --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v /run:/run \
  -v /tmp:/tmp \
  -d --name ubuntu-systemd \
  ghcr.io/pulibrary/vm-builds/ubuntu-22.04:dev

# Rocky
docker run --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:ro \
  -v /run:/run \
  -v /tmp:/tmp \
  -d --name rocky-systemd \
  ghcr.io/pulibrary/vm-builds/rocky-9:dev
```

Inside the container you can then:

```bash
docker exec -it ubuntu-systemd bash
systemctl status
ansible-galaxy collection list
```

## Ansible Roles

### base

- Updates all packages to latest
- Installs essential packages
- Configures cloud-init (when enabled)

### users

- Creates `pulsys` user with sudo access
- Pulls SSH keys from GitHub for:
  - Operations staff
  - Library development staff
  - Ansible Tower Keys
- Manages build users (`packer`, `ubuntu`)

### configure

- Enables SSH public key authentication
- Sets hostname to `localhost`
- Configures cloud-init datasources
- Regenerates SSH host keys on first boot

### mirrors

- Configures repository mirrors for faster package downloads
- Supports both Ubuntu and Rocky Linux mirror configurations

### security_firstboot

- Installs and configures security tools on first boot:
  - BigFix endpoint management
  - Rapid7 InsightAgent
  - CrowdStrike Falcon sensor
- Configures firewalls (UFW for Ubuntu, firewalld for Rocky)
- Sets up fail2ban for SSH protection
- Hardens SSH configuration

### clean

- Removes temporary files and logs
- Cleans build artifacts
- Optionally removes build users
- Clears machine-id for uniqueness

## User Management

### pulsys Administrative User

The `pulsys` user is automatically created with SSH keys from:

```yaml
# ansible/roles/users/defaults/main.yml
ops_github_keys:
  - https://github.com/acozine.keys
  - https://github.com/kayiwa.keys
  # ... additional ops staff

library_github_keys:
  - https://github.com/escowles.keys
  - https://github.com/hackartisan.keys
  # ... additional library staff
```

To add/remove users, update the lists in `ansible/roles/users/defaults/main.yml`.

### Build Cleanup

Set `cleanup_final_image=true` to remove build users from the final image:

```bash
packer build -var "cleanup_final_image=true" [template]
```

Protected users (`root`, `pulsys`) are never removed.

## Testing Images

### Local QEMU Testing

```bash
# Boot the image
qemu-system-x86_64 \
    -m 2048 -smp 2 \
    -accel tcg,thread=multi \
    -drive file="artifacts/qemu/linux-ubuntu-22-04-lts-20250922-062113/linux-ubuntu-22-04-lts-20250922-062113.qcow2",if=virtio,format=qcow2,cache=writeback \
    -netdev user,id=n1,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=n1 \
    -serial mon:stdio -display

# SSH into the VM (in another terminal)
ssh -p 2222 pulsys@localhost
```

## Configuration Variables

Common Packer variables:

```hcl
# User settings
build_username = "packer"
ansible_username = "packer"
build_key = "ssh-rsa ..."     # SSH key for build user
ansible_key = "ssh-rsa ..."   # SSH key for ansible user

# Image settings
disk_size = 30                # GB
vm_guest_os_cloudinit = true  # Enable cloud-init

# Cleanup
cleanup_final_image = true    # Remove build artifacts
```

## Troubleshooting

### ISO Checksum Error

**Problem**: `invalid checksum: encoding/hex: invalid byte`  
**Solution**: Download the ISO and update the checksum in the `.pkr.hcl` file

### SSH Timeout During Build

**Problem**: Packer can't connect to the VM  
**Solution**: Check QEMU is working and increase `ssh_timeout`

### Missing Dependencies

**Problem**: Command not found errors  
**Solution**: Use `devbox shell` or install missing tools manually

### Build Users Remain in Image

**Problem**: `ubuntu` or `packer` users still present  
**Solution**: Set `-var "cleanup_final_image=true"` during build

### Docker Login Failed

**Problem**: Unable to authenticate with GHCR  
**Solution**: Ensure your PAT has `read:packages` and `write:packages` scopes, and verify you're using the correct username

### Systemd Not Working in Container

**Problem**: `systemctl` commands fail in Docker container  
**Solution**: Ensure you're using `--privileged` and mounting cgroups correctly as shown in the run examples

## Build Manifests

Each build generates a manifest in `manifests/` containing:

- Build timestamp
- Git commit hash
- Image metadata
- Custom variables used

Example: `manifests/2025-11-13 11:07:49.json`

## Contributing

1. Create a feature branch
2. Test changes locally with QEMU or Docker
3. Validate Packer templates: `packer validate [template]`
4. Test Docker builds: `docker build -f docker/[os]/Dockerfile .`
5. Submit pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

See [LICENSE](LICENSE) file for details.

---

**Maintained by**: Princeton University Library  
**Repository**: <https://github.com/pulibrary/vm-builds>
