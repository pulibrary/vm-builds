// © Broadcom. All Rights Reserved.
// SPDX-License-Identifier: BSD-2-Clause
// borrowed heavily from https://vmware.github.io/packer-examples-for-vsphere/
// Packer + QEMU using Ubuntu cloud image + cloud-init (NoCloud seed)

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
// Variables (separate these once successful?)     //
/////////////////////////////

// Naming / OS metadata
variable "vm_guest_os_family" {
  type        = string
  default     = "linux"
  description = "OS family for naming (e.g., linux)."
}

variable "vm_guest_os_name" {
  type        = string
  default     = "ubuntu"
  description = "OS name for naming (e.g., ubuntu)."
}

variable "vm_guest_os_version" {
  type        = string
  default     = "22.04-lts"
  description = "OS version string for naming (e.g., 22.04-lts)."
}

variable "vm_guest_os_type" {
  type        = string
  default     = "ubuntu64Guest"
  description = "Informational guest type label (for manifest)."
}

// Firmware label for manifest only (qemu will use default unless we wire EFI vars)
variable "vm_firmware" {
  type        = string
  default     = "efi-secure"
  description = "Virtual firmware: 'efi', 'efi-secure', or 'bios'."
}

// Cloud image "url" (still named iso_* to match builder inputs)
variable "iso_filename" {
  type        = string
  default     = "ubuntu-22.04-server-cloudimg-amd64.img"
  description = "Default local image under ./isos when iso_url not provided."
}

variable "iso_url" {
  type        = string
  default     = ""
  description = "file:///... or https://... to a cloud image (QCOW2). Leave empty to use ./isos/<iso_filename>."
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:CHANGE_ME"
  description = "Checksum for the cloud image (e.g., sha256:...). See Ubuntu release checksums."
}

// QEMU knobs
variable "qemu_accelerator" {
  type        = string
  default     = "tcg"
  description = "Acceleration: kvm (Linux), hvf (macOS same-arch), or tcg/none (software)."
}

variable "qemu_headless" {
  type        = bool
  default     = true
  description = "Run QEMU headless."
}

variable "qemu_binary" {
  type        = string
  default     = null
  description = "Optional override path to qemu-system-x86_64."
}

variable "qemu_machine_type" {
  type        = string
  default     = null
  description = "Optional machine type (e.g., q35)."
}

variable "qemu_disk_format" {
  type        = string
  default     = "qcow2"
  description = "Disk format for builder output (qcow2 recommended)."
}

variable "qemu_disk_interface" {
  type        = string
  default     = "virtio"
  description = "Disk interface: virtio, scsi, ide."
}

variable "qemu_net_device" {
  type        = string
  default     = "virtio-net"
  description = "NIC model: virtio-net, e1000, rtl8139."
}

// VM resources
variable "vm_cpu_count" {
  type        = number
  default     = 2
  description = "vCPUs."
}

variable "vm_cpu_cores" {
  type        = number
  default     = 1
  description = "Cores per socket (manifest only)."
}

variable "vm_mem_size" {
  type        = number
  default     = 2048
  description = "RAM (MB)."
}

variable "vm_disk_size" {
  type        = number
  default     = 30600
  description = "Disk size (MB)."
}

// Guest net/storage for templates
variable "vm_network_device" {
  type        = string
  default     = "ens3"
  description = "Guest NIC name (e.g., ens3 for virtio)."
}

variable "vm_ip_address" {
  type        = string
  default     = null
  description = "Static IP (or null for DHCP)."
}

variable "vm_ip_netmask" {
  type        = number
  default     = null
  description = "CIDR netmask (e.g., 24) or null."
}

variable "vm_ip_gateway" {
  type        = string
  default     = null
  description = "Gateway or null."
}

variable "vm_dns_list" {
  type        = list(string)
  default     = []
  description = "Nameservers."
}

variable "vm_disk_device" {
  type        = string
  default     = "vda"
  description = "Primary disk device inside guest (virtio -> vda)."
}

variable "vm_disk_use_swap" {
  type        = bool
  default     = true
  description = "Whether to use swap partition."
}

variable "vm_disk_partitions" {
  type = list(object({
    name = string
    size = number
    format = object({
      label  = string
      fstype = string
    })
    mount = object({
      path    = string
      options = string
    })
    volume_group = string
  }))
  default     = []
  description = "Partition scheme for the primary disk."
}

