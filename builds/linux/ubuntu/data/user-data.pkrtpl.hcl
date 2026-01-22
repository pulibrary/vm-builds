#cloud-config
# Create the build user and allow SSH password logins
users:
  - name: ${build_username}
    gecos: Packer Build User
    uid: 1010
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: "ALL=(ALL:ALL) NOPASSWD:ALL"
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

# Make sure NoCloud is considered
write_files:
  - path: /etc/cloud/cloud.cfg.d/99_packer_nocloud.cfg
    permissions: "0644"
    content: |
      datasource_list: [ NoCloud, None ]
  - path: /etc/cloud/cloud.cfg.d/90_packer_default_user.cfg
    permissions: "0644"
    content: |
      system_info:
        default_user:
          name: ${build_username}
          gecos: Packer Build User
          groups: [adm, sudo]
          shell: /bin/bash
          sudo: "ALL=(ALL:ALL) NOPASSWD:ALL"
          lock_passwd: false
  - path: /etc/pul/security-tools.env
    permissions: '0600'
    content: |
      # BigFix
      BIGFIX_MASTHEAD_URL=${BIGFIX_MASTHEAD_URL}
      # Rapid7
      RAPID7_TOKEN=${RAPID7_TOKEN}
      RAPID7_ATTRIBUTES="Library Systems"
      # Palo Alto Cortex XDR
      CORTEX_XDR_DEB_TARBALL_URL=${CORTEX_XDR_DEB_TARBALL_URL}
      CORTEX_XDR_DISTRIBUTION_ID=${CORTEX_XDR_DISTRIBUTION_ID}
      CORTEX_XDR_DISTRIBUTION_SERVER=${CORTEX_XDR_DISTRIBUTION_SERVER}
runcmd:
  - systemctl enable --now ssh || systemctl enable --now sshd
  - "id ubuntu >/dev/null 2>&1 && deluser --remove-home ubuntu || true"
# Locales & timezone
timezone: ${vm_guest_os_timezone}
locale: ${vm_guest_os_language}
keyboard:
  layout: ${vm_guest_os_keyboard}
