[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$selection = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\rootless-podman.psd1')
$distribution = [string] $selection.WSL_MALWARE_DISTRIBUTION
$linuxUser = [string] $selection.WSL_MALWARE_USER
$developerDistribution = [string] $selection.WSL_DISTRIBUTION

if ($distribution -notmatch '^[A-Za-z0-9._-]+$' -or $linuxUser -notmatch '^[a-z_][a-z0-9_-]*$') {
    throw 'The malware WSL distribution or user selector contains unsupported characters.'
}

function Test-DistributionInstalled {
    $names = @(& wsl.exe --list --quiet) | ForEach-Object { (([string] $_) -replace "`0", '').Trim() }
    $names -contains $distribution
}

function Invoke-MalwareUserShell {
    param([Parameter(Mandatory = $true)][string] $Command)
    @(& wsl.exe -d $distribution --user $linuxUser --exec sh -lc $Command 2>&1) -join "`n"
}

function Invoke-MalwareUserCommand {
    param([Parameter(Mandatory = $true)][string[]] $ArgumentList)
    $output = @(& wsl.exe -d $distribution --user $linuxUser --exec @ArgumentList 2>&1)
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Text = ($output -join "`n").Trim()
    }
}

function Send-BytesToMalwareGuest {
    param(
        [Parameter(Mandatory = $true)][byte[]] $Bytes,
        [Parameter(Mandatory = $true)][string] $Destination,
        [string] $Mode = '0644'
    )
    $base64 = [Convert]::ToBase64String($Bytes)
    $base64 | & wsl.exe -d $distribution --user root --exec sh -c "umask 022; base64 --decode > '$Destination' && chmod '$Mode' '$Destination'"
    if ($LASTEXITCODE -ne 0) { throw "Failed to stream '$Destination' into '$distribution' through StandardInput." }
}

function Get-PackageRows {
    param([string[]] $Names)
    foreach ($package in $Names) {
        $status = Invoke-MalwareUserCommand -ArgumentList @('dpkg-query', '-W', '-f=${db:Status-Abbrev}', $package)
        [pscustomobject]@{ Name = $package; Installed = ($status.ExitCode -eq 0 -and $status.Text -match '^ii') }
    }
}

function Get-PathRecord {
    param([string] $LinuxHome, [string] $RelativePath)
    $path = "$LinuxHome/$RelativePath"
    $exists = Invoke-MalwareUserCommand -ArgumentList @('test', '-e', $path)
    $link = Invoke-MalwareUserCommand -ArgumentList @('test', '-L', $path)
    $present = ($exists.ExitCode -eq 0 -or $link.ExitCode -eq 0)
    $resolved = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('readlink', '-f', '--', $path)).Text } else { $null }
    $owner = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('stat', '-c', '%U', '--', $path)).Text } else { $null }
    $sizeText = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('du', '-sb', '--', $path)).Text } else { $null }
    $bytes = if ($sizeText -match '^(\d+)') { [int64] $Matches[1] } else { $null }
    [pscustomobject]@{
        Path = $path
        Exists = $present
        ResolvedPath = $resolved
        Owner = $owner
        Bytes = $bytes
    }
}

