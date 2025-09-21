// © Broadcom. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause
// borrowed heavily from https://vmware.github.io/packer-examples-for-vsphere/
// Packer + QEMU using Rocky Linux 9.4 GenericCloud + cloud-init (NoCloud seed)

packer {
  required_version = ">= 1.12.0"
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
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
  default = "linux"
}

variable "vm_guest_os_name" {
  type    = string
  default = "rocky"
}

variable "vm_guest_os_version" {
  type    = string
  default = "9.4"
}

variable "vm_guest_os_type" {
  type    = string
  default = "rhel9_64Guest"
} // manifest label

// Firmware label (manifest only)
variable "vm_firmware" {
  type    = string
  default = "efi-secure"
}

// Cloud image (QCOW2)
variable "iso_filename" {
  type        = string
  default     = "Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  description = "Default local image under ./isos when iso_url not provided."
}

variable "iso_url" {
  type    = string
  default = ""
}

variable "iso_checksum" {
  type    = string
  default = "sha256:CHANGE_ME"
}

// QEMU knobs
variable "qemu_accelerator" {
  type    = string
  default = "tcg"
} // hvf on macOS/ARM same-arch, kvm on Linux

variable "qemu_headless" {
  type    = bool
  default = true
}

variable "qemu_binary" {
  type    = string
  default = null
}

variable "qemu_machine_type" {
  type    = string
  default = null
}

variable "qemu_disk_format" {
  type    = string
  default = "qcow2"
}

variable "qemu_disk_interface" {
  type    = string
  default = "virtio"
}

variable "qemu_net_device" {
  type    = string
  default = "virtio-net"
}

// VM resources
variable "vm_cpu_count" {
  type    = number
  default = 2
}

variable "vm_cpu_cores" {
  type    = number
  default = 1
} // manifest only

variable "vm_mem_size" {
  type    = number
  default = 2048
}

variable "vm_disk_size" {
  type    = number
  default = 30720
} // MB

// Guest net/storage for templates (cloud-init will usually DHCP; names vary: ens3/enp1s0)
variable "vm_network_device" {
  type    = string
  default = "enp1s0"
}

variable "vm_ip_address" {
  type    = string
  default = null
}

variable "vm_ip_netmask" {
  type    = number
  default = null
}

variable "vm_ip_gateway" {
  type    = string
  default = null
}

variable "vm_dns_list" {
  type    = list(string)
  default = []
}

variable "vm_disk_device" {
  type    = string
  default = "vda"
}

variable "vm_disk_use_swap" {
  type    = bool
  default = false
}

variable "vm_disk_partitions" {
  type = list(object({
    name         = string
    size         = number
    format       = object({ label = string, fstype = string })
    mount        = object({ path = string, options = string })
    volume_group = string
  }))
  default = []
}

variable "vm_disk_lvm" {
  type = list(object({
    name = string
    partitions = list(object({
      name   = string
      size   = number
      format = object({ label = string, fstype = string })
      mount  = object({ path = string, options = string })
    }))
  }))
  default = []
}

// export knobs
variable "compress_qcow2" {
  type    = bool
  default = false
} // gzip qcow2

variable "export_ovf" {
  type    = bool
  default = false
} // write .ovf + .mf

variable "pack_ova" {
  type    = bool
  default = false
} // tar to .ova

// Cloud-init transport
variable "common_data_source" {
  type    = string
  default = "disk"
} // or "http"

variable "common_http_ip" {
  type    = string
  default = null
}

variable "common_http_port_min" {
  type    = number
  default = 8800
}

variable "common_http_port_max" {
  type    = number
  default = 8900
}

// Auth / communicator (created by cloud-init user-data)
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

variable "communicator_port" {
  type    = number
  default = 22
}

