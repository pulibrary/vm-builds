packer {
  required_plugins {
    virtualbox = {
      version = ">= 0.0.1"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "os_username" {
  type      = string
  default   = "ansible"
  sensitive = true
}

variable "os_password" {
  type      = string
  default   = "ansible"
  sensitive = true
}

locals {
  hashed_os_password = bcrypt("${var.os_password}")
}

source "virtualbox-iso" "ubuntu-22-04-live-server" {
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]
  boot_wait     = "5s"
  guest_os_type = "ubuntu-64"
  http_content = {
    "/meta-data" = file("../subiquity/http/meta-data")
    "/user-data" = templatefile("../subiquity/http/user-data.yaml.pkrtpl.hcl", {
      "os_username" : "${var.os_username}"
      "hashed_os_password" : "${local.hashed_os_password}"
    })
  }
  iso_url                = "https://releases.ubuntu.com/22.04/ubuntu-22.04.1-live-server-amd64.iso"
  iso_checksum           = "sha256:10f19c5b2b8d6db711582e0e27f5116296c34fe4b313ba45f9b201a5007056cb"
  memory                 = 8192
  output_directory       = "output/ubuntu-2204-live-server-ansible"
  shutdown_command       = "sudo shutdown -P now"
  ssh_handshake_attempts = "20"
  ssh_pty                = true
  ssh_timeout            = "20m"
  ssh_username           = "${var.os_username}"
  ssh_password           = "${var.os_password}"
}

build {
  sources = ["sources.virtualbox-iso.ubuntu-22-04-live-server"]

  provisioner "ansible" {
    use_proxy     = false
    playbook_file = file("../ansible/site.yml")
  }

  post-processor "vagrant" {
    output = "output/ubuntu-2204-live-server-ansible.box"
  }
}
