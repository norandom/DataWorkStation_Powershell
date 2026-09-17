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
$networkMtu = [int] $configuration.NetworkMtu
if ($networkMtu -lt 1280 -or $networkMtu -gt 65535) { throw 'NetworkMtu must be between 1280 and 65535.' }

function Invoke-DeveloperShell {
    param([string] $Command)
    @(& wsl.exe -d $distribution --user $linuxUser -- sh -lc $Command 2>&1) -join "`n"
}

function Get-DeveloperDockerState {
    $packages = foreach ($package in @($configuration.RequiredPackages)) {
        $state = Invoke-DeveloperShell "dpkg-query -W '$package' >/dev/null 2>&1 && printf installed || true"
        [pscustomobject]@{ Name = $package; Installed = ($state.Trim() -eq 'installed') }
    }
    $infoText = Invoke-DeveloperShell "docker --host unix:///var/run/docker.sock info --format '{{json .}}' 2>/dev/null || true"
    $info = $null
    try { if ($infoText.Trim().StartsWith('{')) { $info = $infoText | ConvertFrom-Json } } catch {
        Write-Verbose 'Developer Docker info did not match the expected JSON shape.'
    }
    $securityOptions = if ($info) { @($info.SecurityOptions) } else { @() }
    $rootless = [bool] ($securityOptions | Where-Object { [string] $_ -eq 'name=rootless' })
    $keyHash = (Invoke-DeveloperShell "sha256sum /etc/apt/keyrings/docker.asc 2>/dev/null | cut -d' ' -f1").Trim()
    $repositoryDeclared = (Invoke-DeveloperShell "grep -q 'https://download.docker.com/linux/debian' /etc/apt/sources.list.d/docker.sources 2>/dev/null && printf declared || true").Trim() -eq 'declared'
    # The daemon config may contain secrets and be root-readable only. Render only MTU fields.
    $daemonText = @(& wsl.exe -d $distribution --user root -- sh -c 'if test -e /etc/docker/daemon.json; then cat /etc/docker/daemon.json; else printf "{}"; fi' 2>$null) -join "`n"
    $daemon = $null
    try { $daemon = $daemonText | ConvertFrom-Json -ErrorAction Stop } catch { Write-Verbose 'Docker daemon.json is unreadable or invalid.' }
    $uplinkMtu = (Invoke-DeveloperShell 'cat /sys/class/net/eth0/mtu 2>/dev/null || true').Trim()
    $networkText = Invoke-DeveloperShell 'docker --host unix:///var/run/docker.sock network ls --filter driver=bridge -q | xargs -r docker --host unix:///var/run/docker.sock network inspect'
    $networks = @()
    try { $networks = @($networkText | ConvertFrom-Json -ErrorAction Stop) } catch { Write-Verbose 'Docker bridge inventory is unavailable.' }
    $bridges = @($networks | ForEach-Object {
        $mtu = $_.Options.'com.docker.network.driver.mtu'
        [pscustomobject]@{
            Name = $_.Name
            Mtu = if ($mtu) { [int] $mtu } else { 1500 }
            Containers = @($_.Containers.PSObject.Properties | ForEach-Object { $_.Value.Name })
        }
    })
    $defaultBridge = @($bridges | Where-Object Name -eq 'bridge')
    $oversizedBridges = @($bridges | Where-Object Mtu -gt $networkMtu)
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
        DaemonMtu = ($null -ne $daemon -and $daemon.mtu -eq $networkMtu)
        NewBridgeMtu = ($null -ne $daemon -and $daemon.'default-network-opts'.bridge.'com.docker.network.driver.mtu' -eq [string] $networkMtu)
        MtuFitsUplink = ($uplinkMtu -match '^\d+$' -and $networkMtu -le [int] $uplinkMtu)
        DefaultBridgeMtu = ($defaultBridge.Count -eq 1 -and $defaultBridge[0].Mtu -eq $networkMtu)
        ExistingBridgeMtu = ($bridges.Count -gt 0 -and $oversizedBridges.Count -eq 0)
    }
    [pscustomobject]@{
        Status = if ($checks.Values -contains $false) { 'drift-detected' } else { 'compliant' }
        Distribution = $distribution
        User = $linuxUser
        DockerRootDir = if ($info) { $info.DockerRootDir } else { $null }
        SecurityOptions = $securityOptions
        Packages = @($packages)
        NetworkMtu = $networkMtu
        UplinkMtu = $uplinkMtu
        DaemonMtu = $daemon.mtu
        NewBridgeMtu = $daemon.'default-network-opts'.bridge.'com.docker.network.driver.mtu'
        BridgeNetworks = $bridges
        NetworksRequiringRecreation = @($oversizedBridges | Where-Object Name -ne 'bridge' | ForEach-Object Name)
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
    Write-Host "  MTU: declared=$($State.NetworkMtu), eth0=$($State.UplinkMtu), daemon=$($State.DaemonMtu), new bridges=$($State.NewBridgeMtu)"
    foreach ($bridge in $State.BridgeNetworks) { Write-Host "  Bridge $($bridge.Name): MTU $($bridge.Mtu) [$($bridge.Containers -join ', ')]" }
    if ($State.NetworksRequiringRecreation.Count -gt 0) {
        Write-Host "  Recreate these custom networks during planned downtime: $($State.NetworksRequiringRecreation -join ', ')"
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
    if (-not $before.Checks.MtuFitsUplink) { throw 'The declared Docker MTU exceeds eth0 MTU or eth0 could not be inspected.' }
    $deployWindows = Join-Path $repositoryRoot $configuration.Deploy
    $deployPortable = [IO.Path]::GetFullPath($deployWindows).Replace('\', '/')
    $deploy = (& wsl.exe -d $distribution --user $linuxUser -- wslpath -a $deployPortable).Trim()
    $pyinfra = "/home/$linuxUser/.local/bin/pyinfra"
    $path = "/home/linuxbrew/.linuxbrew/bin:/home/$linuxUser/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    $reinitialize = if ($Mode -eq 'Reinitialize' -or -not $before.Checks.DefaultBridgeMtu) { '1' } else { '0' }
    Write-Host 'Applying developer Docker state as WSL root. Changed MTU settings restart Docker and can interrupt running containers; existing custom networks are retained.'
    & wsl.exe -d $distribution --user root -- env "PATH=$path" "DEVELOPER_DOCKER_USER=$linuxUser" `
        "DEVELOPER_DOCKER_REINITIALIZE=$reinitialize" "DEVELOPER_DOCKER_MTU=$networkMtu" $pyinfra '@local' $deploy '-y'
    if ($LASTEXITCODE -ne 0) { throw "pyinfra failed to apply developer Docker state: $LASTEXITCODE" }
}

$after = Get-DeveloperDockerState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'Developer Docker did not reach the declared state. Inspect the failed checks; existing custom networks require explicit recreation by their owning project.' }