variable "communicator_timeout" {
  type    = string
  default = "30m"
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

// Manifest-only toggles
variable "vm_network_card" {
  type    = string
  default = "virtio-net"
}

variable "vm_disk_thin_provisioned" {
  type    = bool
  default = true
}

// Timeouts
variable "vm_boot_wait" {
  type    = string
  default = "3s"
}

variable "common_shutdown_timeout" {
  type    = string
  default = "20m"
}

// HCP Packer
variable "common_hcp_packer_registry_enabled" {
  type    = bool
  default = false
}

// security_role
variable "prepare_security_firstboot" {
  type    = bool
  default = true
}

////////////////////
// Data & Locals  //
////////////////////

data "git-repository" "cwd" {}

locals {
  build_by          = "Built by: HashiCorp Packer ${packer.version}"
  build_date        = formatdate("YYYY-MM-DD hh:mm ZZZ", timestamp())
  build_timestamp   = formatdate("YYYYMMDD-HHmmss", timestamp())
  build_description = "Built on: ${local.build_date}\n${local.build_by}"

  manifest_date   = formatdate("YYYY-MM-DD hh:mm:ss", timestamp())
  manifest_path   = "${abspath(path.root)}/../../../manifests/"
  manifest_output = "${local.manifest_path}${local.manifest_date}.json"

  vm_name    = "${var.vm_guest_os_family}-${var.vm_guest_os_name}-${replace(var.vm_guest_os_version, ".", "-")}-${local.build_timestamp}"
  output_dir = "${abspath(path.root)}/../../../artifacts/qemu/${local.vm_name}"

  // Resolve cloud image path (expects file at ./isos/)
  iso_url_effective = var.iso_url != "" ? var.iso_url : "file://${abspath(path.root)}/isos/${var.iso_filename}"

  // Which qcow2 to publish (.qcow2 or .qcow2.gz)
  qcow2_artifact = var.compress_qcow2 ? "${local.vm_name}.qcow2.gz" : "${local.vm_name}.qcow2"

  // cloud-init seed (NoCloud)
  data_source_content = {
    "/meta-data" = templatefile("${abspath(path.root)}/data/meta-data.pkrtpl.hcl", {
      vm_guest_os_name    = var.vm_guest_os_name
      vm_guest_os_version = var.vm_guest_os_version
    })
    "/user-data" = templatefile("${abspath(path.root)}/data/user-data.pkrtpl.hcl", {
      vm_guest_os_name         = var.vm_guest_os_name
      build_username           = var.build_username
      build_password           = var.build_password
      build_password_encrypted = var.build_password_encrypted
      build_key                = var.build_key
      vm_guest_os_language     = var.vm_guest_os_language
      vm_guest_os_keyboard     = var.vm_guest_os_keyboard
      vm_guest_os_timezone     = var.vm_guest_os_timezone
      vm_disk_device           = var.vm_disk_device
      network = templatefile("${abspath(path.root)}/data/network.pkrtpl.hcl", {
        device  = var.vm_network_device
        ip      = var.vm_ip_address
        netmask = var.vm_ip_netmask
        gateway = var.vm_ip_gateway
        dns     = var.vm_dns_list
      })
      storage = templatefile("${abspath(path.root)}/data/storage.pkrtpl.hcl", {
        device     = var.vm_disk_device
        swap       = var.vm_disk_use_swap
        partitions = var.vm_disk_partitions
        lvm        = var.vm_disk_lvm
      })
      additional_packages = var.additional_packages
    })
  }

  // HTTP seed variant
  data_source_command = var.common_data_source == "http" ? "ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"" : "ds=\"nocloud\""

  bucket_name        = replace("${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}", ".", "")
  bucket_description = "${var.vm_guest_os_family} ${var.vm_guest_os_name} ${var.vm_guest_os_version}"
}

//////////////////////////
// QEMU Build (cloudimg)
//////////////////////////

source "qemu" "linux-rocky-cloudimg" {
  iso_url      = local.iso_url_effective
  iso_checksum = var.iso_checksum
  disk_image   = true // bootable cloud image

  accelerator  = var.qemu_accelerator
  headless     = var.qemu_headless
  qemu_binary  = var.qemu_binary
  machine_type = var.qemu_machine_type

  cpus           = var.vm_cpu_count
  memory         = var.vm_mem_size
  disk_size      = var.vm_disk_size
  format         = var.qemu_disk_format
  disk_interface = var.qemu_disk_interface

  net_device = var.qemu_net_device

  output_directory = local.output_dir

  // Attach NoCloud seed ISO
  cd_content = var.common_data_source == "disk" ? local.data_source_content : null
  cd_label   = var.common_data_source == "disk" ? "cidata" : null

  // Or serve via HTTP
  http_content      = var.common_data_source == "http" ? local.data_source_content : null
  http_bind_address = var.common_data_source == "http" ? var.common_http_ip : null
  http_port_min     = var.common_data_source == "http" ? var.common_http_port_min : null
  http_port_max     = var.common_data_source == "http" ? var.common_http_port_max : null

  communicator = "ssh"
  ssh_username = var.build_username
  ssh_password = var.build_password
  ssh_port     = var.communicator_port
  ssh_timeout  = var.communicator_timeout

  shutdown_command = "echo '${var.build_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout = var.common_shutdown_timeout

  qemuargs = [
    ["-serial", "file:serial.log"],
    ["-cpu", "max"],
  ]
}

//////////////
// Build     //
//////////////

build {
  sources = ["source.qemu.linux-rocky-cloudimg"]

  // Reuse Ansible flow (roles handle OS family differences)
  provisioner "ansible" {
    user                   = var.build_username
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
      "--extra-vars", "cleanup_final_image=true",
      "--extra-vars", "prepare_security_firstboot=${var.prepare_security_firstboot}",
      "--forks", "1"
    ]
  }

  post-processor "manifest" {
    output     = local.manifest_output
    strip_path = true
    strip_time = true
    custom_data = {
      ansible_username         = var.ansible_username
      build_username           = var.build_username
      build_date               = local.build_date
      build_timestamp          = local.build_timestamp
      common_data_source       = var.common_data_source
      vm_cpu_cores             = var.vm_cpu_cores
      vm_cpu_count             = var.vm_cpu_count
      vm_disk_size             = var.vm_disk_size
      vm_disk_thin_provisioned = var.vm_disk_thin_provisioned
      vm_firmware              = var.vm_firmware
      vm_guest_os_type         = var.vm_guest_os_type
      vm_mem_size              = var.vm_mem_size
      vm_network_card          = var.vm_network_card
      qemu_accelerator         = var.qemu_accelerator
      qemu_disk_format         = var.qemu_disk_format
      qemu_disk_interface      = var.qemu_disk_interface
      qemu_net_device          = var.qemu_net_device
      iso_url                  = local.iso_url_effective
    }
  }

  // Convert exports + optional gzip + optional OVF/OVA
  post-processor "shell-local" {
    inline = [<<-EOT
set -euo pipefail
D='${local.output_dir}'
B='${local.vm_name}'

SRC="$(ls -1 "$D"/*.qcow2 2>/dev/null | head -n1 || true)"
if [ -z "$SRC" ]; then SRC="$(ls -1 "$D"/*.img 2>/dev/null | head -n1 || true)"; fi
if [ -z "$SRC" ]; then SRC="$(ls -1 "$D"/packer-* 2>/dev/null | head -n1 || true)"; fi
if [ -z "$SRC" ]; then SRC="$(find "$D" -type f -size +100M -print0 | xargs -0 ls -1S 2>/dev/null | head -n1 || true)"; fi
if [ -z "$SRC" ]; then echo "Could not locate source disk image in $D" >&2; exit 1; fi

qemu-img info "$SRC" || true

qemu-img convert -p -O qcow2 "$SRC" "$D/$B.qcow2"
qemu-img convert -p -O vmdk -o subformat=streamOptimized "$SRC" "$D/$B.vmdk"
qemu-img convert -p -O vpc  -o subformat=dynamic        "$SRC" "$D/$B.vhd"

if [ "${var.compress_qcow2}" = "true" ]; then
  gzip -f -9 "$D/$B.qcow2"
fi

if [ "${var.export_ovf}" = "true" ]; then
  VMDK="$D/$B.vmdk"
  OVF="$D/$B.ovf"
  MF="$D/$B.mf"

  DISK_BYTES=$(qemu-img info "$VMDK" | awk '/virtual size/ {match($0, /\(([0-9]+) bytes\)/, a); print a[1]}')

  cat > "$OVF" <<OVF
<?xml version="1.0" encoding="UTF-8"?>
<ovf:Envelope xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vmw="http://www.vmware.com/schema/ovf" ovf:version="1.0">
  <ovf:References>
    <ovf:File ovf:id="file1" ovf:href="$B.vmdk" ovf:size="$DISK_BYTES"/>
  </ovf:References>
  <ovf:DiskSection>
    <ovf:Info>Virtual disk information</ovf:Info>
    <ovf:Disk ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:capacity="$DISK_BYTES" ovf:capacityAllocationUnits="byte"/>
  </ovf:DiskSection>
  <ovf:VirtualSystem ovf:id="$B">
    <ovf:Info>Rocky Linux ${var.vm_guest_os_version}</ovf:Info>
    <ovf:VirtualHardwareSection>
      <ovf:Item>
        <ovf:ElementName>${var.vm_cpu_count} virtual CPU(s)</ovf:ElementName>
        <ovf:InstanceID>1</ovf:InstanceID>
        <ovf:ResourceType>3</ovf:ResourceType>
        <ovf:VirtualQuantity>${var.vm_cpu_count}</ovf:VirtualQuantity>
      </ovf:Item>
      <ovf:Item>
        <ovf:ElementName>${var.vm_mem_size}MB of memory</ovf:ElementName>
        <ovf:InstanceID>2</ovf:InstanceID>
        <ovf:ResourceType>4</ovf:ResourceType>
        <ovf:VirtualQuantity>${var.vm_mem_size}</ovf:VirtualQuantity>
        <ovf:AllocationUnits>byte * 2^20</ovf:AllocationUnits>
      </ovf:Item>
      <ovf:Item>
        <ovf:ElementName>Hard disk</ovf:ElementName>
        <ovf:InstanceID>3</ovf:InstanceID>
        <ovf:ResourceType>17</ovf:ResourceType>
        <ovf:HostResource>ovf:/disk/vmdisk1</ovf:HostResource>
      </ovf:Item>
    </ovf:VirtualHardwareSection>
  </ovf:VirtualSystem>
</ovf:Envelope>
OVF

  if command -v shasum >/dev/null 2>&1; then
    (cd "$D" && shasum -a 256 "$B.ovf" "$B.vmdk" | awk '{print "SHA256(" $2 ")= " $1 }' > "$MF")
  else
    (cd "$D" && sha256sum "$B.ovf" "$B.vmdk" | awk '{print "SHA256(" $2 ")= " $1 }' > "$MF")
  fi

  if [ "${var.pack_ova}" = "true" ]; then
    (cd "$D" && tar -cvf "$B.ova" "$B.ovf" "$B.vmdk" "$B.mf")
  fi
fi
EOT
    ]
  }

  // Publish just the converted files (+ qcow2/.gz)
  post-processor "artifice" {
    files = concat(
      [
        "${local.output_dir}/${local.qcow2_artifact}",
        "${local.output_dir}/${local.vm_name}.vmdk",
        "${local.output_dir}/${local.vm_name}.vhd",
      ],
      var.pack_ova ? ["${local.output_dir}/${local.vm_name}.ova"] : []
    )
  }

  post-processor "checksum" {
    checksum_types = ["sha256"]
    output         = "${local.output_dir}/${local.vm_name}_CHECKSUMS"
  }

  dynamic "hcp_packer_registry" {
    for_each = var.common_hcp_packer_registry_enabled ? [1] : []
    content {
      bucket_name = local.bucket_name
      description = local.bucket_description
      bucket_labels = {
        "os_family"  = var.vm_guest_os_family,
        "os_name"    = var.vm_guest_os_name,
        "os_version" = var.vm_guest_os_version,
      }
      build_labels = {
        "build_version"  = local.build_version,
        "packer_version" = packer.version,
      }
    }
  }
}
