packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.9"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

## Variable will be set via the Command line defined under the `vars` directory
variable "ubuntu_distro" {
  type = string
}

variable "ubuntu_version" {
  type = string
}

variable "ubuntu_iso_file" {
  type = string
}

variable "vm_template_name" {
  type    = string
  default = "packer-qemu-ubuntu"
}

locals {
  vm_name    = "${var.vm_template_name}-${var.ubuntu_version}"
  output_dir = "output/${local.vm_name}"
}

source "qemu" "custom_image" {
  vm_name = "ubuntu-jammy-qemu"

  iso_url      = "https://releases.ubuntu.com/${var.ubuntu_version}/${var.ubuntu_iso_file}"
  iso_checksum = "file:https://releases.ubuntu.com/${var.ubuntu_version}/SHA256SUMS"

  # Location of Cloud-Init / Autoinstall Configuration files
  # Will be served via an HTTP Server from Packer
  http_directory = "http"

  # Boot Commands when Loading the ISO file with OVMF.fd file GrubV2
  boot_command = [
    "<spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait><spacebar><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<f10>"
  ]

  boot_wait = "5s"

  # QEMU specific configuration
  cpus             = 4
  memory           = 8196
  disk_size        = "30G"
  disk_compression = true

  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS_4M.fd"
  efi_boot          = true

  # Final Image will be available in `output/packerubuntu-*/`
  output_directory = ""

  # SSH configuration so that Packer can log into the Image
  ssh_password     = "pulsys"
  ssh_username     = "pulsys"
  ssh_timeout      = "20m"
  shutdown_command = "echo 'lib-vm' | sudo -S shutdown -P now"
  headless         = false
}

build {
  name    = "custom_build"
  sources = ["source.qemu.custom_image"]

  # Wait till Cloud-Init has finished setting up the image on first-boot
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for Cloud-Init...'; sleep 1; done"
    ]
  }

  # Finally Generate a Checksum (SHA256) which can be used for further stages in the `output` directory
  post-processor "checksum" {
    checksum_types      = ["sha256"]
    output              = "${local.output_dir}/${local.vm_name}.{{.ChecksumType}}"
    keep_input_artifact = true
  }
}
