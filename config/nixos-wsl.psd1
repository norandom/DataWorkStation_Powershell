@{
    ReleaseTag = '2605.7.2'
    AssetSha256 = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    AssetSizeBytes = 577813513
    DistributionVariable = 'WSL_NIXOS_DISTRIBUTION'
    UserVariable = 'WSL_NIXOS_USER'
    InstallLocation = '%LOCALAPPDATA%\WSL\NixOS'
    FlakeTarget = 'workstation'
    RequiredCommands = @('helm', 'kubectl', 'pulumi', 'ssh', 'workstation-self-check')
    SourceFiles = @('flake.nix', 'flake.lock', 'configuration.nix', 'self-check.nix')
}