function Get-RootlessPodmanState {
    if (-not (Test-DistributionInstalled)) {
        return [pscustomobject]@{
            SchemaVersion = 1
            Status = 'drift-detected'
            MigrationPhase = 'distribution-absent'
            Distribution = $distribution
            User = $linuxUser
            Uid = $null
            PodmanVersion = $null
            PodmanStorageRoot = $null
            LegacyDockerData = @()
            PendingChanges = @('Install the dedicated distribution', 'Provision rootless Podman', 'Retire rootless Docker')
            MigrationImpact = 'Privileged networked WSL package and service changes; legacy Docker data retained.'
            Checks = [pscustomobject] [ordered]@{ DistributionInstalled = $false }
        }
    }

    $uid = (Invoke-MalwareUserShell 'id -u').Trim()
    $linuxHome = (Invoke-MalwareUserShell "getent passwd '$linuxUser' | cut -d: -f6").Trim()
    $podmanPackages = @(Get-PackageRows -Names @($configuration.RequiredPackages))
    $dockerPackages = @(Get-PackageRows -Names @($configuration.LegacyDockerPackages))
    $podmanCommand = (Invoke-MalwareUserShell 'command -v podman 2>/dev/null || true').Trim()
    $dockerCommand = (Invoke-MalwareUserShell 'command -v docker 2>/dev/null || true').Trim()
    $subuid = (Invoke-MalwareUserShell "grep -E '^${linuxUser}:[0-9]+:[1-9][0-9]*$' /etc/subuid 2>/dev/null || true").Trim()
    $subgid = (Invoke-MalwareUserShell "grep -E '^${linuxUser}:[0-9]+:[1-9][0-9]*$' /etc/subgid 2>/dev/null || true").Trim()
    $storagePath = "$linuxHome/$($configuration.PodmanStorageRelativePath)"
    $storageInitialized = (Invoke-MalwareUserShell "test -d '$storagePath' && printf initialized || true").Trim() -eq 'initialized'
    $podmanInfo = $null
    $podmanInfoText = $null
    if ($podmanCommand -and $storageInitialized) {
        $podmanInfoText = Invoke-MalwareUserShell 'podman info --format json 2>/dev/null || true'
        try { if ($podmanInfoText.Trim().StartsWith('{')) { $podmanInfo = $podmanInfoText | ConvertFrom-Json -ErrorAction Stop } } catch {
            Write-Verbose 'Podman info did not match the expected bounded JSON shape.'
        }
    }
    $podmanVersion = if ($podmanInfo) { [string] $podmanInfo.Version.Version } else { $null }
    $rootless = [bool] ($podmanInfo -and $podmanInfo.Host.Security.Rootless)
    $serviceIsRemote = [bool] ($podmanInfo -and $podmanInfo.Host.ServiceIsRemote)
    $graphRoot = if ($podmanInfo) { [string] $podmanInfo.Store.GraphRoot } else { $null }
    $graphDriverName = if ($podmanInfo) { [string] $podmanInfo.Store.GraphDriverName } else { $null }
    $seccompEnabled = [bool] ($podmanInfo -and $podmanInfo.Host.Security.SeccompEnabled)
    $podmanUnitActive = (Invoke-MalwareUserShell 'systemctl --user is-active podman.socket podman.service 2>/dev/null || true') -split "`n" | Where-Object { $_ -eq 'active' }
    $podmanUnitEnabled = (Invoke-MalwareUserShell 'systemctl --user is-enabled podman.socket podman.service 2>/dev/null || true') -split "`n" | Where-Object { $_ -in @('enabled', 'static', 'indirect') }
    $dockerUserActive = (Invoke-MalwareUserShell 'systemctl --user is-active docker.service 2>/dev/null || true').Trim() -eq 'active'
    $dockerUserEnabled = (Invoke-MalwareUserShell 'systemctl --user is-enabled docker.service 2>/dev/null || true').Trim() -eq 'enabled'
    $dockerRootActive = (Invoke-MalwareUserShell 'systemctl is-active docker.service docker.socket 2>/dev/null || true') -split "`n" | Where-Object { $_ -eq 'active' }
    $dockerRootEnabled = (Invoke-MalwareUserShell 'systemctl is-enabled docker.service docker.socket 2>/dev/null || true') -split "`n" | Where-Object { $_ -in @('enabled', 'static', 'indirect') }
    $dockerRepository = (Invoke-MalwareUserShell 'test -e /etc/apt/sources.list.d/docker.sources -o -e /etc/apt/sources.list.d/docker.list -o -e /etc/apt/keyrings/docker.asc && printf present || true').Trim() -eq 'present'
    $dockerDesktopIntegrated = $dockerCommand -match '(?i)docker-desktop|/mnt/wsl/'
    $wslConf = Invoke-MalwareUserShell 'cat /etc/wsl.conf 2>/dev/null || true'
    $interopDisabled = $wslConf -match '(?ims)^\s*\[interop\].*?^\s*enabled\s*=\s*false\s*$' -and
        $wslConf -match '(?ims)^\s*\[interop\].*?^\s*appendWindowsPath\s*=\s*false\s*$'
    $automountDisabled = $wslConf -match '(?ims)^\s*\[automount\].*?^\s*enabled\s*=\s*false\s*$'
    $groups = (Invoke-MalwareUserShell 'id -nG').Trim() -split '\s+'
    $withoutSudo = @($groups | Where-Object { $_ -in @('sudo', 'wheel', 'admin') }).Count -eq 0
    $legacyData = @($configuration.LegacyDockerDataPaths | ForEach-Object { Get-PathRecord -LinuxHome $linuxHome -RelativePath $_ })
    $checks = [ordered]@{
        DistributionInstalled = $true
        DedicatedBoundary = ($distribution -eq [string] $configuration.RequiredDistribution -and $distribution -ne $developerDistribution)
        NonRootUser = ($uid -match '^\d+$' -and $uid -ne '0')
        PodmanPackages = -not ($podmanPackages.Installed -contains $false)
        SubordinateIds = (-not [string]::IsNullOrWhiteSpace($subuid) -and -not [string]::IsNullOrWhiteSpace($subgid))
        StorageInitialized = $storageInitialized
        PodmanInfo = $null -ne $podmanInfo
        RootlessEngine = $rootless
        LocalEngine = ($null -ne $podmanInfo -and -not $serviceIsRemote)
        StorageScopedToUser = ($graphRoot -and $graphRoot.StartsWith("$linuxHome/", [StringComparison]::Ordinal))
        StorageDriver = ($graphDriverName -eq 'overlay')
        SeccompEnabled = $seccompEnabled
        PodmanApiDisabled = ($podmanUnitActive.Count -eq 0 -and $podmanUnitEnabled.Count -eq 0)
        DockerPackagesAbsent = -not ($dockerPackages.Installed -contains $true)
        DockerCommandAbsent = [string]::IsNullOrWhiteSpace($dockerCommand)
        DockerServicesAbsent = (-not $dockerUserActive -and -not $dockerUserEnabled -and $dockerRootActive.Count -eq 0 -and $dockerRootEnabled.Count -eq 0)
        DockerRepositoryAbsent = -not $dockerRepository
        DockerDesktopIntegrated = -not $dockerDesktopIntegrated
        InteropDisabled = $interopDisabled
        AutomountDisabled = $automountDisabled
        DailyUserWithoutSudo = $withoutSudo
    }
    $pending = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
    [pscustomobject]@{
        SchemaVersion = 1
        Status = if ($pending.Count -eq 0) { 'compliant' } else { 'drift-detected' }
        MigrationPhase = if ($pending.Count -eq 0) { 'compliant' } elseif ($null -ne $podmanInfo) { 'podman-provisioned' } else { 'docker-only-or-partial' }
        Distribution = $distribution
        User = $linuxUser
        Uid = $uid
        Home = $linuxHome
        PodmanVersion = $podmanVersion
        PodmanStorageRoot = $graphRoot
        PodmanStorageDriver = $graphDriverName
        PodmanServiceIsRemote = $serviceIsRemote
        DockerCommand = $dockerCommand
        DockerDesktopIntegrated = $dockerDesktopIntegrated
        LegacyDockerData = $legacyData
        PendingChanges = $pending
        MigrationImpact = 'Privileged networked WSL package and service changes; legacy Docker data retained.'
        Checks = [pscustomobject] $checks
    }
}

