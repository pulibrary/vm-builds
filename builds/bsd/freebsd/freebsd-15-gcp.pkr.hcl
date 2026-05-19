// © Broadcom. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause
// Packer + Google Compute Engine using a FreeBSD source image + Ansible

packer {
  required_version = ">= 1.12.0"
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = ">= 1.1.6"
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
  default = "freebsd"
}

variable "vm_guest_os_name" {
  type    = string
  default = "freebsd"
}

variable "vm_guest_os_version" {
  type    = string
  default = "15.0"
}

variable "vm_guest_os_type" {
  type    = string
  default = "freebsd"
}

// GCP basics
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "gcp_zone" {
  type    = string
  default = "us-central1-a"
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
  default = null
}

variable "gcp_service_account_email" {
  type    = string
  default = null
}

variable "gcp_use_internal_ip" {
  type    = bool
  default = false
}

variable "gcp_omit_external_ip" {
  type    = bool
  default = false
}

// Source image (defaults to FreeBSD 15.0 RELEASE from freebsd-org-cloud-dev)
variable "source_image_project_id" {
  type    = list(string)
  default = ["freebsd-org-cloud-dev"]
}

variable "source_image_family" {
  type    = string
  default = "freebsd-15-0-amd64-zfs"
}

variable "source_image" {
  type    = string
  default = null
}

// Output image / disk
variable "image_description" {
  type    = string
  default = "Built by HashiCorp Packer"
}

variable "image_storage_locations" {
  type    = list(string)
  default = []
}

variable "disk_size_gb" {
  type    = number
  default = 30
}

variable "disk_type" {
  type    = string
  default = "pd-ssd"
}

// Shielded VM: FreeBSD images are not signed for Secure Boot; leave it off.
variable "enable_secure_boot" {
  type    = bool
  default = false
}

variable "enable_vtpm" {
  type    = bool
  default = true
}

variable "enable_integrity_monitoring" {
  type    = bool
  default = true
}

// Communicator / users (base image defaults)
variable "ssh_username" {
  type    = string
  default = "freebsd"
}

variable "communicator_timeout" {
  type    = string
  default = "30m"
}

variable "gcp_network_tags" {
  type    = list(string)
  default = ["pul-gcdc-staging"]
}

// Users for provisioning (same shape as the QEMU/AWS builds)
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

// FreeBSD typically needs an explicit python interpreter for Ansible
variable "ansible_python_interpreter" {
  type    = string
  default = "/usr/local/bin/python3"
}

////////////////////
// Data & Locals  //
////////////////////

data "git-repository" "cwd" {}

locals {
  build_by   = "Built by: HashiCorp Packer ${packer.version}"
  build_date = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())

  # Use timestamp for uniqueness - guaranteed to be safe
  build_timestamp = formatdate("YYYYMMDDHHmmss", timestamp())

  build_ref_raw   = try(data.git-repository.cwd.head, "unknown")
  build_hash_full = sha1(local.build_ref_raw)

  build_description = "Commit: ${local.build_hash_full}\nBuilt on: ${local.build_date}\n${local.build_by}"

  manifest_date   = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path   = "${abspath(path.root)}/../../../manifests/"
  manifest_output = "${local.manifest_path}${local.manifest_date}.json"

  # GCE image names: lowercase letters, digits, and hyphens; 1–63 chars.
  # All inputs here are guaranteed safe under that pattern.
  image_name = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${replace(var.vm_guest_os_version, ".", "-")}-${local.build_timestamp}"

  # GCE image family: same rules; drop the timestamp so the family is stable.
  image_family = "${var.vm_guest_os_family}-${replace(var.vm_guest_os_version, ".", "-")}"

  common_labels = {
    os_family  = lower(var.vm_guest_os_family)
    os_name    = lower(var.vm_guest_os_name)
    os_version = lower(replace(var.vm_guest_os_version, ".", "-"))
    build_date = local.build_timestamp
  }
}

//////////////////////////
// Google Compute Image //
//////////////////////////

