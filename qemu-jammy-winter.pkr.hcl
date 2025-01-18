packer {
  required_plugins {
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "github_users" {
  default = ["acozine", "aruiz1789", "beck-davis", "dphillips-39", "kayiwa", "vickiekarasic"]
}

locals {
  # Create a script with the github users from the variable
  github_keys_script = templatefile("${path.root}/scripts/github_keys.tpl", {
    github_users = var.github_users
  })
}

source "qemu" "ubuntu" {
  iso_url      = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
  iso_checksum = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

  # VM Configuration
  output_directory = "output-qemu-ubuntu-jammy"
  vm_name          = "ubuntu-jammy-qemu"
  disk_size        = 30720
  memory           = 8196
  cpus             = 2

  # SSH Configuration
  communicator           = "ssh"
  ssh_username           = "pulsys"
  ssh_password           = "pulsys"
  ssh_timeout            = "30m"
  ssh_wait_timeout       = "30m"
  ssh_handshake_attempts = "100"

  # Boot and Installation Configuration
  boot_wait         = "5s"
  boot_key_interval = "10ms"
  shutdown_command  = "echo 'pulsys' | sudo -S shutdown -P now"

  # HTTP Server Configuration
  http_directory = "http"
  http_port_min  = 8080
  http_port_max  = 8080

  # VNC Configuration
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 5999
  headless         = false

  # Boot Command for Autoinstall
  boot_command = [
    "<esc><wait10>",
    "c<wait5>",
    "set gfxpayload=keep<enter><wait5>",
    "linux /casper/hwe-vmlinuz ",
    "autoinstall ",
    "ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ",
    "hostname=lib-vm ",
    "fsck.mode=skip ",
    "net.ifnames=0 ",
    "biosdevname=0 ",
    "console=tty1 ",
    "console=ttyS0<enter><wait5>",
    "initrd /casper/hwe-initrd<enter><wait5>",
    "boot<enter><wait>"
  ]

  # QEMU specific arguments for better debugging
  qemuargs = [
    ["-display", "gtk"]
  ]
}

build {
  sources = ["source.qemu.ubuntu"]

  # Create the GitHub keys script
  provisioner "file" {
    content     = local.github_keys_script
    destination = "/tmp/github_keys.sh"
  }

  # Initial system setup and key installation
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo chmod +x /tmp/github_keys.sh",
      "sudo /tmp/github_keys.sh",
      "echo 'System setup complete. Verifying SSH keys:'",
      "ls -la /home/pulsys/.ssh",
      "cat /home/pulsys/.ssh/authorized_keys"
    ]
  }
}
