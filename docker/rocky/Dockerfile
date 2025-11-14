# docker/rocky/Dockerfile
# syntax = docker/dockerfile:1.4

ARG TARGETARCH=linux/amd64

FROM --platform=$TARGETARCH rockylinux:9

ENV TZ=UTC \
    container=docker

# Base OS + systemd + useful tools
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

# pulsys admin user
RUN useradd -m -s /bin/bash pulsys && \
    echo "pulsys ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

# Prepare systemd dirs
RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd


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

# ---------------------------------------------------------------------------

EXPOSE 22

STOPSIGNAL SIGRTMIN+3
VOLUME ["/sys/fs/cgroup", "/run", "/tmp"]

CMD ["/sbin/init"]
