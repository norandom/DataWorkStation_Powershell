"""Run Docker Engine as the selected dedicated Debian-MW user, not as WSL root."""

import os
import pwd
import shlex
import subprocess
from pathlib import Path

from pyinfra.operations import apt, files, server

linux_user = os.environ["ROOTLESS_DOCKER_USER"]
user_record = pwd.getpwnam(linux_user)
uid = user_record.pw_uid
home = user_record.pw_dir
architecture = subprocess.check_output(["dpkg", "--print-architecture"], text=True).strip()
os_release = {}
for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        os_release[key] = value.strip('"')
codename = os_release["VERSION_CODENAME"]
user_environment = (
    f"runuser -u {shlex.quote(linux_user)} -- env "
    f"HOME={shlex.quote(home)} USER={shlex.quote(linux_user)} "
    f"LOGNAME={shlex.quote(linux_user)} XDG_RUNTIME_DIR=/run/user/{uid} "
    f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{uid}/bus "
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
)

files.directory(
    name="Create the Docker APT keyring directory",
    path="/etc/apt/keyrings",
    mode="755",
)

files.download(
    name="Install the hash-pinned Docker repository signing key",
    src="https://download.docker.com/linux/debian/gpg",
    dest="/etc/apt/keyrings/docker.asc",
    mode="644",
    sha256sum="1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570",
)

files.template(
    name="Configure the official Docker Debian repository",
    src=str(Path(__file__).parent / "assets" / "docker.sources.j2"),
    dest="/etc/apt/sources.list.d/docker.sources",
    mode="644",
    codename=codename,
    architecture=architecture,
)

files.file(
    name="Remove the legacy one-line Docker repository declaration",
    path="/etc/apt/sources.list.d/docker.list",
    present=False,
)

files.put(
    name="Prevent package installation from starting a root-owned daemon",
    src=str(Path(__file__).parent / "assets" / "policy-rc.d"),
    dest="/usr/sbin/policy-rc.d",
    mode="755",
)

apt.packages(
    name="Install rootless Docker prerequisites",
    packages=[
        "uidmap",
        "dbus-user-session",
        "slirp4netns",
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
        "docker-ce-rootless-extras",
    ],
    present=True,
    update=True,
)

files.file(
    name="Remove the temporary package-service start inhibitor",
    path="/usr/sbin/policy-rc.d",
    present=False,
)

server.shell(
    name="Disable the root-owned Docker daemon and activation socket",
    commands=["systemctl disable --now docker.service docker.socket"],
)

server.shell(
    name="Keep the rootless Docker user service available when WSL starts",
    commands=[f"loginctl enable-linger {shlex.quote(linux_user)}"],
)

server.shell(
    name="Install the official rootless Docker user service",
    commands=[
        f"test -f {shlex.quote(home)}/.config/systemd/user/docker.service || "
        f"{user_environment} dockerd-rootless-setuptool.sh install"
    ],
)

server.shell(
    name="Enable and start rootless Docker",
    commands=[
        f"{user_environment} systemctl --user daemon-reload",
        f"{user_environment} systemctl --user enable --now docker.service",
        f"{user_environment} docker context use rootless",
    ],
)

if os.environ.get("ROOTLESS_DOCKER_REINITIALIZE") == "1":
    server.shell(
        name="Restart the declared rootless Docker daemon",
        commands=[f"{user_environment} systemctl --user restart docker.service"],
    )
