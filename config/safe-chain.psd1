@{
    Version = '1.5.15'
    Repository = 'AikidoSec/safe-chain'
    Windows = @{
        Installer = 'install-safe-chain.ps1'
        InstallerSha256 = '5fc22eef74814bef6828aa07c0eaec79598f343f98b94a4acab823769ad56da1'
        BinarySha256 = 'b51a939025f6bb228521626f78247d6ef6a75fa6483868175a9158c9e2752b0d'
    }
    Linux = @{
        Installer = 'install-safe-chain.sh'
        InstallerSha256 = 'de0565e3d6346407a604e84e639e95fea8758748063da2216bbfdca5feda5dd2'
        BinarySha256 = 'e78675981e4b5e6886cbcf3b4a8975b164e102dab68c56de7580d3b668c25cb4'
    }
    SupportedCommands = @(
        'npm', 'npx', 'yarn', 'pnpm', 'pnpx', 'rush', 'rushx', 'bun', 'bunx',
        'uv', 'uvx', 'pip', 'pip3', 'poetry', 'python', 'python3', 'pipx', 'pdm'
    )
}
