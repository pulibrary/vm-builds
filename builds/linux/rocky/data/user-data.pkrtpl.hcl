#cloud-config

preserve_hostname: false
hostname: lib-vm

ssh_pwauth: true

users:
  - name: ${build_username}
    gecos: "Packer"
    uid: 1010
    groups: [ wheel, adm, systemd-journal ]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    lock_passwd: false
%{ if build_key != "" }
    ssh_authorized_keys:
      - ${build_key}
%{ endif }

# Prefer encrypted password if provided, else plain (cloud-init will hash it).
%{ if build_password_encrypted != "" }
chpasswd:
  list: |
    ${build_username}:${build_password_encrypted}
  expire: false
%{ else }
chpasswd:
  list: |
    ${build_username}:${build_password}
  expire: false
%{ endif }

package_update: true
package_upgrade: false
packages: []
# We are installing extras via Ansible;

#growpart:
#  mode: auto
#  devices: [ / ]
#  ignore_growroot_disabled: false
#
## Create a swapfile without repartitioning
#swap:
#  filename: /swapfile
#  size: auto
#  maxsize: 2048M
#

# Network config (cloud-init v2). We inject the pre-rendered snippet.
${network}

# Storage config
${storage}

# Small selinux tweaks typical for RHEL-family cloud images
write_files:
  - path: /etc/sysconfig/selinux
    permissions: '0644'
    content: |
      SELINUX=enforcing
      SELINUXTYPE=targeted
  - path: /etc/pul/security-tools.env
    permissions: '0600'
    content: |
      # BigFix
      BIGFIX_MASTHEAD_URL=${BIGFIX_MASTHEAD_URL}
      # Rapid7
      RAPID7_TOKEN=${RAPID7_TOKEN}
      RAPID7_ATTRIBUTES="Library Systems"
      # CrowdStrike Falcon
      FALCON_CID=${FALCON_CID}

runcmd:
  # ensure wheel has passwordless sudo (some images have it already)
  - [ bash, -lc, "echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99-wheel-nopasswd && chmod 440 /etc/sudoers.d/99-wheel-nopasswd" ]
  # make sure cloud-init finished before packer tries ssh
  - [ systemctl, is-active, --quiet, cloud-init-local ]
  - [ systemctl, is-active, --quiet, cloud-init ]
  - [ systemctl, is-active, --quiet, cloud-config ]
  - [ systemctl, is-active, --quiet, cloud-final ]

