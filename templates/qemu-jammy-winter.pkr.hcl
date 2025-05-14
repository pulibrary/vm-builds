packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}


locals {
  vm_name    = "packer-qemu-ubuntu-${var.ubuntu_version}"
  output_dir = "output/${local.vm_name}"
  timestamp  = formatdate("YYYYMMDD-hhmmss", timestamp())
}

# --- QEMU SOURCE ---
source "qemu" "ubuntu" {
  accelerator     = "kvm"
  headless        = true
  output_directory = local.output_dir

  # Boot from Ubuntu live-server ISO (with cloud‑init autoinstall)
  iso_url            = "https://releases.ubuntu.com/${var.ubuntu_version}/ubuntu-${var.ubuntu_version}-live-server-amd64.iso"
  # TODO: update this sha256 after downloading ISO
  iso_checksum_type  = "sha256"
  iso_checksum       = "ENTER_SHA256_HERE"

  # Disk configuration
  disk_size    = "30720"      # 30 GB
  disk_interface = "virtio"
  format       = "qcow2"

  # Networking / SSH
  ssh_username = var.ssh_username
  ssh_timeout  = "20m"
  ssh_pty      = true
  # forward host port 2222 → guest port 22
  ssh_host_port   = "2222"
  ssh_guest_port  = "22"

  # HTTP server to serve cloud-init
  http_directory = "http"

  # Tell the installer to use autoinstall
  boot_wait   = "10s"
  boot_command = [
    "<esc><wait>",
    "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter>"
  ]
}

# --- BUILD & PROVISION ---
build {
  name    = "ubuntu-qemu"
  sources = ["source.qemu.ubuntu"]

  # Wait for cloud-init to finish (same as GCP template)
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for Cloud‑Init…'; sleep 1; done"
    ]
  }

  # System update & basic packages
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y nginx openssh-server",
      "sudo systemctl enable nginx"
    ]
  }

  # Create your pulsys user
  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash ${var.username}",
      "echo '${var.username} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${var.username}",
      "sudo mkdir -p /home/${var.username}/.ssh",
      "sudo chmod 700 /home/${var.username}/.ssh",
      "sudo touch /home/${var.username}/.ssh/authorized_keys",
      "sudo chmod 600 /home/${var.username}/.ssh/authorized_keys",
      "sudo chown -R ${var.username}:${var.username} /home/${var.username}/.ssh"
    ]
  }

  # Copy your defaults.cfg
  provisioner "file" {
    source      = "./config/defaults.cfg"
    destination = "/tmp/defaults.cfg"
  }

  provisioner "shell" {
    inline = ["sudo mv /tmp/defaults.cfg /etc/cloud/cloud.cfg.d/defaults.cfg"]
  }

  # Run your install_tools.sh and setup.sh
  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/install_tools.sh"
  }

  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/setup.sh"
  }

  # Ansible‑local for dev_user_add
  provisioner "ansible-local" {
    playbook_file = "./templates/scripts/dev_user_add.yml"
  }

  # Cleanup
  provisioner "shell" {
    execute_command = "echo '${var.username}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "./templates/scripts/cleanup.sh"
  }
}

# --- POST-PROCESS: convert QCOW2 → VMDK for VMware ---
post-processor "shell-local" {
  inline = [
    "qemu-img convert -p -O vmdk ${local.output_dir}/${local.vm_name}.qcow2 ${local.output_dir}/${local.vm_name}.vmdk"
  ]
}

# --- MANIFEST ---
post-processor "manifest" {
  output     = "${local.output_dir}/manifest.json"
  strip_path = true
  custom_data = {
    vm_name   = local.vm_name
    timestamp = local.timestamp
  }
}

