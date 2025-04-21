# VM-Builds

Packer templates for creating server images with:
- Packer
- QEMU (for local VM images)
- AWS (for AMI creation)
- Autoinstall (cloud-init)

## Requirements

- [Packer](https://www.packer.io/) (v1.8.0+)
- [QEMU](https://www.qemu.org/) (for local VM building)
- [AWS CLI](https://aws.amazon.com/cli/) (configured with proper credentials for AWS AMI building)
- [Cloud-Init](https://cloud-init.io/) (for validation, optional)

## Supported Images

| Distribution | Version | Build Types |
|:-------------|:-------:|:------------|
| **Ubuntu Jammy Jellyfish** | `22.04.4` | QEMU, AWS |

.
├── http/                # Cloud-init configurations
│   └── jammy/           # Ubuntu 22.04 specific configs
├── templates/           # Packer template files
│   ├── qemu-jammy-winter.pkr.hcl  # QEMU template for Ubuntu 22.04
│   ├── aws-jammy.pkr.hcl          # AWS template for Ubuntu 22.04
│   └── scripts/         # Provisioning scripts
└── vars/                # Variable files for templates
├── jammy.pkrvars.hcl       # QEMU variables
└── aws-jammy.pkrvars.hcl   # AWS variables

## Usage

This project uses GNU-Make to streamline building and validation.

### Validation

#### Validate All Templates
```bash
make validate
```


#### Validate Cloud-Init Configuration

```bash
# Validate all cloud-init configurations
make validate-cloudinit

# Validate specific distro (currently only jammy)
make validate-cloudinit-jammy
```

#### Validate Packer Templates

```bash
# Validate all packer templates
make validate-packer

# Validate only QEMU template
make validate-jammy

# Validate only AWS template
make validate-aws-jammy
```

### Building Images

#### QEMU Images (Local VMS)

```bash
# Build Ubuntu 22.04 (Jammy) QEMU image
make build-jammy
```

#### AWS AMIs

```bash
# Build Ubuntu 22.04 (Jammy) AWS AMI
make build-aws-jammy
```

#### AWS AMI Building

Before building AWS AMIs, ensure:

1. You have AWS-CLI installed and configured
2. The AWS CLI profile has permissions to:
  * Create and modify EC2 instances
  * Create AMIs
  * Create and modify security groups
  * Create and delete key pairs

You can customize the AWS build by editing `vars/aws-jammy.pkrvars.hcl` to change:

AWS region
Instance type
AMI name prefix
Other AWS-specific settings
