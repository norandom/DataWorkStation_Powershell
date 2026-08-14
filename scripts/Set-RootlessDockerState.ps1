[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$null = $Json # consumed by the nested human/JSON renderer
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\rootless-docker.psd1')
$distribution = $wslEnvironment.WSL_MALWARE_DISTRIBUTION
$linuxUser = $wslEnvironment.WSL_MALWARE_USER
if ($distribution -notmatch '^[A-Za-z0-9._-]+$' -or $linuxUser -notmatch '^[a-z_][a-z0-9_-]*$') {
    throw 'The malware WSL distribution or user selector contains unsupported characters.'
}

function Test-DistributionInstalled {
    $names = @(& wsl.exe --list --quiet) | ForEach-Object { (([string] $_) -replace "`0", '').Trim() }
    $names -contains $distribution
}

function Invoke-WslUserShell {
    param([string] $Command)
    @(& wsl.exe -d $distribution --user $linuxUser -- sh -lc $Command 2>&1) -join "`n"
}

function Get-RootlessDockerState {
    if (-not (Test-DistributionInstalled)) {
        return [pscustomobject]@{
            Status = 'drift-detected'
            Distribution = $distribution
            User = $linuxUser
            Uid = $null
            Context = $null
            DockerRootDir = $null
            SecurityOptions = @()
            Packages = @()
            Checks = [pscustomobject] [ordered]@{ DistributionInstalled = $false }
        }
    }
    $uid = (Invoke-WslUserShell 'id -u').Trim()
    $packageRows = foreach ($package in @($configuration.RequiredPackages)) {
        $installed = Invoke-WslUserShell "dpkg-query -W '$package' >/dev/null 2>&1 && printf installed || true"
        [pscustomobject]@{ Name = $package; Installed = ($installed.Trim() -eq 'installed') }
    }
    $rootfulActive = (Invoke-WslUserShell 'systemctl is-active docker.service docker.socket 2>/dev/null || true') -split "`n" | Where-Object { $_ -eq 'active' }
    $rootfulEnabled = (Invoke-WslUserShell 'systemctl is-enabled docker.service docker.socket 2>/dev/null || true') -split "`n" | Where-Object { $_ -in @('enabled', 'static', 'indirect') }
    $userServiceActive = (Invoke-WslUserShell 'systemctl --user is-active docker.service 2>/dev/null || true').Trim() -eq 'active'
    $userServiceEnabled = (Invoke-WslUserShell 'systemctl --user is-enabled docker.service 2>/dev/null || true').Trim() -eq 'enabled'
    $lingerEnabled = (Invoke-WslUserShell "loginctl show-user '$linuxUser' -p Linger --value 2>/dev/null || true").Trim() -eq 'yes'
    $dockerInfoText = Invoke-WslUserShell "DOCKER_HOST=unix:///run/user/$uid/docker.sock docker info --format '{{json .}}' 2>/dev/null || true"
    $dockerInfo = $null
    try { if ($dockerInfoText.Trim().StartsWith('{')) { $dockerInfo = $dockerInfoText | ConvertFrom-Json } } catch {
        Write-Verbose 'Rootless Docker info did not match the expected JSON shape.'
    }
    $securityOptions = if ($dockerInfo) { @($dockerInfo.SecurityOptions) } else { @() }
    $rootless = [bool] ($securityOptions | Where-Object { [string] $_ -eq $configuration.RootlessSecurityOption })
    $context = (Invoke-WslUserShell 'docker context show 2>/dev/null || true').Trim()
    $keyHash = (Invoke-WslUserShell "sha256sum /etc/apt/keyrings/docker.asc 2>/dev/null | cut -d' ' -f1").Trim()
    $repositoryDeclared = (Invoke-WslUserShell "grep -q 'https://download.docker.com/linux/debian' /etc/apt/sources.list.d/docker.sources 2>/dev/null && printf declared || true").Trim() -eq 'declared'
    $pyinfraVersion = (Invoke-WslUserShell "'$($configuration.Pyinfra)' --version 2>/dev/null || true").Trim()
    $checks = [ordered]@{
        DistributionInstalled = $true
        PyinfraPinned = ($pyinfraVersion -match "v$([regex]::Escape($configuration.PyinfraVersion))(?:\s|$)")
        RepositoryKeyPinned = ($keyHash -eq $configuration.DockerGpgSha256)
        RepositoryDeclared = $repositoryDeclared
        Packages = -not ($packageRows.Installed -contains $false)
        RootfulServicesDisabled = ($rootfulActive.Count -eq 0 -and $rootfulEnabled.Count -eq 0)
        UserServiceEnabled = $userServiceEnabled
        UserServiceActive = $userServiceActive
        LingerEnabled = $lingerEnabled
        RootlessEngine = $rootless
        RootlessContext = ($context -eq 'rootless')
    }
    [pscustomobject]@{
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        Distribution = $distribution
        User = $linuxUser
        Uid = $uid
        Context = $context
        DockerRootDir = if ($dockerInfo) { $dockerInfo.DockerRootDir } else { $null }
        SecurityOptions = $securityOptions
        Packages = @($packageRows)
        Checks = [pscustomobject] $checks
    }
}

function Write-State {
    param([object] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 8; return }
    Write-Host "RootlessDocker: $($State.Status) ($($State.User)@$($State.Distribution))"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    if ($State.DockerRootDir) { Write-Host "  Docker root: $($State.DockerRootDir)" }
}

$before = Get-RootlessDockerState
if ($Mode -eq 'Test') {
    Write-State $before
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if ($before.Status -ne 'compliant' -or $Mode -eq 'Reinitialize') {
    if (-not (Test-DistributionInstalled)) {
        Write-Host "Installing a clean $($configuration.BaseDistribution) WSL distribution as '$distribution' without launching an interactive OOBE."
        & wsl.exe --install $configuration.BaseDistribution --name $distribution --no-launch
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'The WSL Store-backed download failed; retrying through the documented --web-download path.'
            & wsl.exe --install $configuration.BaseDistribution --name $distribution --no-launch --web-download
        }
        if ($LASTEXITCODE -ne 0) { throw "WSL failed to install $distribution through both download paths: $LASTEXITCODE" }
        & wsl.exe -d $distribution --user root -- sh -lc "id -u '$linuxUser' >/dev/null 2>&1 || useradd --create-home --shell /bin/bash '$linuxUser'"
        if ($LASTEXITCODE -ne 0) { throw "Failed to create $linuxUser in $distribution." }
        & wsl.exe --manage $distribution --set-default-user $linuxUser
        if ($LASTEXITCODE -ne 0) { throw "Failed to set the default user for $distribution." }
    }

    Write-Host "Bootstrapping pinned pyinfra inside the dedicated $distribution distro."
    & wsl.exe -d $distribution --user root -- sh -lc "DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl python3 python3-venv && (test -x '$($configuration.Pip)' || python3 -m venv /opt/dataworkstation/pyinfra) && ('$($configuration.Pyinfra)' --version 2>/dev/null | grep -q 'v$($configuration.PyinfraVersion)' || '$($configuration.Pip)' install --disable-pip-version-check --no-compile --force-reinstall 'pyinfra==$($configuration.PyinfraVersion)')"
    if ($LASTEXITCODE -ne 0) { throw "Failed to bootstrap pyinfra in $distribution." }

    $pyinfra = $configuration.Pyinfra
    $deployWindows = Join-Path $repositoryRoot $configuration.Deploy
    $deployPortable = [IO.Path]::GetFullPath($deployWindows).Replace('\', '/')
    $deploy = (& wsl.exe -d $distribution --user $linuxUser -- wslpath -a $deployPortable).Trim()
    if (-not $deploy) { throw 'Failed to resolve the rootless Docker pyinfra deploy inside WSL.' }
    $path = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    $reinitialize = if ($Mode -eq 'Reinitialize') { '1' } else { '0' }
    & wsl.exe -d $distribution --user root -- env "PATH=$path" "ROOTLESS_DOCKER_USER=$linuxUser" `
        "ROOTLESS_DOCKER_REINITIALIZE=$reinitialize" $pyinfra '@local' $deploy '-y'
    if ($LASTEXITCODE -ne 0) { throw "pyinfra failed to apply rootless Docker state: $LASTEXITCODE" }
}

$after = Get-RootlessDockerState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'Rootless Docker did not reach the declared state.' }
