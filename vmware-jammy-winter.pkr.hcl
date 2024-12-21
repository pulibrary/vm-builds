packer {
  required_plugins {
    vmware = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

variable "github_users" {
  default = ["acozine", "aruiz1789", "beck-davis", "dphillips-39", "kayiwa", "vickiekarasic"]
}

source "vmware-iso" "ubuntu" {
  iso_url              = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso"
  iso_checksum         = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"
  communicator         = "ssh"
  ssh_username         = "pulsys"
  ssh_private_key_file = "${path.root}/ansible_tower_private_key"

  vm_name          = "ubuntu-jammy-vmware"
  output_directory = "output-vmware-ubuntu-jammy"

  guest_os_type    = "ubuntu-64"
  disk_size        = 30720
  memory           = 8196
  cpus             = 2
  shutdown_command = "echo 'pulsys' | sudo -S shutdown -P now"
}

build {
  sources = ["source.vmware-iso.ubuntu"]

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
%{for user in var.github_users}
$(curl -s https://github.com/${user}.keys)
%{endfor}
EOF
  }

  provisioner "shell" {
    inline = [
      "cat /tmp/authorized_keys > /home/pulsys/.ssh/authorized_keys",
      "chmod 600 /home/pulsys/.ssh/authorized_keys",
      "chown -R pulsys:pulsys /home/pulsys/.ssh",
      "rm /tmp/authorized_keys"
    ]
  }
}
