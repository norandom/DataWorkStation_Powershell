@{
    DockerGpgUrl = 'https://download.docker.com/linux/debian/gpg'
    DockerGpgSha256 = '1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570'
    RequiredPackages = @(
        'docker-ce'
        'docker-ce-cli'
        'containerd.io'
        'docker-buildx-plugin'
        'docker-compose-plugin'
    )
    Deploy = 'linux/developer_docker.py'
}
