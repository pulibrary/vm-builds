# vm-builds
Packer templates for creating Server Images with Packer + QEMU + Autoinstall (cloud-init)

## Cloud Init

[Cloud-Init](https://cloud-init.io) will need to be installed
[QEMU](https://qemu.org) Quick Emulator will also need to be installed

Currently Supported Images:

| Name                | Version       |
|:--------------------|:-------------:|
| __Jammy Jellyfish__ |     `22.04.4` |


## Usage

Use GNU-Make to perform validation / build images:

### Validation

To validate `cloud-init` and `ubuntu.pkr.hcl` template perform

```bash
make validate
```

To simply validate `cloud-init` against all distros

```bash
make validate-cloudinit
```

To validate `cloud-init` configuration of a specific distro (`focal`, `jammy`, `noble`)

```bash
make validate-cloudinit-<distroname> # <distroname> here is either focal, jammy or noble
```

To simply validate `ubuntu.pkr.hcl` template against all distros

```bash
make validate-packer
```

### Build Images

to build Ubuntu 22.04 (Jammy) image

```bash
make build-jammy
```
