@{
    SchemaVersion = 1
    ReleaseTag = '2605.7.2'
    AssetSha256 = 'e7180ad555fdcb8e1e057e2ef056de467603a5e502ff8531053738371be3f6b9'
    AssetSizeBytes = 577813513
    DistributionVariable = 'WSL_AI_DISTRIBUTION'
    DailyUserVariable = 'WSL_AI_USER'
    PlanDistribution = 'NixOS-AI'
    PlanDailyUser = 'ai'
    MaintenanceUser = 'ai-maint'
    InstallLocation = '%LOCALAPPDATA%\WSL\NixOS-AI'
    FlakeTarget = 'ai-workstation'
    RequiredCommands = @('opencode', 'nono', 'ai-workstation-self-check')
    SourceFiles = @('flake.nix', 'flake.lock', 'configuration.nix', 'self-check.nix', 'opencode-profile.json')
    OpenCode = @{
        Version = '1.18.18'
        Uri = 'https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz'
        Sha256 = '0cddc222418b8553669905a8980c0cda7088f00da24d83d6ac76b01c9fdb2aaf'
        InstallPath = '/run/current-system/sw/bin/opencode'
    }
    Nono = @{
        InstallCommand = 'brew install nono'
        OwnerUser = 'ai-maint'
        MinimumVersion = '0.55.0'
        ExpectedVersion = '0.73.0'
        Profile = '/etc/nono/opencode-profile.json'
        ProfileSha256 = '0112cf5b52dfbf954f1dd84856852043919d9466ca108afe5bfb0735f5402495'
        UpstreamProfile = 'nolabs-ai/opencode'
        BrewPrefix = '/home/linuxbrew/.linuxbrew'
    }
}
