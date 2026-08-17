# docker/rocky/Dockerfile
# syntax = docker/dockerfile:1.4
FROM rockylinux:9
ENV TZ=UTC \
    container=docker

# Ansible is deliberately NOT installed: this image is a managed node, not a
# control host. The controller ships its own module code over the connection,
# so all a target needs is a Python interpreter.
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
    echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# Somewhere for a controller to stage modules. Both paths are plain
# directories in the image, never mount points, so a controller can write here
# and then execute what it wrote. Putting Ansible's remote_tmp on a tmpfs or
# volume mount instead is unreliable and shows up as
# "can't open file .../AnsiballZ_setup.py: No such file or directory".
RUN mkdir -p /root/.ansible/tmp /var/tmp/ansible \
    && chmod 700 /root/.ansible/tmp \
    && chmod 1777 /var/tmp/ansible

# Optimize systemd for container use.
# tmp.mount and systemd-tmpfiles-clean are masked so systemd can never remount
# or sweep /tmp while a playbook is running against this container; that would
# silently delete files a controller has already written there.
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
    kdump.service \
    tmp.mount \
    systemd-tmpfiles-clean.timer \
    systemd-tmpfiles-clean.service

# Disable network wait service
RUN systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

# Stop systemd from emptying /tmp and /var/tmp while a playbook is running.
# The shipped /usr/lib/tmpfiles.d/tmp.conf tells
# systemd-tmpfiles-setup.service (running --create --remove --boot) to delete
# everything under /tmp during boot. A controller that connects while the
# container is still booting can have its staged files deleted mid-task, which
# fails as "can't open file .../AnsiballZ_setup.py: No such file or directory".
# A file of the same name in /etc/tmpfiles.d overrides the shipped one, and
# lowercase "d" creates the directory without ever removing its contents.
RUN mkdir -p /etc/tmpfiles.d \
    && printf 'd /tmp 1777 root root -\nd /var/tmp 1777 root root -\n' \
       > /etc/tmpfiles.d/tmp.conf

# Configure journald for minimal overhead
RUN mkdir -p /etc/systemd/journald.conf.d && \
    echo -e "[Journal]\nStorage=volatile\nRuntimeMaxUse=8M" > /etc/systemd/journald.conf.d/volatile.conf

EXPOSE 22
STOPSIGNAL SIGRTMIN+3
# No VOLUME here on purpose. Declaring /run, /tmp or /sys/fs/cgroup as volumes
# creates anonymous volumes that shadow whatever the caller mounts and makes
# copying files into those paths behave inconsistently between Docker and
# Podman. Callers mount what they need (see README).
CMD ["/sbin/init"]