function Write-State {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 10; return }
    Write-Host "RootlessPodman: $($State.Status) ($($State.User)@$($State.Distribution))"
    Write-Host "  Migration phase: $($State.MigrationPhase)"
    foreach ($check in $State.Checks.PSObject.Properties) {
        Write-Host ('  {0}: {1}' -f $check.Name, $(if ($check.Value) { 'compliant' } else { 'drift detected' }))
    }
    foreach ($item in @($State.LegacyDockerData | Where-Object Exists)) {
        Write-Host "  Retained legacy Docker data: $($item.Path)"
    }
    Write-Host "  Impact: $($State.MigrationImpact)"
}

function Invoke-PyinfraDeploy {
    param([Parameter(Mandatory = $true)][string] $RelativePath)
    $deployWindows = Join-Path $repositoryRoot $RelativePath
    $deployDirectory = '/opt/dataworkstation/deploy'
    $deploy = "$deployDirectory/$([IO.Path]::GetFileName($RelativePath))"
    & wsl.exe -d $distribution --user root --exec install -d -m 0755 $deployDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Failed to prepare the private Debian-MW deploy directory.' }
    Send-BytesToMalwareGuest -Bytes ([IO.File]::ReadAllBytes($deployWindows)) -Destination $deploy
    $path = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    & wsl.exe -d $distribution --user root --exec env "PATH=$path" "ROOTLESS_PODMAN_USER=$linuxUser" `
        $configuration.Pyinfra '@local' $deploy '-y'
    if ($LASTEXITCODE -ne 0) { throw "pyinfra failed to apply '$RelativePath' with exit code ${LASTEXITCODE}." }
}

$before = Get-RootlessPodmanState
if ($Mode -eq 'Test') {
    Write-State $before -AsJson:$Json
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if (-not (Test-DistributionInstalled)) {
    Write-Host "Installing a clean $($configuration.BaseDistribution) WSL distribution as '$distribution' without interactive OOBE."
    & wsl.exe --install $configuration.BaseDistribution --name $distribution --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'The WSL Store-backed download failed; retrying through --web-download.'
        & wsl.exe --install $configuration.BaseDistribution --name $distribution --no-launch --web-download
    }
    if ($LASTEXITCODE -ne 0) { throw "WSL failed to install ${distribution} with exit code ${LASTEXITCODE}." }
    & wsl.exe -d $distribution --user root --exec sh -lc "id -u '$linuxUser' >/dev/null 2>&1 || useradd --create-home --shell /bin/bash '$linuxUser'"
    if ($LASTEXITCODE -ne 0) { throw "Failed to create $linuxUser in $distribution." }
    & wsl.exe --manage $distribution --set-default-user $linuxUser
    if ($LASTEXITCODE -ne 0) { throw "Failed to set the default user for $distribution." }
}

$currentBoundary = Invoke-MalwareUserShell 'cat /etc/wsl.conf 2>/dev/null || true'
if ($currentBoundary.Replace("`r`n", "`n").Trim() -ne $configuration.BoundaryConfiguration.Replace("`r`n", "`n").Trim()) {
    Write-Host "Applying the restricted WSL boundary and restarting only '$distribution'."
    Send-BytesToMalwareGuest -Bytes ([Text.Encoding]::UTF8.GetBytes($configuration.BoundaryConfiguration)) -Destination '/etc/wsl.conf'
    & wsl.exe --terminate $distribution | Out-Null
    & wsl.exe -d $distribution --user root --exec true
    if ($LASTEXITCODE -ne 0) { throw "'$distribution' did not start after applying its WSL boundary." }
}

Write-Host "Bootstrapping pinned pyinfra inside $distribution. This is a privileged networked package change."
& wsl.exe -d $distribution --user root --exec sh -lc "DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates python3 python3-venv && (test -x '$($configuration.Pip)' || python3 -m venv /opt/dataworkstation/pyinfra) && ('$($configuration.Pyinfra)' --version 2>/dev/null | grep -q 'v$($configuration.PyinfraVersion)' || '$($configuration.Pip)' install --disable-pip-version-check --no-compile --force-reinstall 'pyinfra==$($configuration.PyinfraVersion)')"
if ($LASTEXITCODE -ne 0) { throw "Failed to bootstrap pyinfra in $distribution." }

Invoke-PyinfraDeploy -RelativePath 'linux/rootless_podman.py'
$PodmanProvisioned = Get-RootlessPodmanState
$podmanGateNames = @('DistributionInstalled', 'DedicatedBoundary', 'NonRootUser', 'PodmanPackages', 'SubordinateIds', 'StorageInitialized', 'PodmanInfo', 'RootlessEngine', 'LocalEngine', 'StorageScopedToUser', 'StorageDriver', 'SeccompEnabled', 'PodmanApiDisabled')
$failedPodmanChecks = @($podmanGateNames | Where-Object { -not $PodmanProvisioned.Checks.$_ })
if ($failedPodmanChecks.Count -gt 0) {
    Write-State $PodmanProvisioned -AsJson:$Json
    throw "Podman provisioning failed its pre-retirement gate: $($failedPodmanChecks -join ', '). Docker was not retired."
}

Write-Host 'PodmanProvisioned: local rootless readiness passed. Retiring Docker packages and services while retaining legacy data.'
Invoke-PyinfraDeploy -RelativePath 'linux/retire_rootless_docker.py'

$after = Get-RootlessPodmanState
Write-State $after -AsJson:$Json
if ($after.Status -ne 'compliant') { throw 'Rootless Podman did not reach the declared state.' }
