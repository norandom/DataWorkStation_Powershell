@{
    WindowsConfig = '%USERPROFILE%\.ssh\config'
    LinuxTargets = @(
        @{ DistributionVariable = 'WSL_DISTRIBUTION'; UserVariable = 'WSL_USER' }
    )
    PermissionDistributionVariable = 'WSL_DISTRIBUTION'
    PermissionUserVariable = 'WSL_USER'
    ExcludedDistributionVariables = @('WSL_MALWARE_DISTRIBUTION', 'WSL_NIXOS_DISTRIBUTION', 'WSL_AI_DISTRIBUTION')
}
