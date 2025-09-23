# VM Builds

Infrastructure-as-Code repository for building standardized virtual machine images using Packer and Ansible.

## Overview

This repository contains Packer templates and Ansible playbooks for creating consistent, secure golden images for Princeton University Library infrastructure. Currently supports Ubuntu 22.04 LTS and Rocky Linux 9.4.

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
- Git
- Just

### Manual Installation

If not using Devbox, (you know what you're doing :wink:) manually install:
- Packer >= 1.12.0
- Ansible >= 2.9
- Python >= 3.8
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

```bash
# Ubuntu QEMU (requires the cloud-image checksum)
# Exmaple checksum shown; replace with the current release checksum
just build-ubuntu-qemu 'sha256:b119a978dcb66194761674c23a860a75cdb7778e95e222b51d7a3386dfe3c920' true

# Rocky QEMU (also requires checksum)
just build-rocky-qemu 'sha256:<rocky_cloud_image_sha256_here>'

# Ubuntu AWS AMI
just build-ubuntu-aws

# Rocky AWS AMI
just build-rocky-aws

# Ubuntu GCP image (failing for now)
just build-ubuntu-gcp pul-gcdc zone=us-east1-b machine_type=e2-standard-2

```

## Secrets & config

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

```
.
├── ansible/                   # Ansible provisioning
│   ├── roles/
│   │   ├── base/            # OS updates and packages
│   │   ├── users/           # User and SSH key management
│   │   ├── configure/       # System configuration
│   │   └── clean/           # Image cleanup
│   └── linux-playbook.yml   # Main playbook
├── artifacts/                # Build outputs (git-ignored)
├── builds/
│   └── linux/
│       ├── rocky/           # Rocky Linux configs
│       └── ubuntu/          # Ubuntu configs
├── manifests/               # Build metadata
└── devbox.json             # Development environment
```

## Supported Builds

| OS | Version | Platform | Status |
|---|---------|----------|---------|
| Ubuntu | 22.04 LTS | QEMU | Working |
| Ubuntu | 22.04 LTS | GCP | Template exists |
| Ubuntu | 22.04 LTS | AWS | Working |
| Rocky Linux | 9.4 | QEMU | Working |
| Rocky Linux | 9.4 | AWS | Working |

## Building Images

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
- Sets hostname to `lib-vm`
- Configures cloud-init datasources
- Regenerates SSH host keys on first boot

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

## Build Manifests

Each build generates a manifest in `manifests/` containing:
- Build timestamp
- Git commit hash
- Image metadata
- Custom variables used

Example: `manifests/2025-09-19 19:17:41.json`

## Contributing

1. Create a feature branch
2. Test changes locally with QEMU
3. Validate Packer templates: `packer validate [template]`
4. Submit pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

See [LICENSE](LICENSE) file for details.

---

**Maintained by**: Princeton University Library
**Repository**: https://github.com/pulibrary/vm-builds
