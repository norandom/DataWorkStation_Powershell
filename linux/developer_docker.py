"""Adopt and maintain the rootful Docker daemon used by Dagger in Debian."""

import copy
import json
import os
import subprocess
from datetime import UTC, datetime
from io import StringIO
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
network_mtu = int(os.environ["DEVELOPER_DOCKER_MTU"])
if not 1280 <= network_mtu <= 65535:
    raise ValueError("DEVELOPER_DOCKER_MTU must be between 1280 and 65535")
daemon_path = Path("/etc/docker/daemon.json")
current_config = json.loads(daemon_path.read_text(encoding="utf-8")) if daemon_path.exists() else {}
desired_config = copy.deepcopy(current_config)
desired_config["mtu"] = network_mtu
desired_config.setdefault("default-network-opts", {}).setdefault("bridge", {})[
    "com.docker.network.driver.mtu"
] = str(network_mtu)
config_changed = desired_config != current_config

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

if config_changed:
    candidate = "/etc/docker/daemon.dataworkstation-candidate.json"
    config_text = json.dumps(desired_config, indent=2) + "\n"
    files.put(
        name="Stage merged Docker MTU configuration, preserving unrelated settings",
        src=StringIO(config_text),
        dest=candidate,
        mode="600",
        _sudo=True,
    )
    server.shell(
        name="Validate the candidate before replacing Docker configuration",
        commands=[f"dockerd --validate --config-file={candidate}"],
        _sudo=True,
    )
    if daemon_path.exists():
        backup_stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%S%fZ")
        files.copy(
            name="Back up existing Docker daemon configuration",
            src=str(daemon_path),
            dest=f"{daemon_path}.dataworkstation-{backup_stamp}.bak",
            _sudo=True,
        )
    files.put(
        name="Persist Docker MTU for the default bridge and future custom bridges",
        src=StringIO(config_text),
        dest=str(daemon_path),
        mode="600",
        _sudo=True,
    )
    files.file(
        name="Remove the validated Docker configuration candidate",
        path=candidate,
        present=False,
        _sudo=True,
    )

server.service(
    name="Keep the rootful Docker daemon available for Dagger",
    service="docker.service",
    running=True,
    enabled=True,
    restarted=(config_changed or os.environ.get("DEVELOPER_DOCKER_REINITIALIZE") == "1"),
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
