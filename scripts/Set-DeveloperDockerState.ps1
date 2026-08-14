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
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\developer-docker.psd1')
$distribution = $wslEnvironment.WSL_DISTRIBUTION
$linuxUser = $wslEnvironment.WSL_USER

function Invoke-DeveloperShell {
    param([string] $Command)
    @(& wsl.exe -d $distribution --user $linuxUser -- sh -lc $Command 2>&1) -join "`n"
}

function Get-DeveloperDockerState {
    $packages = foreach ($package in @($configuration.RequiredPackages)) {
        $state = Invoke-DeveloperShell "dpkg-query -W '$package' >/dev/null 2>&1 && printf installed || true"
        [pscustomobject]@{ Name = $package; Installed = ($state.Trim() -eq 'installed') }
    }
    $infoText = Invoke-DeveloperShell "docker info --format '{{json .}}' 2>/dev/null || true"
    $info = $null
    try { if ($infoText.Trim().StartsWith('{')) { $info = $infoText | ConvertFrom-Json } } catch {
        Write-Verbose 'Developer Docker info did not match the expected JSON shape.'
    }
    $securityOptions = if ($info) { @($info.SecurityOptions) } else { @() }
    $rootless = [bool] ($securityOptions | Where-Object { [string] $_ -eq 'name=rootless' })
    $keyHash = (Invoke-DeveloperShell "sha256sum /etc/apt/keyrings/docker.asc 2>/dev/null | cut -d' ' -f1").Trim()
    $repositoryDeclared = (Invoke-DeveloperShell "grep -q 'https://download.docker.com/linux/debian' /etc/apt/sources.list.d/docker.sources 2>/dev/null && printf declared || true").Trim() -eq 'declared'
    $checks = [ordered]@{
        ManagedByPyinfra = (Invoke-DeveloperShell 'test -f /var/lib/dataworkstation/developer-docker.managed && printf managed || true').Trim() -eq 'managed'
        RepositoryKeyPinned = ($keyHash -eq $configuration.DockerGpgSha256)
        RepositoryDeclared = $repositoryDeclared
        Packages = -not ($packages.Installed -contains $false)
        ServiceActive = (Invoke-DeveloperShell 'systemctl is-active docker.service').Trim() -eq 'active'
        ServiceEnabled = (Invoke-DeveloperShell 'systemctl is-enabled docker.service').Trim() -eq 'enabled'
        SocketActive = (Invoke-DeveloperShell 'systemctl is-active docker.socket').Trim() -eq 'active'
        UserInDockerGroup = ((Invoke-DeveloperShell "id -nG '$linuxUser'") -split '\s+') -contains 'docker'
        RootfulForDagger = ($null -ne $info -and -not $rootless)
    }
    [pscustomobject]@{
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        Distribution = $distribution
        User = $linuxUser
        DockerRootDir = if ($info) { $info.DockerRootDir } else { $null }
        SecurityOptions = $securityOptions
        Packages = @($packages)
        Checks = [pscustomobject] $checks
        Boundary = 'This rootful daemon is reserved for developer tools such as Dagger, never suspicious-file analysis.'
    }
}

function Write-State {
    param([object] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 8; return }
    Write-Host "DeveloperDocker: $($State.Status) ($($State.User)@$($State.Distribution))"
    $State.Checks.PSObject.Properties | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    Write-Host "  Boundary: $($State.Boundary)"
}

$before = Get-DeveloperDockerState
if ($Mode -eq 'Test') {
    Write-State $before
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if ($before.Status -ne 'compliant' -or $Mode -eq 'Reinitialize') {
    $deployWindows = Join-Path $repositoryRoot $configuration.Deploy
    $deployPortable = [IO.Path]::GetFullPath($deployWindows).Replace('\', '/')
    $deploy = (& wsl.exe -d $distribution --user $linuxUser -- wslpath -a $deployPortable).Trim()
    $pyinfra = "/home/$linuxUser/.local/bin/pyinfra"
    $path = "/home/linuxbrew/.linuxbrew/bin:/home/$linuxUser/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    $reinitialize = if ($Mode -eq 'Reinitialize') { '1' } else { '0' }
    & wsl.exe -d $distribution --user root -- env "PATH=$path" "DEVELOPER_DOCKER_USER=$linuxUser" `
        "DEVELOPER_DOCKER_REINITIALIZE=$reinitialize" $pyinfra '@local' $deploy '-y'
    if ($LASTEXITCODE -ne 0) { throw "pyinfra failed to apply developer Docker state: $LASTEXITCODE" }
}

$after = Get-DeveloperDockerState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'Developer Docker did not reach the declared state.' }
