@{
    WindowsConfig = '%USERPROFILE%\.ssh\config'
    LinuxTargets = @(
        @{ DistributionVariable = 'WSL_DISTRIBUTION'; UserVariable = 'WSL_USER' }
        @{ DistributionVariable = 'WSL_NIXOS_DISTRIBUTION'; UserVariable = 'WSL_NIXOS_USER' }
    )
    PermissionDistributionVariable = 'WSL_NIXOS_DISTRIBUTION'
    PermissionUserVariable = 'WSL_NIXOS_USER'
    ExcludedDistributionVariable = 'WSL_MALWARE_DISTRIBUTION'
}
