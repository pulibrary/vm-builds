// © Broadcom. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause
// borrowed heavily from https://vmware.github.io/packer-examples-for-vsphere/
// Packer + Google Compute Engine image using Ubuntu 22.04 LTS + cloud-init + Ansible

packer {
  required_version = ">= 1.12.0"
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.0.19"
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

####################
# Variables
####################

variable "vm_guest_os_family" {
  type    = string
  default = "linux"
}

variable "vm_guest_os_name" {
  type    = string
  default = "ubuntu"
}

variable "vm_guest_os_version" {
  type    = string
  default = "22.04-lts"
}

variable "vm_guest_os_type" {
  type    = string
  default = "hvm"
}

# GCP basics
variable "gcp_project_id" {
  type = string
}

variable "gcp_zone" {
  type    = string
  default = "us-east1-b"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "gcp_network" {
  type    = string
  default = "default"
}

variable "gcp_subnetwork" {
  type    = string
  default = ""
}

variable "use_internal_ip" {
  type    = bool
  default = false
}

# Image output
variable "image_family" {
  type    = string
  default = "linux-ubuntu-2204"
}

variable "image_storage_locations" {
  type    = list(string)
  default = ["us"]
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "disk_type" {
  type    = string
  default = "pd-balanced"
} # pd-ssd | pd-standard | pd-balanced

# Base image (Ubuntu 22.04 LTS)
variable "source_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "source_image_project_id" {
  type    = list(string)
  default = ["ubuntu-os-cloud"]
}

# Communicator/users
variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "communicator_timeout" {
  type    = string
  default = "30m"
}

# Users for provisioning (shared with QEMU/AWS)
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

# Final cleanup toggle
variable "cleanup_final_image" {
  type    = bool
  default = true
}

####################
# Data & Locals
####################

data "git-repository" "cwd" {}

locals {
  build_by          = "Built by: HashiCorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_version     = data.git-repository.cwd.head
  build_description = "Version: ${local.build_version}\nBuilt on: ${local.build_date}\n${local.build_by}"

  manifest_date   = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path   = "${abspath(path.root)}/../../manifests/"
  manifest_output = "${local.manifest_path}${local.manifest_date}.json"
  image_name = substr(
    replace(
      format(
        "img-%s-%s-%s-%s",
        var.vm_guest_os_family,
        var.vm_guest_os_name,
        replace(var.vm_guest_os_version, ".", "-"),
        substr(local.build_version, 0, 12)
      ),
      "_", "-" # Replace all underscores with hyphens
    ),
    0,
    63
  )

  vm_name = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}-${local.build_version}"

  common_labels = {
    os_family  = var.vm_guest_os_family
    os_name    = var.vm_guest_os_name
    os_version = var.vm_guest_os_version
    build_date = local.build_date
    build_hash = local.build_version
  }
}

############################
# Google Compute Image
############################

source "googlecompute" "linux-gcp-image" {
  project_id   = var.gcp_project_id
  zone         = var.gcp_zone
  machine_type = var.gcp_machine_type

  metadata = {
    "user-data" = <<-EOT
    #cloud-config
    hostname: lib-vm
    manage_etc_hosts: true
    EOT
  }

  # Base image
  source_image_family     = var.source_image_family
  source_image_project_id = var.source_image_project_id

  # Network
  network          = var.gcp_network
  subnetwork       = var.gcp_subnetwork != "" ? var.gcp_subnetwork : null
  use_internal_ip  = var.use_internal_ip
  omit_external_ip = var.use_internal_ip

  # Output image
  image_name              = local.image_name
  image_family            = var.image_family
  image_description       = local.build_description
  image_storage_locations = var.image_storage_locations
  labels                  = local.common_labels

  # Disk
  disk_size = var.disk_size_gb
  disk_type = var.disk_type

  # Shielded VM flags (supported as top-level booleans)
  enable_secure_boot          = true
  enable_vtpm                 = true
  enable_integrity_monitoring = true

  # Communicator
  ssh_username = var.ssh_username
  ssh_timeout  = var.communicator_timeout
}

############
# Build
############

build {
  sources = ["source.googlecompute.linux-gcp-image"]

  provisioner "ansible" {
    user                   = var.ssh_username
    galaxy_file            = "${abspath(path.root)}/../../../ansible/linux-requirements.yml"
    galaxy_force_with_deps = true
    playbook_file          = "${abspath(path.root)}/../../../ansible/linux-playbook.yml"
    roles_path             = "${abspath(path.root)}/../../../ansible/roles"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${abspath(path.root)}/../../../ansible/ansible.cfg",
      "OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES",
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

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      build_date       = local.build_date
      build_version    = local.build_version
      gcp_project_id   = var.gcp_project_id
      gcp_zone         = var.gcp_zone
      image_name       = local.image_name
      image_family     = var.image_family
      disk_size_gb     = var.disk_size_gb
      disk_type        = var.disk_type
      ssh_username     = var.ssh_username
      enable_cloudinit = var.vm_guest_os_cloudinit
      ansible_username = var.ansible_username
      build_username   = var.build_username
    }
  }
}
