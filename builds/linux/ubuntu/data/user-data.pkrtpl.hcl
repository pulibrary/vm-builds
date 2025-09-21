#cloud-config
# Create the build user and allow SSH password logins
users:
  - name: ${build_username}
    gecos: Packer Build User
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: false
%{ if build_key != "" }
    ssh_authorized_keys:
      - ${build_key}
%{ endif }

chpasswd:
  list: |
    ${build_username}:${build_password}
  expire: false

ssh_pwauth: true

package_update: true
package_upgrade: false
packages:
%{ for p in additional_packages ~}
  - ${p}
%{ endfor ~}

# Ensure SSH service is enabled (cloud images usually already have it)
runcmd:
  - systemctl enable --now ssh || systemctl enable --now sshd

# Make sure NoCloud is considered
write_files:
  - path: /etc/cloud/cloud.cfg.d/99_packer_nocloud.cfg
    permissions: "0644"
    content: |
      datasource_list: [ NoCloud, None ]
  - path: /etc/security-tools.env
    permissions: '0600'
    content: |
      # BigFix
      BIGFIX_MASTHEAD_URL=${BIGFIX_MASTHEAD_URL}
      # Rapid7
      RAPID7_TOKEN=${RAPID7_TOKEN}
      RAPID7_ATTRIBUTES=Library Systems
      # CrowdStrike Falcon
      FALCON_CID=${FALCON_CID}
runcmd:
  - systemctl start bigfix-firstboot.service || true
  - systemctl start rapid7-firstboot.service || true
  - systemctl start falcon-firstboot.service || true

# Locales & timezone
timezone: ${vm_guest_os_timezone}
locale: ${vm_guest_os_language}
keyboard:
  layout: ${vm_guest_os_keyboard}
