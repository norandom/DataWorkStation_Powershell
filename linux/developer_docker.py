"""Adopt and maintain the rootful Docker daemon used by Dagger in Debian."""

import os
import subprocess
from pathlib import Path

from pyinfra.operations import apt, files, server

linux_user = os.environ["DEVELOPER_DOCKER_USER"]
os_release = {}
for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
    if "=" in line:
        key, value = line.split("=", 1)
        os_release[key] = value.strip('"')
codename = os_release["VERSION_CODENAME"]
architecture = subprocess.check_output(["dpkg", "--print-architecture"], text=True).strip()

files.directory(
    name="Maintain the Docker APT keyring directory",
    path="/etc/apt/keyrings",
    mode="755",
    _sudo=True,
)

files.download(
    name="Maintain the hash-pinned Docker repository signing key",
    src="https://download.docker.com/linux/debian/gpg",
    dest="/etc/apt/keyrings/docker.asc",
    mode="644",
    sha256sum="1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570",
    _sudo=True,
)

files.template(
    name="Maintain the official Docker Debian repository",
    src=str(Path(__file__).parent / "assets" / "docker.sources.j2"),
    dest="/etc/apt/sources.list.d/docker.sources",
    mode="644",
    codename=codename,
    architecture=architecture,
    _sudo=True,
)

files.file(
    name="Remove a duplicate one-line Docker repository declaration",
    path="/etc/apt/sources.list.d/docker.list",
    present=False,
    _sudo=True,
)

apt.packages(
    name="Maintain the developer Docker Engine and Compose packages",
    packages=[
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
    ],
    present=True,
    update=True,
    _sudo=True,
)

server.user(
    name="Allow the selected developer user to call the Docker daemon",
    user=linux_user,
    groups=["docker"],
    append=True,
    _sudo=True,
)

server.service(
    name="Keep the rootful Docker daemon available for Dagger",
    service="docker.service",
    running=True,
    enabled=True,
    _sudo=True,
)

server.service(
    name="Keep Docker socket activation enabled for developer tools",
    service="docker.socket",
    running=True,
    enabled=True,
    _sudo=True,
)

files.put(
    name="Record developer Docker adoption by the workstation DSL",
    src=str(Path(__file__).parent / "assets" / "developer-docker.managed"),
    dest="/var/lib/dataworkstation/developer-docker.managed",
    mode="644",
    _sudo=True,
)

if os.environ.get("DEVELOPER_DOCKER_REINITIALIZE") == "1":
    server.service(
        name="Restart the declared developer Docker daemon",
        service="docker.service",
        restarted=True,
        _sudo=True,
    )
