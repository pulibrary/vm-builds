# VM Builds - Golden Image Repository

Infrastructure-as-Code repository for building standardized virtual machine images across multiple cloud platforms using Packer and Ansible.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Supported Platforms](#supported-platforms)
- [Configuration](#configuration)
- [Building Images](#building-images)
- [Ansible Roles](#ansible-roles)
- [User Management](#user-management)
- [Testing](#testing)
- [CI/CD](#cicd)
- [Contributing](#contributing)
- [License](#license)

## Overview

This repository contains Packer templates and Ansible playbooks for creating consistent, secure, and production-ready golden images across multiple virtualization and cloud platforms. These images serve as standardized base templates for deploying infrastructure at Princeton University Library.

### Key Technologies

- **Packer**: Automates the creation of machine images
- **Ansible**: Handles configuration management and provisioning
- **Devbox**: Provides consistent development environment
- **Cloud-init**: Enables cloud instance initialization
- **QEMU**: Local virtualization for testing

## Features

- **Multi-Platform Support**: Build images for AWS, GCP, and QEMU/KVM
- **Security-First**: SSH key authentication, sudo management, and user access controls
- **Dynamic User Management**: GitHub-based SSH key distribution for ops and library staff
- **Consistent Environment**: Devbox ensures reproducible builds across teams

## Prerequisites

### Required Software

- [Devbox](https://www.jetbox.io/devbox) (recommended) OR manually install:
  - Packer >= 1.12.0
  - Ansible >= 2.9
  - Python >= 3.8
  - AWS CLI v2 (for AWS builds)
  - Google Cloud SDK (for GCP builds)
  - QEMU (for local builds)

### Cloud Credentials

For cloud builds, ensure appropriate credentials are configured:

- **AWS**: Configure AWS CLI (`aws configure`) or set environment variables
- **GCP**: Authenticate with `gcloud auth application-default login`

## Quick Start

### Using Devbox (Recommended)

```bash
# Clone the repository
git clone https://github.com/pulibrary/vm-builds.git
cd vm-builds

# Enter the Devbox shell
devbox shell

# Build an Ubuntu image for QEMU
just build-ubuntu-qemu

# Build a Rocky Linux image for AWS
just build-rocky-aws
```

### Manual Setup

```bash
# Install dependencies
pip install -r requirements.txt
ansible-galaxy install -r ansible/linux-requirements.yml

# Build an image
packer build -var-file=variables.pkrvars.hcl builds/linux/ubuntu/linux-ubuntu-qemu-cloudimg.pkr.hcl
```

## Project Structure

```
.
├── ansible/                    # Ansible configuration management
│   ├── roles/                 # Ansible roles for image configuration
│   │   ├── base/             # Base OS configuration
│   │   ├── users/            # User management (including pulsys)
│   │   ├── configure/        # System configuration
│   │   └── clean/            # Image cleanup and preparation
│   ├── linux-playbook.yml    # Main Linux provisioning playbook
│   └── linux-requirements.yml # Ansible Galaxy dependencies
├── artifacts/                 # Build output directory (git-ignored)
│   └── qemu/                 # QEMU build artifacts
├── builds/                    # Packer build configurations
│   └── linux/
│       ├── rocky/            # Rocky Linux templates
│       └── ubuntu/           # Ubuntu templates
├── manifests/                # Build manifests and metadata
├── devbox.json              # Devbox environment configuration
├── devbox.lock              # Locked dependency versions
├── justfile                 # Build automation commands
└── Makefile                 # Legacy build automation
```

## Supported Platforms

### Operating Systems

| OS | Version | Cloud-init | Status |
|---|---------|------------|---------|
| Ubuntu | 22.04 LTS | ✅ | Production |
| Rocky Linux | 9.4 | ✅ | Production |
| Windows | TBD | ❌ | In Development |

### Target Platforms

- **QEMU/KVM**: Local testing and on-premise virtualization
- **AWS EC2**: Amazon Web Services deployments
- **Google Compute Engine**: Google Cloud Platform deployments
- **VMware vSphere**: (convert QEMU)

## Configuration

### Variables

Key variables can be configured through:
1. Environment variables
2. `.pkrvars.hcl` files
3. Command-line flags

Common variables:

```hcl
# Cloud Platform
gcp_project_id = "your-project-id"
aws_region = "us-east-1"

# Image Settings
disk_size_gb = 30
vm_guest_os_cloudinit = true

# User Configuration
build_username = "packer"
ansible_username = "ansible"

# Cleanup
cleanup_final_image = true  # Remove build artifacts from final image
```

## Building Images

### Using Just (Recommended)

```bash
# List available commands
just

# Build Ubuntu for all platforms
just build-ubuntu-all

# Build Rocky for QEMU only
just build-rocky-qemu

# Clean build artifacts
just clean
```

### Direct Packer Commands

```bash
# Validate template
packer validate builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl

# Build with variables
packer build \
  -var "gcp_project_id=my-project" \
  -var "cleanup_final_image=true" \
  builds/linux/ubuntu/linux-ubuntu-gcp.pkr.hcl
```

## Ansible Roles

### base
- Updates the operating system
- Installs essential packages
- Configures cloud-init (if enabled)

### users
- Creates system users (packer, ansible, pulsys)
- Configures SSH keys from GitHub
- Sets up sudo permissions
- **Special**: `pulsys` user gets keys from:
  - Ansible Tower
  - Operations staff (GitHub)
  - Library staff (GitHub)

### configure
- Sets up SSH for public key authentication
- Configures hostname and networking
- Manages systemd services
- Prepares cloud-init datasources

### clean
- Removes temporary files and logs
- Cleans SSH host keys (regenerated on first boot)
- Removes build users (optional)
- Truncates machine-id for unique instances

## User Management

### pulsys User

The `pulsys` user is a special administrative account with dynamically managed SSH keys pulled from GitHub:

```yaml
# In ansible/roles/users/defaults/main.yml
ops_github_keys:
  - https://github.com/acozine.keys
  - https://github.com/kayiwa.keys
  # ... more ops staff

library_github_keys:
  - https://github.com/escowles.keys
  - https://github.com/hackartisan.keys
  # ... more library staff
```

Keys are automatically fetched and installed during the build process.

### Build vs. Runtime Users

- **Build-time users** (`packer`, `ubuntu`, etc.): Can be removed with `cleanup_final_image=true`
- **Runtime users** (`pulsys`, `root`): Always preserved
- **Protected users**: Defined in `users_keep_always` variable

## Testing

### Local Testing with QEMU

```bash
# Build a test image
just build-ubuntu-qemu

# Test the image with QEMU
qemu-system-x86_64 \
  -m 2048 \
  -drive file=artifacts/qemu/linux-ubuntu-22.04-lts-*/linux-ubuntu-22.04-lts-*.qcow2,format=qcow2 \
  -enable-kvm
```

### Validation

```bash
# Validate all Packer templates
for template in builds/linux/*/*.pkr.hcl; do
  echo "Validating $template"
  packer validate "$template"
done

# Lint Ansible playbooks
ansible-lint ansible/
```

## CI/CD

Build manifests are automatically generated in `manifests/` with:
- Build timestamp
- Git commit hash
- Image metadata
- Platform-specific details

Example manifest:
```json
{
  "builds": [{
    "artifact_id": "img-linux-ubuntu-22-04-lts-abc123",
    "build_date": "2025-09-19 19:17:41",
    "build_version": "i163_new_standard",
    "custom_data": {
      "enable_cloudinit": true,
      "disk_size_gb": 30,
      "image_family": "linux-ubuntu-2204"
    }
  }]
}
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Troubleshooting

### Common Issues

**Issue**: Build fails with "SSH timeout"
- **Solution**: Increase `communicator_timeout` variable

**Issue**: Cloud-init not working
- **Solution**: Ensure `enable_cloudinit=true` and check datasource configuration

**Issue**: Missing dependencies in Devbox
- **Solution**: Run `devbox update` to refresh packages

**Issue**: pulsys keys not updating
- **Solution**: Check GitHub URLs are accessible and users have public keys

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

---

**Maintained by**: Princeton University Library Operations Team  
