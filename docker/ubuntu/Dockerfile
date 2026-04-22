# docker/ubuntu/Dockerfile
# syntax = docker/dockerfile:1.4
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    container=docker

# Base OS + systemd + useful tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       systemd systemd-sysv \
       sudo \
       openssh-server \
       net-tools \
       ca-certificates \
       curl \
       gnupg2 \
       software-properties-common

# install python 3.12
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y python3.12 python3.12-venv python3.12-dev \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12

# Use the 3.12 binary for Ansible
RUN python3.12 -m pip install --upgrade pip \
    && python3.12 -m pip install ansible-core==2.19.4 pyopenssl \
    && rm -rf /var/lib/apt/lists/*

# pulsys admin user
RUN useradd -m -s /bin/bash pulsys && \
    echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

# Prepare systemd dirs
RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# Optimize systemd for container use
RUN systemctl mask \
    systemd-remount-fs.service \
    sys-kernel-config.mount \
    sys-kernel-debug.mount \
    sys-kernel-tracing.mount \
    e2scrub_reap.service \
    systemd-pstore.service \
    systemd-ask-password-wall.path \
    systemd-update-utmp.service

# Disable network wait service (major culprit for delays)
RUN systemctl disable systemd-networkd-wait-online.service

# Configure journald for minimal overhead
RUN mkdir -p /etc/systemd/journald.conf.d && \
    echo -e "[Journal]\nStorage=volatile\nRuntimeMaxUse=8M" > /etc/systemd/journald.conf.d/volatile.conf


COPY ansible/collections.yaml /tmp/collections.yaml
RUN ansible-galaxy collection install -r /tmp/collections.yaml \
    && rm -f /tmp/collections.yaml

RUN mkdir -p /etc/ansible \
    && printf "[local]\nlocalhost ansible_connection=local\n" > /etc/ansible/hosts

RUN mkdir -p /root/.ansible/tmp /tmp/ansible \
    && chmod -R 777 /root/.ansible/tmp \
    && chmod -R 1777 /tmp/ansible

EXPOSE 22
STOPSIGNAL SIGRTMIN+3
VOLUME ["/sys/fs/cgroup", "/run"]
CMD ["/sbin/init"]
