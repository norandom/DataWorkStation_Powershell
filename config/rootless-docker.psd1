@{
    BaseDistribution = 'Debian'
    PyinfraVersion = '3.9.2'
    Pyinfra = '/opt/dataworkstation/pyinfra/bin/pyinfra'
    Pip = '/opt/dataworkstation/pyinfra/bin/pip'
    DockerRepository = 'https://download.docker.com/linux/debian'
    DockerGpgUrl = 'https://download.docker.com/linux/debian/gpg'
    DockerGpgSha256 = '1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570'
    RequiredPackages = @(
        'uidmap'
        'dbus-user-session'
        'slirp4netns'
        'docker-ce'
        'docker-ce-cli'
        'containerd.io'
        'docker-buildx-plugin'
        'docker-compose-plugin'
        'docker-ce-rootless-extras'
    )
    Deploy = 'linux/rootless_docker.py'
    RootlessSecurityOption = 'name=rootless'
    RootfulServices = @('docker.service', 'docker.socket')
    UserService = 'docker.service'
}
