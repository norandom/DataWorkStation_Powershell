function Import-WslEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepositoryRoot,
        [string] $ConfigurationPath
    )

    . (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
    $configuration = Import-WorkstationConfiguration -RepositoryRoot $RepositoryRoot -ConfigurationPath $ConfigurationPath
    @{
        WSL_DISTRIBUTION = [string] $configuration.Wsl.developer.distribution
        WSL_USER = [string] $configuration.Wsl.developer.user
        WSL_MALWARE_DISTRIBUTION = [string] $configuration.Wsl.malware.distribution
        WSL_MALWARE_USER = [string] $configuration.Wsl.malware.user
        WSL_NIXOS_DISTRIBUTION = [string] $configuration.Wsl.nixos.distribution
        WSL_NIXOS_USER = [string] $configuration.Wsl.nixos.user
        WSL_AI_DISTRIBUTION = [string] $configuration.Wsl.ai.distribution
        WSL_AI_USER = [string] $configuration.Wsl.ai.user
    }
}
