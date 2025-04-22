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

variable "username" {
  type    = string
  default = "pulsys"
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
      "sudo apt-get install -y openssh-server"
    ]
  }
  
  # Create the pulsys user before running any scripts that depend on it
  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash ${var.username}",
      "sudo echo '${var.username} ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers",
      "sudo mkdir -p /home/${var.username}/.ssh",
      "sudo chmod 700 /home/${var.username}/.ssh",
      "sudo touch /home/${var.username}/.ssh/authorized_keys",
      "sudo chmod 600 /home/${var.username}/.ssh/authorized_keys",
      "sudo chown -R ${var.username}:${var.username} /home/${var.username}/.ssh"
    ]
  }

  # Copy defaults.cfg to the VM
  provisioner "file" {
    destination = "/tmp/defaults.cfg"
    source      = "./config/defaults.cfg"
  }
  
  # Move defaults.cfg to its final location
  provisioner "shell" {
    inline = ["sudo mv /tmp/defaults.cfg /etc/cloud/cloud.cfg.d/defaults.cfg"]
  }
  
  # Run install_tools.sh with appropriate permissions
  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/install_tools.sh"
  }
  
  # Run setup.sh with appropriate permissions
  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/setup.sh"
  }
  
  # Run Ansible playbook to add developer users
  provisioner "ansible-local" {
    playbook_file = "./templates/scripts/dev_user_add.yml"
  }
  
  # Run cleanup.sh with appropriate permissions
  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/cleanup.sh"
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
