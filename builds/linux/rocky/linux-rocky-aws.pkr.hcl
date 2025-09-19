// © Broadcom. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause
// Packer + Amazon EBS (AMI) using base public AMI + cloud-init + Ansible
// Directory: builds/linux/rocky

packer {
  required_version = ">= 1.12.0"
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = ">= 1.3.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.2"
    }
    git = {
      source  = "github.com/ethanmdavidson/git"
      version = ">= 0.6.3"
    }
  }
}

/////////////////////////////
// Variables               //
/////////////////////////////

// Naming / OS metadata
variable "vm_guest_os_family" {
  type    = string
  default = "linux"
}

variable "vm_guest_os_name" {
  type    = string
  default = "rocky"
}

variable "vm_guest_os_version" {
  type    = string
  default = "9.4"
}

// AWS basics
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "aws_subnet_id" {
  type    = string
  default = null
}

variable "aws_security_group_id" {
  type    = string
  default = null
}

variable "aws_iam_instance_profile" {
  type    = string
  default = null
}

variable "associate_public_ip" {
  type    = bool
  default = true
}

// AMI source filters (defaults target Rocky Linux 9 x86_64 Base images)
// NOTE: Verify/override owners for your region/account. These are placeholders.
variable "source_ami_owners" {
  type    = list(string)
  default = ["679593333241"] // <— Replace with the official Rocky AMI owner(s) for your region as needed
}

variable "source_ami_filters" {
  type = map(string)
  default = {
    name                = "Rocky-9-EC2-Base-*x86_64*"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
    architecture        = "x86_64"
  }
}

// AMI output + root volume
variable "ami_encrypted" {
  type    = bool
  default = true
}

variable "ami_kms_key_id" {
  type    = string
  default = null
}

variable "root_volume_size_gb" {
  type    = number
  default = 30
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "delete_on_termination" {
  type    = bool
  default = true
}

// Communicator / users (base AMI defaults)
variable "ssh_username" {
  type    = string
  default = "rocky"
}

variable "communicator_timeout" {
  type    = string
  default = "30m"
}

// Users for provisioning (aligned with QEMU builds)
variable "build_username" {
  type    = string
  default = "packer"
}

variable "build_password" {
  type      = string
  default   = "packer"
  sensitive = true
}

variable "build_password_encrypted" {
  type      = string
  default   = ""
  sensitive = true
}

variable "build_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ansible_username" {
  type      = string
  default   = "packer"
  sensitive = true
}

variable "ansible_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "vm_guest_os_language" {
  type    = string
  default = "en_US.UTF-8"
}

variable "vm_guest_os_keyboard" {
  type    = string
  default = "us"
}

variable "vm_guest_os_timezone" {
  type    = string
  default = "UTC"
}

variable "vm_guest_os_cloudinit" {
  type    = bool
  default = true
}

variable "additional_packages" {
  type    = list(string)
  default = []
}

// Toggle to run final cleanup role
variable "cleanup_final_image" {
  type    = bool
  default = true
}

////////////////////
// Data & Locals  //
////////////////////

data "git-repository" "cwd" {}

locals {
  build_by          = "Built by: HashiCorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version     = data.git-repository.cwd.head
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"

  manifest_date   = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path   = "${abspath(path.root)}/../../../manifests/"
  manifest_output = "${local.manifest_path}${local.manifest_date}.json"

  vm_name  = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${local.build_version}"
  ami_name = local.vm_name

  common_tags = {
    Name       = local.ami_name
    os_family  = var.vm_guest_os_family
    os_name    = var.vm_guest_os_name
    os_version = var.vm_guest_os_version
    build_date = local.build_date
    build_hash = local.build_version
  }
}

//////////////////////////
// Amazon EBS (AMI)     //
//////////////////////////

source "amazon-ebs" "linux-aws-ami" {
  region        = var.aws_region
  instance_type = var.aws_instance_type

  ami_name        = local.ami_name
  ami_description = local.build_description

  # Tags for the created AMI (and its snapshot)
  tags          = local.common_tags
  snapshot_tags = local.common_tags

  # Root volume mapping for the launched build instance
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size_gb
    delete_on_termination = var.delete_on_termination
    encrypted             = var.ami_encrypted
    kms_key_id            = var.ami_kms_key_id
  }

  # Networking / IAM (optional)
  subnet_id                   = var.aws_subnet_id
  security_group_id           = var.aws_security_group_id
  associate_public_ip_address = var.associate_public_ip
  iam_instance_profile        = var.aws_iam_instance_profile

  # Base AMI selection (Rocky Linux)
  source_ami_filter {
    filters     = var.source_ami_filters
    owners      = var.source_ami_owners
    most_recent = true
  }

  # Communicator
  ssh_username = var.ssh_username
  ssh_timeout  = var.communicator_timeout
}

//////////////
// Build     //
//////////////

build {
  sources = ["source.amazon-ebs.linux-aws-ami"]

  # Reuse Linux playbook/roles (same as QEMU/Ubuntu AWS)
  provisioner "ansible" {
    user                   = var.ssh_username
    galaxy_file            = "${abspath(path.root)}/../../../ansible/linux-requirements.yml"
    galaxy_force_with_deps = true
    playbook_file          = "${abspath(path.root)}/../../../ansible/linux-playbook.yml"
    roles_path             = "${abspath(path.root)}/../../../ansible/roles"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${abspath(path.root)}/../../../ansible/ansible.cfg",
      "OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES", // macOS fork-safety fix
    ]
    extra_arguments = [
      "--extra-vars", "display_skipped_hosts=false",
      "--extra-vars", "build_username=${var.build_username}",
      "--extra-vars", "build_key='${var.build_key}'",
      "--extra-vars", "ansible_username=${var.ansible_username}",
      "--extra-vars", "ansible_key='${var.ansible_key}'",
      "--extra-vars", "enable_cloudinit=${var.vm_guest_os_cloudinit}",
      "--extra-vars", "cleanup_final_image=${var.cleanup_final_image}",
      "--forks", "1"
    ]
  }

  # Manifest
  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_date            = local.build_date
      build_version         = local.build_version
      aws_region            = var.aws_region
      ami_name              = local.ami_name
      root_volume_size_gb   = var.root_volume_size_gb
      root_volume_type      = var.root_volume_type
      delete_on_termination = var.delete_on_termination
      ssh_username          = var.ssh_username
      enable_cloudinit      = var.vm_guest_os_cloudinit
      ansible_username      = var.ansible_username
      build_username        = var.build_username
    }
  }
}