variable "vm_disk_lvm" {
  type = list(object({
    name = string
    partitions = list(object({
      name = string
      size = number
      format = object({
        label  = string
        fstype = string
      })
      mount = object({
        path    = string
        options = string
      })
    }))
  }))
  default     = []
  description = "Optional LVM layout."
}

// ova variables
// gzip the qcow2 after build
variable "compress_qcow2" {
  type    = bool
  default = false
}

// write a minimal OVF + .mf next to the VMDK
variable "export_ovf" {
  type    = bool
  default = false
}

// tar OVF set into a single .ova
variable "pack_ova" {
  type    = bool
  default = false
}

// Cloud-init transport
variable "common_data_source" {
  type        = string
  default     = "disk"
  description = "Provisioning data source: 'http' or 'disk'. (NoCloud as attached seed disk by default)"
}

variable "common_http_ip" {
  type        = string
  default     = null
  description = "Bind IP for packer's HTTP server (null=all interfaces)."
}

variable "common_http_port_min" {
  type        = number
  default     = 8800
  description = "HTTP server port range start."
}

variable "common_http_port_max" {
  type        = number
  default     = 8900
  description = "HTTP server port range end."
}

// Auth / communicator
variable "build_username" {
  type        = string
  default     = "packer"
  description = "SSH user created by cloud-init user-data."
}

variable "build_password" {
  type        = string
  default     = "packer"
  sensitive   = true
  description = "Password for build user."
}

variable "build_password_encrypted" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Encrypted password for the installer identity (mkpasswd -m sha-512)."
}

variable "build_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SSH public key for build user."
}

variable "communicator_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "communicator_timeout" {
  type        = string
  default     = "30m"
  description = "SSH timeout."
}

variable "ansible_username" {
  type        = string
  default     = "packer"
  sensitive   = true
  description = "SSH user for Ansible (same as build_username)."
}

variable "ansible_key" {
  type        = string
  default     = ""
  sensitive   = true
  description = "SSH public key for Ansible"
}

variable "vm_guest_os_language" {
  type        = string
  default     = "en_US"
  description = "Locale."
}

variable "vm_guest_os_keyboard" {
  type        = string
  default     = "us"
  description = "Keyboard layout."
}

variable "vm_guest_os_timezone" {
  type        = string
  default     = "UTC"
  description = "Timezone."
}

variable "vm_guest_os_cloudinit" {
  type        = bool
  default     = true
  description = "Expose flag to Ansible."
}

variable "additional_packages" {
  type        = list(string)
  default     = []
  description = "Extra packages to install."
}

// Manifest-only toggles
variable "vm_network_card" {
  type        = string
  default     = "virtio-net"
  description = "Manifest-only label for NIC type."
}

variable "vm_disk_thin_provisioned" {
  type        = bool
  default     = true
  description = "Manifest-only flag mirroring vSphere template."
}

// Timeouts
variable "vm_boot_wait" {
  type        = string
  default     = "3s"
  description = "Time to wait before typing boot commands (unused in cloudimg path)."
}

variable "common_shutdown_timeout" {
  type        = string
  default     = "20m"
  description = "Time to wait for shutdown."
}

// HCP Packer (optional)
variable "common_hcp_packer_registry_enabled" {
  type    = bool
  default = false
}

// security_role
variable "prepare_security_firstboot" {
  type    = bool
  default = true
}

variable "BIGFIX_MASTHEAD_URL" {
  type    = string
  default = env("BIGFIX_MASTHEAD_URL")
}

variable "RAPID7_TOKEN" {
  type    = string
  default = env("RAPID7_TOKEN")
}

variable "RAPID7_ATTRIBUTES" {
  type    = string
  default = env("RAPID7_ATTRIBUTES")
}

