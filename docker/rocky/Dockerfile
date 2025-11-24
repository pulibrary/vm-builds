# docker/rocky/Dockerfile
# syntax = docker/dockerfile:1.4
FROM rockylinux:9
ENV TZ=UTC \
    container=docker

RUN dnf -y update \
    && dnf -y install \
       systemd \
       sudo \
       openssh-server \
       net-tools \
       ca-certificates \
       python3 \
       python3-pip \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN useradd -m -s /bin/bash pulsys && \
    echo "pulsys ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# ansible-core 2.15.x works with Python 3.9
RUN python3 -m pip install --upgrade pip \
    && python3 -m pip install \
         ansible-core==2.15.13 \
         pyopenssl

COPY ansible/collections.yaml /tmp/collections.yaml
RUN ansible-galaxy collection install -r /tmp/collections.yaml \
    && rm -f /tmp/collections.yaml

RUN mkdir -p /etc/ansible \
    && printf "[local]\nlocalhost ansible_connection=local\n" > /etc/ansible/hosts

RUN mkdir -p /root/.ansible/tmp /tmp/ansible \
    && chmod -R 777 /root/.ansible/tmp \
    && chmod -R 1777 /tmp/ansible

# Optimize systemd for container use
RUN systemctl mask \
    systemd-remount-fs.service \
    sys-kernel-config.mount \
    sys-kernel-debug.mount \
    sys-kernel-tracing.mount \
    systemd-pstore.service \
    systemd-ask-password-wall.path \
    systemd-update-utmp.service \
    systemd-tmpfiles-setup-dev.service \
    dnf-makecache.timer \
    kdump.service

# Disable network wait service
RUN systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

# Configure journald for minimal overhead
RUN mkdir -p /etc/systemd/journald.conf.d && \
    echo -e "[Journal]\nStorage=volatile\nRuntimeMaxUse=8M" > /etc/systemd/journald.conf.d/volatile.conf

EXPOSE 22
STOPSIGNAL SIGRTMIN+3
VOLUME ["/sys/fs/cgroup", "/run", "/tmp"]
CMD ["/sbin/init"]
