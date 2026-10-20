# docker/rocky/Dockerfile
# syntax = docker/dockerfile:1.4
# The Docker Official "rockylinux" image stopped at 9.3; Rocky publishes
# current releases as rockylinux/rockylinux. The tag and digest are pinned so a
# rebuild is reproducible, and Renovate proposes both when Rocky publishes.
FROM rockylinux/rockylinux:10.2@sha256:827d37bc128288ccf160ee318bb3cb92d591164cb217e92f8bc61e3982ae1834

# Links the published image to this repository in GHCR. Without the link the
# package keeps the permissions of whoever pushed it first by hand, and the
# workflow's GITHUB_TOKEN is refused with "permission_denied: write_package".
LABEL org.opencontainers.image.source="https://github.com/pulibrary/vm-builds"

ENV TZ=UTC \
    container=docker

# renovate: datasource=rpm depName=systemd versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG SYSTEMD_VERSION=257-23.el10_2.2.rocky.0.1
# renovate: datasource=rpm depName=sudo versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG SUDO_VERSION=1.9.17-10.p2.el10_2.7
# renovate: datasource=rpm depName=openssh-server versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG OPENSSH_SERVER_VERSION=9.9p1-28.el10_2.rocky.0.1
# renovate: datasource=rpm depName=net-tools versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG NET_TOOLS_VERSION=2.0-0.73.20160912git.el10
# renovate: datasource=rpm depName=ca-certificates versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG CA_CERTIFICATES_VERSION=2025.2.80_v9.0.305-102.el10
# renovate: datasource=rpm depName=python3 versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG PYTHON3_VERSION=3.12.15-1.el10_2
# renovate: datasource=rpm depName=python3-pip versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/AppStream/x86_64/os/repodata/
ARG PYTHON3_PIP_VERSION=23.3.2-11.el10_2
# renovate: datasource=rpm depName=python3-dnf versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG PYTHON3_DNF_VERSION=4.20.0-22.el10_2.rocky.0.1
# renovate: datasource=rpm depName=gnupg2 versioning=rpm registryUrl=https://dl.rockylinux.org/pub/rocky/10/BaseOS/x86_64/os/repodata/
ARG GNUPG2_VERSION=2.4.5-4.el10_1

# Everything is one layer, and the package set mirrors the Ubuntu image.
#
# tmp.mount and systemd-tmpfiles-clean are masked so systemd can never remount
# or sweep /tmp while a playbook is running against this container; that would
# silently delete files a controller has already written there.
#
# The shipped /usr/lib/tmpfiles.d/tmp.conf tells
# systemd-tmpfiles-setup.service (running --create --remove --boot) to delete
# everything under /tmp during boot. A controller that connects while the
# container is still booting can have its staged files deleted mid-task, which
# fails the same way. A file of the same name in /etc/tmpfiles.d overrides the
# shipped one, and lowercase "d" creates the directory without ever removing
# its contents.
#
# journald keeps its logs in memory and small, for minimal overhead.
#
# DF005 is a false positive: droast does not recognise name-version-release
# as a dnf pin.
# droast ignore=DF005
RUN dnf -y install \
       "systemd-${SYSTEMD_VERSION}" \
       "sudo-${SUDO_VERSION}" \
       "openssh-server-${OPENSSH_SERVER_VERSION}" \
       "net-tools-${NET_TOOLS_VERSION}" \
       "ca-certificates-${CA_CERTIFICATES_VERSION}" \
       "python3-${PYTHON3_VERSION}" \
       "python3-pip-${PYTHON3_PIP_VERSION}" \
       "python3-dnf-${PYTHON3_DNF_VERSION}" \
       "gnupg2-${GNUPG2_VERSION}" \
    && dnf clean packages \
    && useradd -m -s /bin/bash pulsys \
    && echo "pulsys ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pulsys \
    && chmod 440 /etc/sudoers.d/99-pulsys \
    && mkdir -p /run/systemd /var/log/journal /var/run/sshd \
    && mkdir -p /root/.ansible/tmp /var/tmp/ansible \
    && chmod 700 /root/.ansible/tmp \
    && chmod 1777 /var/tmp/ansible \
    && systemctl mask \
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
       systemd-tmpfiles-clean.service \
    && { systemctl disable NetworkManager-wait-online.service 2>/dev/null || true; } \
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
