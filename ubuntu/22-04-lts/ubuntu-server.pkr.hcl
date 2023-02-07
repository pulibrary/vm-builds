packer {
  required_plugins {
    virtualbox = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "boot_wait" {
  type    = string
  default = "10s"
}

variable "iso_checksum" {
  type    = string
  default = "10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
}

variable "cpus" {
  type    = string
  default = "2"
}

variable "memory" {
  type    = string
  default = "8192"
}

variable "ssh_password" {
  type    = string
  default = "packer"
}

variable "ssh_timeout" {
  type    = string
  default = "15m"
}

variable "ssh_username" {
  type    = string
  default = "pulsys"
}

variable "ssh_handshake_attempts" {
  type    = number
  default = 75
}

# "timestamp" template function replacement
locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

locals {
  hashed_os_password = bcrypt("${var.ssh_password}")
}

source "virtualbox-iso" "vbox" {
  guest_os_type          = "Ubuntu_64"
  shutdown_command       = "echo 'packer' | sudo -S shutdown -P now"
  ssh_password           = "${var.ssh_password}"
  ssh_timeout            = "${var.ssh_timeout}"
  ssh_username           = "${var.ssh_username}"
  ssh_handshake_attempts = "${var.ssh_handshake_attempts}"
  cpus                   = "${var.cpus}"
  memory                 = "${var.memory}"
  boot_wait              = "${var.boot_wait}"
  http_content           = {
    "/meta-data" = file("http/meta-data")
    "/user-data" = templatefile("http/user-data.yaml.pkrtpl.hcl", {
      "hashed_os_password": "${local.hashed_os_password}"
    })
  }
  iso_url                = "${var.iso_url}"
  iso_checksum           = "${var.iso_checksum}"

  boot_command = [
    "<esc><esc><esc><esc>e<wait>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "<del><del><del><del><del><del><del><del>", "<del><del><del><del><del><del><del><del>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\"<enter><wait>",
    "initrd /casper/initrd<enter><wait>", "boot<enter>", "<enter><f10><wait>"
  ]
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.virtualbox-iso.vbox"]


  provisioner "ansible" {
    playbook_file = "${path.cwd}/ansible/site.yml"
  }

  post-processors {
    post-processor "vagrant" {
      keep_input_artifact = true
      provider_override   = "virtualbox"
    }
  }
}
