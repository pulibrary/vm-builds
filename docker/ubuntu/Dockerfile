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
       python3 \
       python3-venv \
       python3-pip \
    && rm -rf /var/lib/apt/lists/*

# pulsys admin user
RUN useradd -m -s /bin/bash pulsys && \
    echo "pulsys ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

# Prepare systemd dirs
RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# Ansible bits
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install \
         ansible-core==2.16.3 \
         pyopenssl

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
VOLUME ["/sys/fs/cgroup", "/run", "/tmp"]

CMD ["/sbin/init"]

