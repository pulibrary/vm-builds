#!/usr/bin/bash -eux

## install base tools
echo "==> Installing base tools"
apt-get update -y
apt-get install vim -y
apt-get update -y
apt-get install curl apt-transport-https ca-certificates wget -y
apt-get update -y
apt-get install build-essential -y
apt-get update -y
apt install python3 -y
apt install ansible -y
apt-get upgrade -y