variable "CORTEX_XDR_TARBALL_URL" {
  type    = string
  default = env("CORTEX_XDR_TARBALL_URL")
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

  // Resolve local cloud image if iso_url not provided
  iso_url_effective = var.iso_url != "" ? var.iso_url : "file://${abspath(path.root)}/isos/${var.iso_filename}"

  // ova
  qcow2_artifact = var.compress_qcow2 ? "${local.vm_name}.qcow2.gz" : "${local.vm_name}.qcow2"

  user_data_vars = {
    vm_guest_os_name         = var.vm_guest_os_name
    build_username           = var.build_username
    build_password           = var.build_password
    build_password_encrypted = var.build_password_encrypted
    build_key                = var.build_key
    vm_guest_os_language     = var.vm_guest_os_language
    vm_guest_os_keyboard     = var.vm_guest_os_keyboard
    vm_guest_os_timezone     = var.vm_guest_os_timezone
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

    # the security first-boot vars
    BIGFIX_MASTHEAD_URL    = var.BIGFIX_MASTHEAD_URL
    RAPID7_TOKEN           = var.RAPID7_TOKEN
    RAPID7_ATTRIBUTES      = var.RAPID7_ATTRIBUTES
    CORTEX_XDR_TARBALL_URL = var.CORTEX_XDR_TARBALL_URL
  }

  // cloud-init seed (NoCloud)
  data_source_content = {
    "/meta-data" = file("${abspath(path.root)}/data/meta-data")
  "/user-data" = templatefile("${abspath(path.root)}/data/user-data.pkrtpl.hcl", local.user_data_vars) }

  // If we switch to HTTP seed instead of a seed disk:
  data_source_command = var.common_data_source == "http" ? "ds=\"nocloud-net;seedfrom=http://{{.HTTPIP}}:{{.HTTPPort}}/\"" : "ds=\"nocloud\""

  bucket_name        = replace("${var.vm_guest_os_family}-${var.vm_guest_os_name}-${var.vm_guest_os_version}", ".", "")
  bucket_description = "${var.vm_guest_os_family} ${var.vm_guest_os_name} ${var.vm_guest_os_version}"
}

//////////////////////////
// QEMU Build (cloudimg)
//////////////////////////

source "qemu" "linux-ubuntu-cloudimg" {
  // Point at the cloud image (QCOW2)
  iso_url      = local.iso_url_effective
  iso_checksum = var.iso_checksum
  disk_image   = true // treat iso_url as a bootable image

  // QEMU basics
  accelerator  = var.qemu_accelerator
  headless     = var.qemu_headless
  qemu_binary  = var.qemu_binary
  machine_type = var.qemu_machine_type
  // firmware  = local.qemu_firmware // this is a mess because of arm and intel archs avoid these dragons

  // Resources (Packer can resize a cloud image when disk_image=true)
  cpus           = var.vm_cpu_count
  memory         = var.vm_mem_size
  disk_size      = var.vm_disk_size
  format         = var.qemu_disk_format
  disk_interface = var.qemu_disk_interface

  // Network device
  net_device = var.qemu_net_device

  // Output
  output_directory = local.output_dir

  // No installer → no boot_command needed.
  // Attach NoCloud data as a seed disk:
  cd_content = var.common_data_source == "disk" ? local.data_source_content : null
  cd_label   = var.common_data_source == "disk" ? "cidata" : null

  // Serve the same content via ephemeral HTTP
  http_content      = var.common_data_source == "http" ? local.data_source_content : null
  http_bind_address = var.common_data_source == "http" ? var.common_http_ip : null
  http_port_min     = var.common_data_source == "http" ? var.common_http_port_min : null
  http_port_max     = var.common_data_source == "http" ? var.common_http_port_max : null

  // Communicator
  communicator = "ssh"
  ssh_username = var.build_username
  ssh_password = var.build_password
  ssh_port     = var.communicator_port
  ssh_timeout  = var.communicator_timeout

  // Shutdown (cloud-init can also do power_state; this is fine)
  shutdown_command = "echo '${var.build_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout = var.common_shutdown_timeout
}

//////////////
// Build     //
//////////////

