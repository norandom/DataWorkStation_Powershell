[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure')]
    [string] $Mode = 'Test',
    [switch] $ConfirmDestructive,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$selection = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\rootless-podman.psd1')
$distribution = [string] $selection.WSL_MALWARE_DISTRIBUTION
$linuxUser = [string] $selection.WSL_MALWARE_USER

if ($distribution -ne [string] $configuration.RequiredDistribution -or $linuxUser -notmatch '^[a-z_][a-z0-9_-]*$') {
    throw 'Legacy cleanup requires the exact declared Debian-MW distribution and a valid non-root user.'
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

function Get-LegacyDockerDataState {
    $linuxHome = (Invoke-MalwareUserShell "getent passwd '$linuxUser' | cut -d: -f6").Trim()
    if (-not $linuxHome -or $linuxHome -eq '/' -or $linuxHome -notmatch '^/home/[^/]+$') {
        throw 'Cleanup refused an unresolved home, filesystem root, or distribution root.'
    }
    $podmanStorage = "$linuxHome/$($configuration.PodmanStorageRelativePath)"
    $items = foreach ($relativePath in @($configuration.LegacyDockerDataPaths)) {
        if ($relativePath -notmatch '^[A-Za-z0-9._/-]+$' -or $relativePath.StartsWith('/') -or $relativePath -match '(^|/)\.\.(/|$)') {
            throw "Cleanup refused unsupported relative path '$relativePath'."
        }
        $expected = "$linuxHome/$relativePath"
        if ($expected -eq $linuxHome) { throw 'Cleanup refused the home itself.' }
        if ($expected -eq $podmanStorage -or $expected.StartsWith("$podmanStorage/", [StringComparison]::Ordinal)) {
            throw 'Cleanup refused Podman storage.'
        }
        $exists = Invoke-MalwareUserCommand -ArgumentList @('test', '-e', $expected)
        $link = Invoke-MalwareUserCommand -ArgumentList @('test', '-L', $expected)
        $present = ($exists.ExitCode -eq 0 -or $link.ExitCode -eq 0)
        $resolved = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('readlink', '-f', '--', $expected)).Text } else { $null }
        $owner = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('stat', '-c', '%U', '--', $expected)).Text } else { $null }
        $sizeText = if ($present) { (Invoke-MalwareUserCommand -ArgumentList @('du', '-sb', '--', $expected)).Text } else { $null }
        $bytes = if ($sizeText -match '^(\d+)') { [int64] $Matches[1] } else { $null }
        [pscustomobject]@{
            Path = $expected
            Exists = $present
            ResolvedPath = $resolved
            Owner = $owner
            Bytes = $bytes
            ReparsePoint = ($link.ExitCode -eq 0)
        }
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Status = if (@($items | Where-Object Exists).Count -eq 0) { 'compliant' } else { 'retained' }
        Distribution = $distribution
        User = $linuxUser
        Home = $linuxHome
        RootlessPodman = 'required-before-cleanup'
        LegacyDockerDataPaths = @($items)
        Destructive = $true
    }
}

function Write-State {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 8; return }
    Write-Host "LegacyDockerCleanup: $($State.Status) ($($State.User)@$($State.Distribution))"
    foreach ($item in @($State.LegacyDockerDataPaths)) {
        Write-Host ('  {0}: {1}' -f $item.Path, $(if ($item.Exists) { "retained ($($item.Bytes) bytes)" } else { 'absent' }))
    }
}

$before = Get-LegacyDockerDataState
if ($Mode -eq 'Test') {
    Write-State $before -AsJson:$Json
    if ($before.Status -ne 'compliant') { exit 1 }
    exit 0
}

if (-not $ConfirmDestructive) {
    throw 'Legacy Docker cleanup Ensure requires -ConfirmDestructive.'
}

$podmanJson = @(& pwsh -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'Set-RootlessPodmanState.ps1') -Mode Test -Json 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0) { throw "RootlessPodman must be compliant before cleanup: $podmanJson" }

foreach ($item in @($before.LegacyDockerDataPaths | Where-Object Exists)) {
    if ($item.ReparsePoint) { throw "Cleanup refused ReparsePoint '$($item.Path)'." }
    if ($item.Owner -ne $linuxUser) { throw "Cleanup refused unexpected Owner '$($item.Owner)' for '$($item.Path)'." }
    if (-not $item.ResolvedPath -or $item.ResolvedPath -ne $item.Path) { throw "Cleanup refused unresolved target '$($item.Path)'." }
    if ($item.ResolvedPath -eq '/' -or $item.ResolvedPath -eq $before.Home) { throw 'Cleanup refused the filesystem root, distribution root, or home itself.' }
    & wsl.exe -d $distribution --user $linuxUser --exec rm --recursive --force --one-file-system -- $item.ResolvedPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to remove '$($item.ResolvedPath)': $LASTEXITCODE" }
}

$after = Get-LegacyDockerDataState
Write-State $after -AsJson:$Json
if ($after.Status -ne 'compliant') { throw 'Legacy Docker data remains after confirmed cleanup.' }
