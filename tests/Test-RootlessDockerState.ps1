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

$configurationPath = Join-Path $repositoryRoot 'config\rootless-docker.psd1'
$statePath = Join-Path $repositoryRoot 'scripts\Set-RootlessDockerState.ps1'
$deployPath = Join-Path $repositoryRoot 'linux\rootless_docker.py'
Assert-True (Test-Path -LiteralPath $configurationPath) 'rootless Docker configuration exists'
Assert-True (Test-Path -LiteralPath $statePath) 'rootless Docker state resource exists'
Assert-True (Test-Path -LiteralPath $deployPath) 'Debian-local pyinfra deploy exists'

$configuration = Import-PowerShellDataFile $configurationPath
foreach ($package in @('uidmap', 'dbus-user-session', 'slirp4netns', 'docker-ce', 'docker-ce-rootless-extras')) {
    Assert-True ($configuration.RequiredPackages -contains $package) "$package is declared"
}

$deploy = Get-Content -LiteralPath $deployPath -Raw
Assert-True ($deploy -match 'systemctl disable --now docker\.service docker\.socket') 'rootful service and socket are disabled'
Assert-True ($deploy -match 'dockerd-rootless-setuptool\.sh install') 'official rootless setup tool is used'
Assert-True ($deploy -match 'loginctl enable-linger') 'the user service can start with WSL'
Assert-True ($deploy -match 'systemctl --user enable --now docker\.service') 'rootless user service is enabled and started'

$catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
$rootlessModule = @($catalog.Modules | Where-Object Name -eq 'RootlessDocker')
$developerDockerModule = @($catalog.Modules | Where-Object Name -eq 'DeveloperDocker')
$developerModule = @($catalog.Modules | Where-Object Name -eq 'DeveloperTools')
Assert-True ($rootlessModule.Count -eq 1) 'RootlessDocker module exists once'
Assert-True ($rootlessModule[0].Default) 'the dedicated malware container distro is maintained by default'
Assert-True ($rootlessModule[0].DependsOn.Count -eq 0) 'the dedicated distro bootstraps its own local pyinfra'
Assert-True ($developerDockerModule[0].DependsOn -contains 'LinuxAutomation') 'developer Docker remains on the existing pyinfra-managed Debian distro'
Assert-True ($developerModule[0].DependsOn -contains 'DeveloperDocker') 'Dagger depends on the separate developer Docker daemon'
$sampleEnvironment = Get-Content (Join-Path $repositoryRoot '.wsl-env.sample') -Raw
Assert-True ($sampleEnvironment -match 'WSL_MALWARE_DISTRIBUTION=Debian-MW') 'the dedicated distro selector is documented'
$stateScript = Get-Content (Join-Path $repositoryRoot 'scripts\Set-RootlessDockerState.ps1') -Raw
Assert-True ($stateScript -match 'wsl\.exe --install.*--name \$distribution.*--no-launch') 'a clean named Debian distro is installed'
Assert-True ($stateScript -notmatch 'wsl\.exe --export|wsl\.exe --import') 'the developer distro is never cloned'
$aliases = Get-Content (Join-Path $repositoryRoot 'profile\Aliases.ps1') -Raw
Assert-True ($aliases -match 'global:docker-mw') 'the rootless distro has an explicit human command'

Write-Host "Rootless Docker state tests passed ($script:assertions assertions)."
