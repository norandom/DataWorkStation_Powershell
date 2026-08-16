[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\shared-ssh.psd1')
$windowsConfig = [Environment]::ExpandEnvironmentVariables($configuration.WindowsConfig)
$excludedDistribution = $wslEnvironment[$configuration.ExcludedDistributionVariable]

function Get-TargetState {
    param([Parameter(Mandatory = $true)] $Target)
    $distribution = $wslEnvironment[$Target.DistributionVariable]
    $linuxUser = $wslEnvironment[$Target.UserVariable]
    if ($distribution -eq $excludedDistribution) { throw 'The malware-analysis distribution cannot receive shared SSH state.' }
    $windowsPath = (& wsl.exe -d $distribution -u $linuxUser -- wslpath -a -u $windowsConfig.Replace('\', '\\') 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $windowsPath) {
        return [pscustomobject]@{ Distribution = $distribution; User = $linuxUser; State = 'missing-distribution'; Target = '' ; Ssh = ''; Mode = '' }
    }
    $linuxConfig = "/home/$linuxUser/.ssh/config"
    $link = & wsl.exe -d $distribution -u $linuxUser -- readlink $linuxConfig 2>$null
    if ($LASTEXITCODE -ne 0) {
        & wsl.exe -d $distribution -u $linuxUser -- test -e $linuxConfig 2>$null
        $link = if ($LASTEXITCODE -eq 0) { 'regular-file' } else { 'missing' }
    }
    $sshPath = (& wsl.exe -d $distribution -u $linuxUser -- sh -lc 'command -v ssh 2>/dev/null || true').Trim()
    $fileMode = (& wsl.exe -d $distribution -u $linuxUser -- stat -Lc '%a' $linuxConfig 2>$null).Trim()
    $state = if ("$link".Trim() -eq $windowsPath -and $sshPath -match '^/' -and $fileMode -eq '600') { 'compliant' } else { 'drifted' }
    [pscustomobject]@{ Distribution = $distribution; User = $linuxUser; State = $state; Target = "$link".Trim(); Ssh = $sshPath; Mode = $fileMode }
}

function Get-State {
    $windowsState = if (Test-Path -LiteralPath $windowsConfig -PathType Leaf) { 'present' } else { 'missing' }
    $targets = @($configuration.LinuxTargets | ForEach-Object { Get-TargetState -Target $_ })
    [pscustomobject]@{
        SchemaVersion = 1
        WindowsConfig = $windowsConfig
        WindowsState = $windowsState
        ExcludedDistribution = $excludedDistribution
        LinuxTargets = $targets
        Status = if ($windowsState -eq 'present' -and $targets.State -notcontains 'drifted' -and $targets.State -notcontains 'missing-distribution') { 'compliant' } else { 'drifted' }
    }
}

function Write-State {
    param([Parameter(Mandatory = $true)] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 6; return }
    Write-Host "Shared SSH config: $($State.Status)"
    Write-Host "  Windows: $($State.WindowsConfig) ($($State.WindowsState))"
    foreach ($target in $State.LinuxTargets) {
        Write-Host "  $($target.Distribution): $($target.State); ssh=$($target.Ssh); config=$($target.Target); mode=$($target.Mode)"
    }
    Write-Host "  Excluded: $($State.ExcludedDistribution)"
}

if ($Mode -eq 'Plan') {
    $plan = [pscustomobject]@{
        SchemaVersion = 1
        CanonicalConfig = $windowsConfig
        LinkedDistributions = @($configuration.LinuxTargets | ForEach-Object { $wslEnvironment[$_.DistributionVariable] })
        ExcludedDistribution = $excludedDistribution
        WindowsSshRemainsDefault = $true
        ExistingRegularLinuxConfig = 'refuse-overwrite'
    }
    if ($Json) { $plan | ConvertTo-Json -Depth 5 } else { $plan | Format-List | Out-Host }
    exit 0
}

if ($Mode -eq 'Test') {
    $state = Get-State
    Write-State -State $state
    if ($state.Status -eq 'compliant') { exit 0 }
    exit 1
}

$windowsDirectory = Split-Path -Parent $windowsConfig
New-Item -ItemType Directory -Path $windowsDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $windowsConfig)) {
    [IO.File]::WriteAllText($windowsConfig, "# Shared OpenSSH client configuration for Windows and trusted WSL distributions.`n", [Text.UTF8Encoding]::new($false))
}

$windowsSsh = Get-Command ssh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
& $windowsSsh.Source -F $windowsConfig -G dataworkstation.invalid 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Windows OpenSSH rejected '$windowsConfig'." }

$permissionDistribution = $wslEnvironment[$configuration.PermissionDistributionVariable]
$permissionUser = $wslEnvironment[$configuration.PermissionUserVariable]
$permissionPath = (& wsl.exe -d $permissionDistribution -u $permissionUser -- wslpath -a -u $windowsConfig.Replace('\', '\\')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $permissionPath) { throw 'Failed to resolve the canonical SSH config through the metadata-aware NixOS mount.' }
& wsl.exe -d $permissionDistribution -u $permissionUser -- chmod 0600 $permissionPath
if ($LASTEXITCODE -ne 0) { throw 'Failed to set mode 0600 metadata on the canonical SSH config.' }

foreach ($target in $configuration.LinuxTargets) {
    $distribution = $wslEnvironment[$target.DistributionVariable]
    $linuxUser = $wslEnvironment[$target.UserVariable]
    if ($distribution -eq $excludedDistribution) { throw 'Refusing to configure SSH in the malware-analysis distribution.' }
    $windowsPath = (& wsl.exe -d $distribution -u $linuxUser -- wslpath -a -u $windowsConfig.Replace('\', '\\')).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $windowsPath) { throw "Failed to resolve the shared SSH path in '$distribution'." }
    $linuxConfig = "/home/$linuxUser/.ssh/config"
    & wsl.exe -d $distribution -u $linuxUser -- test -L $linuxConfig 2>$null
    if ($LASTEXITCODE -eq 0) {
        $kind = 'symlink'
    } else {
        & wsl.exe -d $distribution -u $linuxUser -- test -e $linuxConfig 2>$null
        $kind = if ($LASTEXITCODE -eq 0) { 'regular' } else { 'missing' }
    }
    if ($kind -eq 'regular') { throw "Refusing to replace the existing regular ~/.ssh/config in '$distribution'. Reconcile it with '$windowsConfig' first." }
    & wsl.exe -d $distribution -u $linuxUser -- mkdir -p -m 0700 "/home/$linuxUser/.ssh"
    if ($LASTEXITCODE -ne 0) { throw "Failed to prepare ~/.ssh in '$distribution'." }
    & wsl.exe -d $distribution -u $linuxUser -- ln -sfn $windowsPath "/home/$linuxUser/.ssh/config"
    if ($LASTEXITCODE -ne 0) { throw "Failed to link the shared SSH config in '$distribution'." }
    & wsl.exe -d $distribution -u $linuxUser -- ssh -G dataworkstation.invalid 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Native OpenSSH in '$distribution' rejected the shared config." }
}

$state = Get-State
Write-State -State $state
if ($state.Status -ne 'compliant') { throw 'Shared SSH configuration did not reach the requested state.' }
