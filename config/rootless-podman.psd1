@{
    SchemaVersion = 1
    RequiredDistribution = 'Debian-MW'
    BaseDistribution = 'Debian'
    PyinfraVersion = '3.9.2'
    Pyinfra = '/opt/dataworkstation/pyinfra/bin/pyinfra'
    Pip = '/opt/dataworkstation/pyinfra/bin/pip'
    RequiredPackages = @(
        'podman'
        'uidmap'
        'dbus-user-session'
        'fuse-overlayfs'
        'passt'
    )
    LegacyDockerPackages = @(
        'docker-ce'
        'docker-ce-cli'
        'containerd.io'
        'docker-buildx-plugin'
        'docker-compose-plugin'
        'docker-ce-rootless-extras'
    )
    LegacyDockerDataPaths = @(
        '.local/share/docker'
        '.docker'
    )
    PodmanStorageRelativePath = '.local/share/containers/storage'
    PodmanUserUnits = @('podman.socket', 'podman.service')
    LegacyDockerUserUnit = 'docker.service'
    LegacyDockerRepositoryFiles = @(
        '/etc/apt/sources.list.d/docker.sources'
        '/etc/apt/sources.list.d/docker.list'
        '/etc/apt/keyrings/docker.asc'
    )
    Deploy = 'linux/rootless_podman.py'
    RetireDeploy = 'linux/retire_rootless_docker.py'
}
