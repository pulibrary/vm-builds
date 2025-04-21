packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables for AWS configuration
variable "ubuntu_distro" {
  type = string
}

variable "ubuntu_version" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "vm_template_name" {
  type    = string
  default = "packer-aws-ubuntu"
}

# Optional variables with sensible defaults
variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "associate_public_ip_address" {
  type    = bool
  default = true
}

locals {
  vm_name    = "${var.vm_template_name}-${var.ubuntu_version}"
  output_dir = "output/${local.vm_name}"
  timestamp  = formatdate("YYYYMMDD-hhmmss", timestamp())
  ami_name   = "${local.vm_name}-${local.timestamp}"
}

source "amazon-ebs" "ubuntu" {
  ami_name        = local.ami_name
  instance_type   = var.instance_type
  region          = var.aws_region
  
  # Use the official Ubuntu AMI as the source
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-*-${var.ubuntu_version}-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical's AWS account ID
  }

  ssh_username = var.ssh_username
  
  # Make the instance publicly accessible for Packer to connect
  associate_public_ip_address = var.associate_public_ip_address

  # Use a temporary SSH key pair for building
  temporary_key_pair_type = "ed25519"

  # Add tags to the resulting AMI
  tags = {
    Name        = local.ami_name
    Environment = "dev"
    Builder     = "Packer"
    OS          = "Ubuntu"
    Version     = var.ubuntu_version
    BuildDate   = local.timestamp
  }
}

build {
  name    = "ubuntu-aws"
  sources = ["source.amazon-ebs.ubuntu"]

  # Wait till Cloud-Init has finished
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for Cloud-Init...'; sleep 1; done"
    ]
  }

  # Install necessary packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y nginx openssh-server",
      "sudo systemctl enable nginx"
    ]
  }

  # Create the output directory for manifest
  provisioner "shell-local" {
    inline = [
      "mkdir -p ${local.output_dir}"
    ]
  }

  # Post-processing steps for the AMI
  post-processor "manifest" {
    output     = "${local.output_dir}/manifest.json"
    strip_path = true
    custom_data = {
      ami_name = local.ami_name
      timestamp = local.timestamp
    }
  }
}
