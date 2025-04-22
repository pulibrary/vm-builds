# VM-Builds

Packer templates for creating server images with:
- Packer
- QEMU (for local VM images)
- AWS (for AMI creation)
- GCP (for GCE image creation)
- Autoinstall (cloud-init)

## Requirements

- [Packer](https://www.packer.io/) (v1.8.0+)
- [QEMU](https://www.qemu.org/) (for local VM building)
- [AWS CLI](https://aws.amazon.com/cli/) (configured with proper credentials for AWS AMI building)
- [Google Cloud SDK](https://cloud.google.com/sdk) (configured with proper credentials for GCP image building)
- [Cloud-Init](https://cloud-init.io/) (for validation, optional)

## Supported Images

| Distribution | Version | Build Types |
|:-------------|:-------:|:------------|
| **Ubuntu Jammy Jellyfish** | `22.04.4` | QEMU, AWS, GCP |


## Usage

This project uses GNU-Make to streamline building and validation.

### Validation

#### Validate All Templates
```bash
make validate
````

#### Validate Cloud-Init Configuration

```
bash
# Validate all cloud-init configurations
make validate-cloudinit

# Validate specific distro (currently only jammy)
make validate-cloudinit-jammy
```

#### Validate Packer Templates

```
bash
# Validate all packer templates
make validate-packer

# Validate only QEMU template
make validate-jammy

# Validate only AWS template
make validate-aws-jammy

# Validate only GCP template
make validate-gcp-jammy
```

### Building Images

#### QEMU Images (Local VMs)

```
bash
# Build Ubuntu 22.04 (Jammy) QEMU image
make build-jammy
```

#### AWS AMIs

```
bash
# Build Ubuntu 22.04 (Jammy) AWS AMI
make build-aws-jammy
```

#### GCP Images

```
bash
# Build Ubuntu 22.04 (Jammy) GCP image
make build-gcp-jammy
```

## Cloud Provider Configuration

### AWS AMI Building

Before building AWS AMIs, ensure:

1. You have AWS CLI installed and configured with proper credentials

2. The AWS CLI profile has permissions to:

   * Create and modify EC2 instances
   * Create AMIs
   * Create and modify security groups
   * Create and delete key pairs

You can customize the AWS build by editing `vars/aws-jammy.pkrvars.hcl` to change:

* AWS region
* Instance type
* AMI name prefix
* Other AWS-specific settings

### GCP Image Building

Before building GCP images, ensure:

1. You have Google Cloud SDK installed and configured with proper credentials

2. Your GCP account has permissions to:

   * Create and delete compute instances
   * Create disk images
   * Create and modify firewall rules

You must customize the GCP build by editing `vars/gcp-jammy.pkrvars.hcl` to set:

* Your GCP project ID
* Zone preference
* Machine type
* Other GCP-specific settings


## Troubleshooting

### Common Issues

1. **Missing cloud-init command**: The validation will skip cloud-init validation if the command is not available
2. **AWS credential issues**: Ensure your AWS credentials are properly configured with `aws configure`
3. **GCP credential issues**: Ensure you're authenticated with `gcloud auth login` and have set your project with `gcloud config set project YOUR_PROJECT_ID`
4. **QEMU errors**: Check that OVMF firmware files are installed on your system
5. **Permission issues**: For cloud providers, check that your account has the necessary permissions to create instances and images
