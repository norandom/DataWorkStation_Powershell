"""Provision local rootless Podman in Debian-MW without enabling an API service."""

import os
import pwd
import shlex

from pyinfra.operations import apt, server

linux_user = os.environ["ROOTLESS_PODMAN_USER"]
user_record = pwd.getpwnam(linux_user)
uid = user_record.pw_uid
home = user_record.pw_dir
quoted_user = shlex.quote(linux_user)
user_environment = (
    f"runuser -u {quoted_user} -- env "
    f"HOME={shlex.quote(home)} USER={quoted_user} LOGNAME={quoted_user} "
    f"XDG_RUNTIME_DIR=/run/user/{uid} "
    f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus "
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
)

apt.packages(
    name="Install Debian rootless Podman and storage/network helpers",
    packages=["podman", "uidmap", "dbus-user-session", "fuse-overlayfs", "passt"],
    present=True,
    update=True,
)

server.shell(
    name="Maintain subordinate IDs for the dedicated analysis user",
    commands=[
        f"grep -q '^{quoted_user}:' /etc/subuid || usermod --add-subuids 100000-165535 {quoted_user}",
        f"grep -q '^{quoted_user}:' /etc/subgid || usermod --add-subgids 100000-165535 {quoted_user}",
    ],
)

server.shell(
    name="Keep Podman daemonless and remove Docker-era linger state",
    commands=[
        f"{user_environment} systemctl --user disable --now podman.socket podman.service 2>/dev/null || true",
        f"loginctl disable-linger {quoted_user} 2>/dev/null || true",
    ],
)

server.shell(
    name="Initialize and validate the selected user's local rootless Podman store",
    commands=[f"{user_environment} podman info --format json >/dev/null"],
)
