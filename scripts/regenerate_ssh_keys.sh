#!/bin/bash
echo "Regenerating SSH keys..."
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server
echo "SSH keys regenerated."
systemctl disable regenerate-ssh-keys.service
