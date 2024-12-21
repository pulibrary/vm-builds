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

source "qemu" "ubuntu" {
  iso_url              = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
  iso_checksum         = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"
  communicator         = "ssh"
  ssh_username         = "pulsys"
  ssh_private_key_file = "${path.root}/ansible_tower_private_key"

  output_directory = "output-qemu-ubuntu-jammy"
  vm_name          = "ubuntu-jammy-qemu"

  disk_size        = 30720
  memory           = 8196
  cpus             = 2
  shutdown_command = "echo 'pulsys' | sudo -S shutdown -P now"
  boot_wait        = "30s"

  qemuargs = [
    ["-display", "none"]
  ]

  ssh_wait_timeout = "30m"
}

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" {
    inline = [
      # Update and install required packages
      "apt-get update && apt-get upgrade -y",
      "apt-get install -y openssh-server curl",

      # Create the 'pulsys' user
      "adduser --disabled-password --gecos '' pulsys",
      "usermod -aG sudo pulsys",

      # Configure sudoers with NOPASSWD
      "echo 'pulsys ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/pulsys",
      "chmod 440 /etc/sudoers.d/pulsys",

      # Setup .ssh directory for key-based authentication
      "mkdir -p /home/pulsys/.ssh",
      "chmod 700 /home/pulsys/.ssh"
    ]
  }

  provisioner "file" {
    destination = "/tmp/authorized_keys"
    content     = <<EOF
%{for user in var.github_users~}
$(curl -s https://github.com/${user}.keys)
%{endfor~}
EOF
  }

  provisioner "shell" {
    inline = [
      "cat /tmp/authorized_keys >> /home/pulsys/.ssh/authorized_keys",
      "chmod 600 /home/pulsys/.ssh/authorized_keys",
      "chown -R pulsys:pulsys /home/pulsys/.ssh",
      "rm /tmp/authorized_keys",
      "sleep 600", # Debug sleep
      "apt-get update && apt-get upgrade -y",
      "apt-get install -y openssh-server curl",

      # Create the 'pulsys' user
      "adduser --disabled-password --gecos '' pulsys",
      "usermod -aG sudo pulsys",

      # Configure sudoers with NOPASSWD
      "echo 'pulsys ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/pulsys",
      "chmod 440 /etc/sudoers.d/pulsys",

      # Setup .ssh directory for key-based authentication
      "mkdir -p /home/pulsys/.ssh",
      "chmod 700 /home/pulsys/.ssh"
    ]
  }

  provisioner "file" {
    content     = <<EOF
%{for user in var.github_users~}
$(curl -s https://github.com/${user}.keys)
%{endfor~}
EOF
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      "cat /tmp/authorized_keys >> /home/pulsys/.ssh/authorized_keys",
      "chmod 600 /home/pulsys/.ssh/authorized_keys",
      "chown -R pulsys:pulsys /home/pulsys/.ssh",
      "rm /tmp/authorized_keys"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Provisioning debug:'",
      "id pulsys",
      "ls -la /home/pulsys/.ssh",
      "cat /home/pulsys/.ssh/authorized_keys || echo 'No keys found'",
      "sleep 600"
    ]
  }
}
