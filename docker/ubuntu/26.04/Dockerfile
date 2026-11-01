# docker/ubuntu/26.04/Dockerfile
# syntax = docker/dockerfile:1.4
# Each Ubuntu release has its own Dockerfile so it can pin the package
# versions that exist in that release. The base image is pinned by tag and
# digest; Renovate proposes updates to both.
FROM ubuntu:26.04@sha256:6a06111c3b0a8600feadb270aec771dc239bf407b25625f93f44ab00e11f4d3c

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
# manager reads the name=version pins and looks them up in resolute,
# resolute-updates and resolute-security (see renovate.json). The Ubuntu
# archive only keeps the newest version in each pocket, so when Ubuntu
# publishes an update the old pin stops installing until the Renovate PR that
# bumps it is merged.
#
# The apt lists are deliberately kept, so DF004 is silenced: dropping them
# makes plain `apt` tasks fail with "No package matching '<name>' is
# available" unless every task remembers update_cache: true. Only downloaded
# .deb files are cleaned.
#
# The distro pip already accepts `--break-system-packages`, so unlike 22.04
# it is left as packaged.
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
       systemd=259.9-0ubuntu0.1 \
       systemd-sysv=259.9-0ubuntu0.1 \
       sudo=1.9.17p2-1ubuntu3.2 \
       openssh-server=1:10.2p1-2ubuntu3.8 \
       net-tools=2.10-2ubuntu1 \
       ca-certificates=20260816ubuntu0.26.04.1 \
       gnupg=2.4.8-4ubuntu3.1 \
       python3=3.14.3-0ubuntu2 \
       python3-apt=3.1.0ubuntu1.1 \
       python3-venv=3.14.3-0ubuntu2 \
       python3-pip=25.1.1+dfsg-1ubuntu2 \
    && apt-get clean \
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
