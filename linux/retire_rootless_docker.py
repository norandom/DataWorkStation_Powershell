"""Retire Debian-MW Docker only after the caller validates rootless Podman."""

import os
import pwd
import shlex

from pyinfra.operations import apt, files, server

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

server.shell(
    name="Stop and disable the legacy rootless Docker service",
    commands=[
        f"{user_environment} systemctl --user disable --now docker.service 2>/dev/null || true",
        "systemctl disable --now docker.service docker.socket 2>/dev/null || true",
    ],
)

files.file(
    name="Remove the legacy rootless Docker user unit",
    path=f"{home}/.config/systemd/user/docker.service",
    present=False,
)

apt.packages(
    name="Remove legacy Docker runtime packages after the Podman gate",
    packages=[
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
        "docker-ce-rootless-extras",
    ],
    present=False,
)

for repository_path in (
    "/etc/apt/sources.list.d/docker.sources",
    "/etc/apt/sources.list.d/docker.list",
    "/etc/apt/keyrings/docker.asc",
):
    files.file(
        name=f"Remove legacy Docker repository state {repository_path}",
        path=repository_path,
        present=False,
    )

files.file(
    name="Remove any stale package-service start inhibitor",
    path="/usr/sbin/policy-rc.d",
    present=False,
)
