# docker/ubuntu/22.04/Dockerfile
# syntax = docker/dockerfile:1.4
# Each Ubuntu release has its own Dockerfile so it can pin the package
# versions that exist in that release. The base image is pinned by tag and
# digest; Renovate proposes updates to both.
FROM ubuntu:22.04@sha256:076e7bf82319619f28dd0aa9c02ab34b055ad37100395b4f49a2ffba04fb5e11

# Links the published image to this repository in GHCR. Without the link the
# package keeps the permissions of whoever pushed it first by hand, and the
# workflow's GITHUB_TOKEN is refused with "permission_denied: write_package".
LABEL org.opencontainers.image.source="https://github.com/pulibrary/vm-builds"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    container=docker

# Everything is one layer.
#
# Ansible is deliberately NOT installed: this image is a managed node, not a
# control host. The controller ships its own module code over the connection,
# so all a target needs is a Python interpreter.
#
# Package versions are pinned for reproducible builds. Renovate's dockerfile
# manager reads the name=version pins and looks them up in jammy,
# jammy-updates and jammy-security (see renovate.json). The Ubuntu
# archive only keeps the newest version in each pocket, so when Ubuntu
# publishes an update the old pin stops installing until the Renovate PR that
# bumps it is merged.
#
# The apt lists are deliberately kept, so DF004 is silenced: dropping them
# makes plain `apt` tasks fail with "No package matching '<name>' is
# available" unless every task remembers update_cache: true. Only downloaded
# .deb files are cleaned.
#
# The system pip is upgraded because 22.04 ships pip 22.0.2, which predates
# `--break-system-packages` (added in pip 23.0), while 24.04 and later ship a
# pip that requires that flag to touch the system environment. Without this, a
# playbook that works against newer releases fails here with "no such option:
# --break-system-packages". Renovate keeps the pin current, limited to releases
# that still support this image's Python 3.10.
#
# /root/.ansible/tmp and /var/tmp/ansible give a controller somewhere to stage
# modules. Both are plain directories in the image, never mount points, so a
# controller can write there and then execute what it wrote. Putting Ansible's
# remote_tmp on a tmpfs or volume mount instead is unreliable and shows up as
# "can't open file .../AnsiballZ_setup.py: No such file or directory".
#
# tmp.mount and systemd-tmpfiles-clean are masked so systemd can never remount
# or sweep /tmp while a playbook is running against this container; that would
# silently delete files a controller has already written there.
#
# The shipped /usr/lib/tmpfiles.d/tmp.conf uses "D", which tells
# systemd-tmpfiles-setup.service (running --create --remove --boot) to delete
# everything under /tmp during boot. A controller that connects while the
# container is still booting can have its staged files deleted mid-task, which
# fails the same way. A file of the same name in /etc/tmpfiles.d overrides the
# shipped one, and lowercase "d" creates the directory without ever removing
# its contents.
#
# journald keeps its logs in memory and small, for minimal overhead.
# droast ignore=DF004
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       systemd=249.11-0ubuntu3.23 \
       systemd-sysv=249.11-0ubuntu3.23 \
       sudo=1.9.9-1ubuntu2.7 \
       openssh-server=1:8.9p1-3ubuntu0.18 \
       net-tools=1.60+git20181103.0eebece-1ubuntu5.4 \
       ca-certificates=20260816ubuntu0.22.04.1 \
       gnupg=2.2.27-3ubuntu2.5 \
       python3=3.10.6-1~22.04.1 \
       python3-apt=2.4.0ubuntu4.1 \
       python3-venv=3.10.6-1~22.04.1 \
       python3-pip=22.0.2+dfsg-1ubuntu0.7 \
    && apt-get clean \
    && /usr/bin/pip3 install --no-cache-dir --upgrade pip==26.2.2 \
    && /usr/bin/pip3 --version \
    && useradd -m -s /bin/bash pulsys \
    && echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys \
    && chmod 440 /etc/sudoers.d/99-pulsys \
    && mkdir -p /run/systemd /var/log/journal /var/run/sshd \
    && mkdir -p /root/.ansible/tmp /var/tmp/ansible \
    && chmod 700 /root/.ansible/tmp \
    && chmod 1777 /var/tmp/ansible \
    && for unit in \
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
       done \
    && { systemctl disable systemd-networkd-wait-online.service \
         || echo "skip disable systemd-networkd-wait-online.service"; } \
    && mkdir -p /etc/tmpfiles.d \
    && printf 'd /tmp 1777 root root -\nd /var/tmp 1777 root root -\n' \
       > /etc/tmpfiles.d/tmp.conf \
    && mkdir -p /etc/systemd/journald.conf.d \
    && printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=8M\n' \
       > /etc/systemd/journald.conf.d/volatile.conf

# systemd must run as PID 1 with root privileges to manage units, and Ansible
# connects as root (or as pulsys with sudo). Stated explicitly rather than
# inherited from the base image. DF002 objects to root, but a non-root USER
# here would stop systemd from booting at all.
# droast ignore=DF002
USER root

# Healthy once systemd has finished booting. "degraded" also counts: some units
# that expect real hardware fail in a container, and the node is still usable.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/bin/sh", "-c", "state=$(systemctl is-system-running); [ \"$state\" = running ] || [ \"$state\" = degraded ]"]

EXPOSE 22
STOPSIGNAL SIGRTMIN+3
# No VOLUME here on purpose. Declaring /run, /tmp or /sys/fs/cgroup as volumes
# creates anonymous volumes that shadow whatever the caller mounts and makes
# copying files into those paths behave inconsistently between Docker and
# Podman. Callers mount what they need (see README).
CMD ["/sbin/init"]
