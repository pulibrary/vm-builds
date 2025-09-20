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

If not using Devbox, manually install:
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

# Download Ubuntu cloud image (first time only)
cd builds/linux/ubuntu/isos
wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
# Update the ISO checksum in the .pkr.hcl file
cd ../../../..

# Build an Ubuntu QEMU image
packer build builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl
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
| Ubuntu | 22.04 LTS | QEMU | ✅ Working |
| Ubuntu | 22.04 LTS | GCP | ✅ Working |
| Ubuntu | 22.04 LTS | AWS | 🚧 Template exists |
| Rocky Linux | 9.4 | QEMU | ✅ Working |
| Rocky Linux | 9.4 | AWS | 🚧 Template exists |

## Building Images

### QEMU Build (Local Testing)

```bash
# Ubuntu QEMU build
packer build builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl

# Rocky Linux QEMU build  
packer build builds/linux/rocky/linux-rocky-qemu-cloudimg.pkr.hcl
```

### GCP Build

```bash
# Requires: gcloud auth application-default login
packer build -var "gcp_project_id=your-project" \
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
  - Ansible Tower
- Manages build users (`packer`, `ubuntu`)

### configure
- Enables SSH public key authentication
- Sets hostname to `localhost`
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
  -m 2048 \
  -drive file=artifacts/qemu/linux-ubuntu-*/linux-ubuntu-*.qcow2,format=qcow2 \
  -enable-kvm \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device e1000,netdev=net0

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

**Maintained by**: Princeton University Library Operations Team  
**Repository**: https://github.com/pulibrary/vm-builds