build {
  sources = ["source.qemu.linux-ubuntu-cloudimg"]

  // Reuse Ansible flow
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

  provisioner "shell" {
    inline = [
      "sudo userdel -r packer 2>/dev/null || true",
      "sudo userdel -r ubuntu 2>/dev/null || true",
    ]
    execute_command = "echo '${var.build_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
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

  // Convert QCOW2 → VMDK/VHD
  post-processor "shell-local" {
    inline = [<<-EOT
      set -euo pipefail
      D='${local.output_dir}'
      B='${local.vm_name}'

      # Find the source image produced by the builder
      SRC="$(ls -1 "$D"/*.qcow2 2>/dev/null | head -n1 || true)"
      if [ -z "$SRC" ]; then SRC="$(ls -1 "$D"/*.img 2>/dev/null | head -n1 || true)"; fi
      if [ -z "$SRC" ]; then SRC="$(ls -1 "$D"/packer-* 2>/dev/null | head -n1 || true)"; fi
      if [ -z "$SRC" ]; then SRC="$(find "$D" -type f -size +100M -print0 | xargs -0 ls -1S 2>/dev/null | head -n1 || true)"; fi
      if [ -z "$SRC" ]; then echo "Could not locate source disk image in $D" >&2; exit 1; fi

      qemu-img info "$SRC" || true

      # Convert to target formats for publishing
      qemu-img convert -p -O qcow2 "$SRC" "$D/$B.qcow2"
      qemu-img convert -p -O vmdk -o subformat=streamOptimized "$SRC" "$D/$B.vmdk"
      qemu-img convert -p -O vpc  -o subformat=dynamic        "$SRC" "$D/$B.vhd"

      # gzip qcow2 (after we've created it)
      if [ "${var.compress_qcow2}" = "true" ]; then
        gzip -f -9 "$D/$B.qcow2"
      fi

      # OVF/OVA export
      if [ "${var.export_ovf}" = "true" ]; then
        VMDK="$D/$B.vmdk"
        OVF="$D/$B.ovf"
        MF="$D/$B.mf"

        # Pull virtual size in bytes from the VMDK we just created
        DISK_BYTES=$(qemu-img info "$VMDK" | awk '/virtual size/ {match($0, /\(([0-9]+) bytes\)/, a); print a[1]}')

        # Actual VMDK file size in bytes (BSD + GNU stat)
        FILE_BYTES=$(stat -f%z "$VMDK" 2>/dev/null || stat -c%s "$VMDK")

        cat > "$OVF" <<'OVF'
  <?xml version="1.0" encoding="UTF-8"?>
  <ovf:Envelope
    xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
    xmlns:vmw="http://www.vmware.com/schema/ovf"
    xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData"
    xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData"
    ovf:version="1.0">

    <ovf:References>
      <ovf:File ovf:id="file1" ovf:href="__B__.vmdk" ovf:size="__FILE_BYTES__"/>
    </ovf:References>

    <ovf:NetworkSection>
      <ovf:Info>Logical networks used in the package</ovf:Info>
      <ovf:Network ovf:name="__NETWORK__"/>
    </ovf:NetworkSection>

    <ovf:DiskSection>
      <ovf:Info>Virtual disk information</ovf:Info>
      <ovf:Disk ovf:diskId="vmdisk1" ovf:fileRef="file1"
                ovf:capacity="__DISK_BYTES__"
                ovf:capacityAllocationUnits="byte"
                ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized"/>
    </ovf:DiskSection>

    <ovf:VirtualSystem ovf:id="__B__">
      <ovf:Info>__OS_NAME__ __OS_VER__</ovf:Info>

      <ovf:OperatingSystemSection ovf:id="101" vmw:osType="__GUEST_ID__">
        <ovf:Info>Guest OS type</ovf:Info>
        <ovf:Description>__OS_DESC__</ovf:Description>
      </ovf:OperatingSystemSection>

      <ovf:VirtualHardwareSection>
        <ovf:Info>Virtual hardware requirements</ovf:Info>

        <ovf:System>
            <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
            <vssd:InstanceID>0</vssd:InstanceID>
            <vssd:VirtualSystemIdentifier>__B__</vssd:VirtualSystemIdentifier>
            <vssd:VirtualSystemType>vmx-14</vssd:VirtualSystemType>
          </ovf:System>

        <ovf:Item>
          <rasd:Description>Number of Virtual CPUs</rasd:Description>
          <rasd:ElementName>__CPU__ virtual CPU(s)</rasd:ElementName>
          <rasd:InstanceID>1</rasd:InstanceID>
          <rasd:ResourceType>3</rasd:ResourceType>
          <rasd:VirtualQuantity>__CPU__</rasd:VirtualQuantity>
        </ovf:Item>

        <ovf:Item>
          <rasd:Description>Memory Size</rasd:Description>
          <rasd:ElementName>__MEM__MB of memory</rasd:ElementName>
          <rasd:InstanceID>2</rasd:InstanceID>
          <rasd:ResourceType>4</rasd:ResourceType>
          <rasd:VirtualQuantity>__MEM__</rasd:VirtualQuantity>
          <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
        </ovf:Item>

        <ovf:Item>
          <rasd:ElementName>SCSI Controller 0</rasd:ElementName>
          <rasd:InstanceID>3</rasd:InstanceID>
          <rasd:ResourceType>6</rasd:ResourceType>
          <rasd:ResourceSubType>lsilogicsas</rasd:ResourceSubType>
          <rasd:BusNumber>0</rasd:BusNumber>
          <rasd:Address>0</rasd:Address>
        </ovf:Item>

        <ovf:Item>
          <rasd:ElementName>Hard disk 1</rasd:ElementName>
          <rasd:InstanceID>4</rasd:InstanceID>
          <rasd:ResourceType>17</rasd:ResourceType>
          <rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>
          <rasd:Parent>3</rasd:Parent>
          <rasd:AddressOnParent>0</rasd:AddressOnParent>
        </ovf:Item>

        <ovf:Item>
          <rasd:ElementName>Network adapter 1</rasd:ElementName>
          <rasd:InstanceID>5</rasd:InstanceID>
          <rasd:ResourceType>10</rasd:ResourceType>
          <rasd:ResourceSubType>VMXNET3</rasd:ResourceSubType>
          <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
          <rasd:Connection>__NETWORK__</rasd:Connection>
        </ovf:Item>

      </ovf:VirtualHardwareSection>
    </ovf:VirtualSystem>
  </ovf:Envelope>
  OVF

        # sed helper (BSD/GNU safe) + escaper
        _inplace_sed() { if sed --version >/dev/null 2>&1; then sed -i "$1" "$2"; else sed -i '' "$1" "$2"; fi; }
        esc() { printf '%s' "$1" | sed 's/[&/]/\\&/g'; }

        NETWORK_NAME="$${NETWORK_NAME:-VM Network}"
        GUEST_ID="$${GUEST_ID:-${var.vm_guest_os_type}}"
        OS_NAME="$${OS_NAME:-${var.vm_guest_os_name}}"
        OS_VER="$${OS_VER:-${var.vm_guest_os_version}}"
        OS_DESC="$${OS_DESC:-${var.vm_guest_os_name} ${var.vm_guest_os_version}}"

        _inplace_sed "s/__B__/$(esc "$B")/g" "$OVF"
        _inplace_sed "s/__DISK_BYTES__/$(esc "$DISK_BYTES")/g" "$OVF"
        _inplace_sed "s/__FILE_BYTES__/$(esc "$FILE_BYTES")/g" "$OVF"
        _inplace_sed "s/__NETWORK__/$(esc "$NETWORK_NAME")/g" "$OVF"
        _inplace_sed "s/__CPU__/$(esc "${var.vm_cpu_count}")/g" "$OVF"
        _inplace_sed "s/__MEM__/$(esc "${var.vm_mem_size}")/g" "$OVF"
        _inplace_sed "s/__OS_NAME__/$(esc "$OS_NAME")/g" "$OVF"
        _inplace_sed "s/__OS_VER__/$(esc "$OS_VER")/g" "$OVF"
        _inplace_sed "s/__OS_DESC__/$(esc "$OS_DESC")/g" "$OVF"
        _inplace_sed "s/__GUEST_ID__/$(esc "$GUEST_ID")/g" "$OVF"

        # Manifest
        if command -v shasum >/dev/null 2>&1; then
          (cd "$D" && shasum -a 256 "$B.ovf" "$B.vmdk" | awk '{print "SHA256(" $2 ")= " $1 }' > "$MF")
        else
          (cd "$D" && sha256sum "$B.ovf" "$B.vmdk" | awk '{print "SHA256(" $2 ")= " $1 }' > "$MF")
        fi

        # pack to OVA
        if [ "${var.pack_ova}" = "true" ]; then
          (cd "$D" && tar -cvf "$B.ova" "$B.ovf" "$B.vmdk" "$B.mf")
        fi
      fi
    EOT
    ]
  }

  // Publish just the converted files (+ qcow2)
  post-processor "artifice" {
    files = [
      "${local.output_dir}/${local.qcow2_artifact}", # .qcow2 or .qcow2.gz
      "${local.output_dir}/${local.vm_name}.vmdk",
      "${local.output_dir}/${local.vm_name}.vhd",
      # we may want OVA for GCP to be part of the artifact set too, uncomment the next line:
      # "${local.output_dir}/${local.vm_name}.ova",
    ]
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

