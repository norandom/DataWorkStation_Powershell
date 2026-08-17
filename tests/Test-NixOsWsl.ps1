[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

$nixConfiguration = Get-Content -LiteralPath (Join-Path $repositoryRoot 'nixos\configuration.nix') -Raw
$selfCheck = Get-Content -LiteralPath (Join-Path $repositoryRoot 'nixos\self-check.nix') -Raw
$flake = Get-Content -LiteralPath (Join-Path $repositoryRoot 'nixos\flake.nix') -Raw
$lock = Get-Content -LiteralPath (Join-Path $repositoryRoot 'nixos\flake.lock') -Raw | ConvertFrom-Json
$resource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-NixOsWslState.ps1') -Raw
$sshResource = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Set-SharedSshConfigState.ps1') -Raw
$aliases = Get-Content -LiteralPath (Join-Path $repositoryRoot 'profile\Aliases.ps1') -Raw
$nixSettings = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\nixos-wsl.psd1')
$sshSettings = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\shared-ssh.psd1')
$moduleCatalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')

Assert-True ($nixSettings.AssetUrl -match [regex]::Escape($nixSettings.ReleaseTag)) 'the NixOS-WSL download is release-pinned'
Assert-True ($nixSettings.AssetSha256 -match '^[a-f0-9]{64}$') 'the NixOS-WSL asset has a SHA-256 pin'
Assert-True ($nixSettings.AssetSizeBytes -gt 500MB) 'the operator plan declares the substantial download size'
Assert-True ($flake -match 'nixos-26\.05') 'the flake selects a stable Nixpkgs branch'
Assert-True ($flake -match 'nixpkgs-unstable') 'the flake separately locks the current Pulumi CLI source'
Assert-True ($flake -match [regex]::Escape("nix-community/NixOS-WSL/$($nixSettings.ReleaseTag)")) 'the flake pins the selected NixOS-WSL release'
Assert-True ($lock.nodes.root.inputs.nixpkgs -and $lock.nodes.root.inputs.'nixos-wsl') 'flake.lock records both upstream inputs'
Assert-True ($lock.nodes.root.inputs.'nixpkgs-unstable' -and $lock.nodes.'nixpkgs-unstable'.locked.rev) 'flake.lock records the separate Pulumi package input'

foreach ($package in @('kubernetes-helm', 'kubectl', 'openssh')) {
    Assert-True ($nixConfiguration -match "(?m)^\s+$([regex]::Escape($package))\s*$") "the system closure contains $package"
}
Assert-True ($nixConfiguration -match 'pkgsUnstable\.pulumi') 'Pulumi comes from the separately locked current CLI package set'
Assert-True ($nixConfiguration -notmatch '\bpulumi-bin\b') 'the system closure does not bundle Pulumi providers'
Assert-True ($selfCheck -match 'nix store verify --all --no-trust') 'the self-check verifies every local Nix store path by content'
Assert-True ($selfCheck -match 'sha256sum --check --status') 'the self-check verifies deployed mutable Nix sources'
Assert-True ($selfCheck -match 'nix eval --raw') 'the self-check evaluates the declared generation without building it'
Assert-True ($selfCheck -notmatch 'nix build') 'the read-only self-check never starts a build'
Assert-True ($selfCheck -match 'status=altered') 'integrity failures have a distinct altered state'
foreach ($command in @($nixSettings.RequiredCommands)) {
    Assert-True ($selfCheck -match [regex]::Escape($command)) "the self-check validates the managed command $command"
}

Assert-True ($resource -match 'Refusing to replace or unregister it') 'the resource refuses to replace an unexpected distribution'
Assert-True ($resource -notmatch 'wsl\.exe\s+--unregister') 'the resource never unregisters a distribution'
Assert-True ($resource -match "(?s)Mode -eq 'Ensure'.*Get-LiveState") 'Ensure has a compliance short-circuit'
Assert-True ($resource -match 'Get-FileHash.*SHA256') 'the release asset is verified before use'

$nixModule = @($moduleCatalog.Modules | Where-Object Name -eq 'NixOsWsl')[0]
$sshModule = @($moduleCatalog.Modules | Where-Object Name -eq 'SharedSshConfig')[0]
Assert-True ($nixModule.DependsOn -contains 'Packages') 'NixOS WSL follows the package bootstrap stage'
Assert-True ($sshModule.DependsOn -contains 'NixOsWsl') 'shared SSH remains ordered after the DevOps WSL bootstrap'
Assert-True ($nixModule.Default -and $sshModule.Default) 'both trusted developer environment resources are in default desired state'

Assert-True ($sshSettings.LinuxTargets.Count -eq 1) 'only trusted Debian receives the canonical SSH config'
Assert-True (@($sshSettings.LinuxTargets)[0].DistributionVariable -eq 'WSL_DISTRIBUTION') 'the shared target is ordinary Debian'
foreach ($restricted in @('WSL_MALWARE_DISTRIBUTION', 'WSL_NIXOS_DISTRIBUTION', 'WSL_AI_DISTRIBUTION')) {
    Assert-True ($sshSettings.ExcludedDistributionVariables -contains $restricted) "$restricted is explicitly excluded from shared SSH state"
}
Assert-True ($sshResource -match 'chmod 0600') 'the resource gives the shared config an OpenSSH-compatible DrvFS mode'
Assert-True ($sshResource -match 'Refusing to replace the existing regular') 'an existing Linux SSH config is never overwritten'
Assert-True ($sshResource -match 'WindowsSshRemainsDefault = \$true') 'the plan states that Windows OpenSSH remains the host default'
Assert-True ($aliases -match 'function global:wsl-nix') 'NixOS has an explicit boundary command'
Assert-True ($aliases -match "Get-Command pwsh\.exe.*Select-Object -First 1") 'the self-check wrapper resolves one PowerShell application when aliases coexist'
Assert-True ($aliases -notmatch 'Set-Alias\s+ssh') 'the profile does not replace the host SSH command'

Write-Host "NixOS WSL contract tests passed ($script:assertions assertions)."
