# docker/ubuntu/Dockerfile
# syntax = docker/dockerfile:1.4
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ARG ANSIBLE_CORE_VERSION=2.16.3
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    container=docker \
    ANSIBLE_VENV=/opt/ansible \
    PATH=/opt/ansible/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

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
    echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

# Prepare systemd dirs
RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# Optimize systemd for container use
RUN for unit in \
      systemd-remount-fs.service \
      sys-kernel-config.mount \
      sys-kernel-debug.mount \
      sys-kernel-tracing.mount \
      e2scrub_reap.service \
      systemd-pstore.service \
      systemd-ask-password-wall.path \
      systemd-update-utmp.service; do \
      systemctl mask "$unit" || echo "skip mask $unit"; \
    done

# Disable network wait service (major culprit for delays)
RUN systemctl disable systemd-networkd-wait-online.service \
    || echo "skip disable systemd-networkd-wait-online.service"

# Configure journald for minimal overhead
RUN mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=8M\n' > /etc/systemd/journald.conf.d/volatile.conf

# Ansible bits, isolated in a venv so newer Ubuntu releases
# with externally managed system Python (PEP 668) build cleanly
RUN python3 -m venv "$ANSIBLE_VENV" \
    && "$ANSIBLE_VENV/bin/python" -m pip install --upgrade pip setuptools wheel \
    && "$ANSIBLE_VENV/bin/python" -m pip install \
         "ansible-core==${ANSIBLE_CORE_VERSION}" \
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
