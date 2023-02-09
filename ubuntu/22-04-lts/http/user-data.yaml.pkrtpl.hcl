#cloud-config
autoinstall:
  version: 1
  early-commands:
  # If we install the SSH server using the subiquity `ssh` configuration then port 22 gets opened up to packer _before_
  # the requisite configuration has been done to allow Packer to SSH on to the guest O/S. This results in a failed build
  # as Packer exceeds its SSH permitted number of SSH handshake attempts.
  # To ensure this doesn't happen we stop the SSH service until right at the end when we re-enable it
  # using a late-command.
  - sudo systemctl stop ssh
  apt:
    conf: |
      Acquire {
        Check-Date "false";
      };
  
  ssh:
    allow-pw: true
    install-server: true
  user-data:
    disable_root: false
    users:
      - name: pulsys
        shell: /bin/bash
        lock-passwd: false
        # Password: 
        passwd: ${hashed_os_password}
  locale: en_US
  keyboard:
    layout: en
  package_update: false
  package_upgrade: false
  packages:
    - apt-transport-https
    - sudo
    - openssh-server
    - wget
    - curl
    - python3
    - python3-pip
    - open-vm-tools-dev
  
  late-commands:
    - sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /target/etc/ssh/sshd_config
29  - sed -i -e 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /target/etc/ssh/sshd_config
    - echo 'pulsys ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/pulsys
32  - curtin in-target --target=/target -- apt-get update
33  - curtin in-target --target=/target -- apt-get upgrade --yes
    - sudo systemctl start ssh