source "googlecompute" "freebsd-gcp-image" {
  project_id   = var.gcp_project_id
  zone         = var.gcp_zone
  machine_type = var.gcp_machine_type

  # Source image selection — prefer explicit image, fall back to family.
  source_image            = var.source_image
  source_image_family     = var.source_image == null ? var.source_image_family : null
  source_image_project_id = var.source_image_project_id

  # Output image
  image_name              = local.image_name
  image_family            = local.image_family
  image_description       = local.build_description
  image_labels            = local.common_labels
  image_storage_locations = var.image_storage_locations

  # Boot disk for the build instance
  disk_size = var.disk_size_gb
  disk_type = var.disk_type

  # Networking
  network          = var.gcp_network
  subnetwork       = var.gcp_subnetwork
  omit_external_ip = var.gcp_omit_external_ip
  use_internal_ip  = var.gcp_use_internal_ip

  # IAM
  service_account_email = var.gcp_service_account_email
  scopes                = ["https://www.googleapis.com/auth/cloud-platform"]

  # Shielded VM — Secure Boot off for FreeBSD (not signed for UEFI SB).
  enable_secure_boot          = var.enable_secure_boot
  enable_vtpm                 = var.enable_vtpm
  enable_integrity_monitoring = var.enable_integrity_monitoring

  # Labels on the build instance itself
  labels = local.common_labels

  # ssh firewall
  tags = var.gcp_network_tags

  # Minimal metadata: set the hostname for the build instance.
  metadata = {
    hostname               = "lib-vm"
    block-project-ssh-keys = "TRUE"
  }

  # Communicator
  ssh_username = var.ssh_username
  ssh_timeout  = var.communicator_timeout
}

//////////////
// Build    //
//////////////

build {
  sources = ["source.googlecompute.freebsd-gcp-image"]

  # FreeBSD images ship without python by default; bootstrap it so Ansible runs.
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
    inline = [
      "env ASSUME_ALWAYS_YES=yes pkg bootstrap -y",
      "env ASSUME_ALWAYS_YES=yes pkg install -y python3 py311-packaging sudo bash",
      "ln -sf /usr/local/bin/python3 /usr/local/bin/python || true",
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo env {{ .Vars }} {{ .Path }}"
    inline = [
      "env ASSUME_ALWAYS_YES=yes pkg bootstrap -y",
      "env ASSUME_ALWAYS_YES=yes pkg install -y python3 py311-packaging doas bash",
      "ln -sf /usr/local/bin/python3 /usr/local/bin/python || true",
      "install -d -m 0755 /usr/local/etc",
      "printf 'permit nopass :wheel\\npermit nopass ${var.ssh_username}\\n' > /usr/local/etc/doas.conf",
      "chmod 0600 /usr/local/etc/doas.conf",
      "chown root:wheel /usr/local/etc/doas.conf",
      "/usr/local/bin/doas -C /usr/local/etc/doas.conf",
    ]
  }

  provisioner "ansible" {
    user                   = var.ssh_username
    galaxy_file            = "${abspath(path.root)}/../../../ansible/freebsd-requirements.yml"
    galaxy_force_with_deps = true
    playbook_file          = "${abspath(path.root)}/../../../ansible/freebsd-gcp-playbook.yml"
    roles_path             = "${abspath(path.root)}/../../../ansible/roles"
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${abspath(path.root)}/../../../ansible/ansible.cfg",
      "OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES",
    ]
    extra_arguments = [
      "--extra-vars", "display_skipped_hosts=false",
      "--extra-vars", "ansible_python_interpreter=${var.ansible_python_interpreter}",
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
      build_version    = local.build_hash_full
      gcp_project_id   = var.gcp_project_id
      gcp_region       = var.gcp_region
      gcp_zone         = var.gcp_zone
      image_name       = local.image_name
      image_family     = local.image_family
      disk_size_gb     = var.disk_size_gb
      disk_type        = var.disk_type
      ssh_username     = var.ssh_username
      enable_cloudinit = var.vm_guest_os_cloudinit
      ansible_username = var.ansible_username
      build_username   = var.build_username
    }
  }
}
