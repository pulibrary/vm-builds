# docker/ubuntu/Dockerfile
# syntax = docker/dockerfile:1.4
ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    container=docker

# Base OS + systemd + useful tools.
# Ansible is deliberately NOT installed: this image is a managed node, not a
# control host. The controller ships its own module code over the connection,
# so all a target needs is a Python interpreter.
# The apt lists are deliberately kept: dropping them makes plain `apt` tasks
# fail with "No package matching '<name>' is available" unless every task
# remembers update_cache: true.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       systemd systemd-sysv \
       sudo \
       openssh-server \
       net-tools \
       ca-certificates \
       gnupg \
       python3 \
       python3-apt \
       python3-venv \
       python3-pip

# Make the system pip behave the same on every release. Ubuntu 22.04 ships
# pip 22.0.2, which predates `--break-system-packages` (added in pip 23.0),
# while 24.04 and later ship a pip that requires that flag to touch the system
# environment. Without this, a playbook that works against newer releases fails
# on 22.04 with "no such option: --break-system-packages". Only older pips are
# upgraded, so newer releases keep their distro-managed pip.
RUN pip_major=$(/usr/bin/pip3 --version | awk '{print $2}' | cut -d. -f1) \
    && if [ "$pip_major" -lt 23 ]; then \
         /usr/bin/pip3 install --no-cache-dir --upgrade 'pip>=23.1'; \
       fi \
    && /usr/bin/pip3 --version

# pulsys admin user
RUN useradd -m -s /bin/bash pulsys && \
    echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys && \
    chmod 440 /etc/sudoers.d/99-pulsys

# Prepare systemd dirs
RUN mkdir -p /run/systemd /var/log/journal /var/run/sshd

# Optimize systemd for container use.
# tmp.mount and systemd-tmpfiles-clean are masked so systemd can never remount
# or sweep /tmp while a playbook is running against this container; that would
# silently delete files a controller has already written there.
RUN for unit in \
      systemd-remount-fs.service \
      sys-kernel-config.mount \
      sys-kernel-debug.mount \
      sys-kernel-tracing.mount \
      e2scrub_reap.service \
      systemd-pstore.service \
      systemd-ask-password-wall.path \
      systemd-update-utmp.service \
      tmp.mount \
      systemd-tmpfiles-clean.timer \
      systemd-tmpfiles-clean.service; do \
      systemctl mask "$unit" || echo "skip mask $unit"; \
    done

# Disable network wait service (major culprit for delays)
RUN systemctl disable systemd-networkd-wait-online.service \
    || echo "skip disable systemd-networkd-wait-online.service"

# Stop systemd from emptying /tmp and /var/tmp while a playbook is running.
# The shipped /usr/lib/tmpfiles.d/tmp.conf uses "D", which tells
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
    printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=8M\n' > /etc/systemd/journald.conf.d/volatile.conf

# Somewhere for a controller to stage modules. Both paths are plain
# directories in the image, never mount points, so a controller can write here
# and then execute what it wrote. Putting Ansible's remote_tmp on a tmpfs or
# volume mount instead is unreliable and shows up as
# "can't open file .../AnsiballZ_setup.py: No such file or directory".
RUN mkdir -p /root/.ansible/tmp /var/tmp/ansible \
    && chmod 700 /root/.ansible/tmp \
    && chmod 1777 /var/tmp/ansible

EXPOSE 22
STOPSIGNAL SIGRTMIN+3
# No VOLUME here on purpose. Declaring /run, /tmp or /sys/fs/cgroup as volumes
# creates anonymous volumes that shadow whatever the caller mounts and makes
# copying files into those paths behave inconsistently between Docker and
# Podman. Callers mount what they need (see README).
CMD ["/sbin/init"]
