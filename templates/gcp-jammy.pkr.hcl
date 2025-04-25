packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
}

# Variables for GCP configuration
variable "ubuntu_distro" {
  type = string
}

variable "ubuntu_version" {
  type = string
}

variable "project_id" {
  type = string
  description = "The GCP project ID to build the image in"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
  description = "The GCP zone to build the image in"
}

variable "machine_type" {
  type    = string
  default = "n1-standard-1"
  description = "The machine type to use for the build"
}

variable "vm_template_name" {
  type    = string
  default = "packer-gcp-ubuntu"
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

locals {
  vm_name    = "${var.vm_template_name}-${var.ubuntu_version}"
  output_dir = "output/${local.vm_name}"
  timestamp  = formatdate("YYYYMMDD-hhmmss", timestamp())
  image_name = "${local.vm_name}-${local.timestamp}"
  version_label = replace(var.ubuntu_version, ".", "-") # Convert "22.04" to "22-04" for labels
}

source "googlecompute" "ubuntu" {
  project_id   = var.project_id
  source_image_family = "ubuntu-2204-lts"
  zone         = var.zone
  image_name   = local.image_name
  image_description = "Ubuntu ${var.ubuntu_version} built with Packer"
  ssh_username = var.ssh_username
  machine_type = var.machine_type

  # Disk configuration
  disk_size = 30
  disk_type = "pd-ssd"

  # Network configuration
  network = "default"

  # Use preemptible instance to reduce cost during build
  preemptible = true

  # Add labels to the resulting image - using regex-compliant values
  image_labels = {
    created_by = "packer"
    os = "ubuntu"
    version = local.version_label # Using the sanitized version
    build_date = replace(local.timestamp, ":", "-") # Also ensuring timestamp is compliant
  }

  # Add a startup script to set metadata
  metadata = {
    enable-oslogin = "FALSE"
  }
}

build {
  name    = "ubuntu-gcp"
  sources = ["source.googlecompute.ubuntu"]

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

  # Post-processing steps for the GCP image
  post-processor "manifest" {
    output     = "${local.output_dir}/manifest.json"
    strip_path = true
    custom_data = {
      image_name = local.image_name
      timestamp = local.timestamp
    }
  }
}
