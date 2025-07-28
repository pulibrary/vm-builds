# VM-Builds

Packer templates for creating server images using **just** as a task runner:

- **Packer** for template-driven builds
- **QEMU** for local VM image creation
- **AWS** for AMI creation
- **GCP** for GCE image creation
- **Cloud-Init** for autoinstall validation (optional)

---

## Requirements

- [Packer](https://www.packer.io/) v1.8.0 or higher
- [QEMU](https://www.qemu.org/) (for local VM builds)
- [AWS CLI](https://aws.amazon.com/cli/) configured for AMI building
- [Google Cloud SDK](https://cloud.google.com/sdk) configured for GCP image builds
- [Cloud-Init](https://cloud-init.io/) (for schema validation, optional)
- [just](https://github.com/casey/just) v1.0 or higher (task runner)

---

## Supported Images

| Distribution               | Version   | Build Targets  |
| -------------------------- | --------- | -------------- |
| **Ubuntu Jammy Jellyfish** | `22.04.4` | QEMU, AWS, GCP |

---

## Usage

All workflows are exposed via `just` recipes defined in the top-level `justfile`.

### Initialization

Prepare any missing Packer plugins:

```bash
just init-qemu
just init-aws
just init-gcp
```

### Validation

#### Validate all Packer templates

```bash
just validate
```

> (runs `validate-jammy`, `validate-aws-jammy`, `validate-gcp-jammy`)

#### Validate only one Packer target

```bash
just validate-jammy      # QEMU only\ njust validate-aws-jammy  # AWS AMI
just validate-gcp-jammy   # GCP image
```

#### Validate Cloud-Init config

```bash
just validate-cloudinit
```

> (schema-checks `http/jammy/user-data` if `cloud-init` is installed)

### Building Images

#### Local QEMU VM

```bash
just build-jammy
```

Runs a headless QEMU build with `vars/jammy.pkrvars.hcl`.

##### Debug mode

```bash
just build-jammy debug=true
# or equivalently
just build-jammy-debug
```

> Enables `-debug` and extra logging in Packer.

#### AWS AMI

```bash
just build-aws-jammy
```

Creates an AMI in AWS using `vars/aws-jammy.pkrvars.hcl`.

##### Debug mode

```bash
just build-aws-jammy debug=true
```

Or:

```bash
just build-aws-jammy-debug
```

#### GCP Image

```bash
just build-gcp-jammy
```

Builds a GCE image using `vars/gcp-jammy.pkrvars.hcl`.

##### Debug mode

```bash
just build-gcp-jammy debug=true
```

Or:

```bash
just build-gcp-jammy-debug
```

---

## Cloud Provider Configuration

### AWS

- Credentials via AWS CLI (`aws configure`).
- Edit `vars/aws-jammy.pkrvars.hcl` to set:
  - `region`, `instance_type`, `ami_name`, etc.

### GCP

- Credentials via `gcloud auth login`.
- Edit `vars/gcp-jammy.pkrvars.hcl` to set:
  - `project_id`, `zone`, `machine_type`, etc.

---

## Troubleshooting

- **Missing **``: Schema validation will skip if not installed.
- **AWS/GCP permissions**: Ensure proper IAM roles and CLI config.
- **QEMU errors**: If running on macOS, ensure `headless = true` in the QEMU source block or adjust to `display = "cocoa"` to avoid GTK.
- **Firewall/Networking**: Verify host ports (e.g. SSH forwarding ranges) are free.

---

> For further details, inspect the `justfile` for available commands and flags.

