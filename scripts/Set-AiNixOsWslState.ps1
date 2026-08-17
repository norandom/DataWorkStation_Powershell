[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$selection = Import-WslEnvironment $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\ai-nixos-wsl.psd1')
if ($Mode -eq 'Plan') {
    $distribution = if ($selection.ContainsKey($configuration.DistributionVariable)) { [string] $selection[$configuration.DistributionVariable] } else { [string] $configuration.PlanDistribution }
    $dailyUser = if ($selection.ContainsKey($configuration.DailyUserVariable)) { [string] $selection[$configuration.DailyUserVariable] } else { [string] $configuration.PlanDailyUser }
} elseif (-not $selection.ContainsKey($configuration.DistributionVariable) -or -not $selection.ContainsKey($configuration.DailyUserVariable)) {
    throw "Copy the WSL_AI_DISTRIBUTION and WSL_AI_USER entries from .wsl-env.sample into .wsl-env before using AiNixOsWsl."
} else {
    $distribution = [string] $selection[$configuration.DistributionVariable]
    $dailyUser = [string] $selection[$configuration.DailyUserVariable]
}
$maintenanceUser = [string] $configuration.MaintenanceUser
$sourceDirectory = Join-Path $repositoryRoot 'nixos-ai'
$stateDirectory = Join-Path $repositoryRoot 'state\ai-nixos-wsl'
$assetPath = Join-Path $stateDirectory "$($configuration.ReleaseTag)\nixos.wsl"
$installLocation = [Environment]::ExpandEnvironmentVariables($configuration.InstallLocation)

function Get-DistributionNames {
    param([switch] $RunningOnly)
    $arguments = if ($RunningOnly) { @('--list', '--running', '--quiet') } else { @('--list', '--quiet') }
    @(& wsl.exe @arguments 2>$null | ForEach-Object { (([string] $_) -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Get-LocalNixSource {
    (Get-Content -LiteralPath (Join-Path $sourceDirectory 'local.nix.in') -Raw).Replace('@WSL_AI_USER@', $dailyUser)
}

function Get-StringSha256 {
    param([string] $Value)
    ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value)))).ToLowerInvariant()
}

function Invoke-AiGuestRead {
    param([string] $User, [string[]] $Arguments)
    $output = @(& wsl.exe -d $distribution -u $User -- @Arguments 2>$null)
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = ($output -join "`n").Trim() }
}

function Get-GuestFileSha256 {
    param([string] $Path)
    $result = Invoke-AiGuestRead root @('sha256sum', $Path)
    if ($result.ExitCode -eq 0 -and $result.Text -match '^([a-f0-9]{64})\s') { return $Matches[1] }
    $null
}

function Test-DeployedSources {
    foreach ($fileName in @($configuration.SourceFiles)) {
        $sourcePath = Join-Path $sourceDirectory $fileName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { return $false }
        $expected = (Get-FileHash $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ((Get-GuestFileSha256 "/etc/nixos/$fileName") -cne $expected) { return $false }
    }
    (Get-GuestFileSha256 '/etc/nixos/local.nix') -ceq (Get-StringSha256 (Get-LocalNixSource))
}

function Get-LiveState {
    $installed = $distribution -in @(Get-DistributionNames)
    $running = $distribution -in @(Get-DistributionNames -RunningOnly)
    $result = [ordered]@{
        SchemaVersion = 1
        Distribution = $distribution
        DailyUser = $dailyUser
        MaintenanceUser = $maintenanceUser
        Installed = $installed
        Running = $running
        Sources = 'not-checked'
        StoreIntegrity = 'not-checked'
        SourceIntegrity = 'not-checked'
        CommandIntegrity = 'not-checked'
        BoundaryIntegrity = 'not-checked'
        NonoVersion = $null
        NonoOwner = $null
        NonoSetup = 'not-checked'
        NetworkEnforcement = 'not-checked'
        ProfileSha256 = $null
        Status = 'drifted'
        Detail = if ($installed) { "Distribution '$distribution' is stopped; Test did not start it." } else { "Distribution '$distribution' is absent." }
    }
    if (-not $installed -or -not $running) { return [pscustomobject] $result }

    $release = Invoke-AiGuestRead root @('cat', '/etc/os-release')
    if ($release.ExitCode -ne 0 -or $release.Text -notmatch '(?m)^ID=nixos$') {
        $result.Status = 'altered'
        $result.Detail = "Distribution '$distribution' is not NixOS."
        return [pscustomobject] $result
    }
    $result.Sources = if (Test-DeployedSources) { 'matched' } else { 'drifted' }
    $selfCheck = Invoke-AiGuestRead $dailyUser @('ai-workstation-self-check', '--json')
    if ($selfCheck.Text) {
        try {
            $guest = $selfCheck.Text | ConvertFrom-Json -ErrorAction Stop
            foreach ($name in @('StoreIntegrity', 'SourceIntegrity', 'CommandIntegrity', 'BoundaryIntegrity')) { $result[$name] = [string] $guest.$name }
            $result.Status = [string] $guest.status
            $result.Detail = [string] $guest.detail
        } catch {
            $result.Status = 'drifted'
            $result.Detail = 'AI NixOS self-check returned invalid JSON.'
        }
    }
    if ($selfCheck.ExitCode -eq 2) { $result.Status = 'altered' }

    $nono = $configuration.Nono.BrewPrefix + '/bin/nono'
    $version = Invoke-AiGuestRead $maintenanceUser @($nono, '--version')
    if ($version.ExitCode -eq 0 -and $version.Text -match '(\d+\.\d+\.\d+)') { $result.NonoVersion = $Matches[1] }
    $owner = Invoke-AiGuestRead root @('stat', '-c', '%U', $nono)
    if ($owner.ExitCode -eq 0) { $result.NonoOwner = $owner.Text }
    $result.ProfileSha256 = Get-GuestFileSha256 $configuration.Nono.Profile
    $setup = Invoke-AiGuestRead $dailyUser @($nono, 'setup', '--check-only')
    $result.NonoSetup = if ($setup.ExitCode -eq 0) { 'verified' } else { 'failed' }
    $result.NetworkEnforcement = if ($setup.ExitCode -eq 0 -and $setup.Text -match 'TCP network rule support verified') { 'verified' } else { 'unavailable' }

    $nonoCompliant = $result.NonoVersion -eq $configuration.Nono.ExpectedVersion -and
        $result.NonoOwner -eq $maintenanceUser -and
        $result.ProfileSha256 -eq $configuration.Nono.ProfileSha256 -and
        $result.NonoSetup -eq 'verified' -and $result.NetworkEnforcement -eq 'verified'
    if ($result.Sources -ne 'matched' -or -not $nonoCompliant) {
        if ($result.Status -eq 'compliant') { $result.Status = 'drifted' }
        $result.Detail = 'AI NixOS sources, nono provenance, reviewed profile, or secure network enforcement are not compliant.'
    }
    [pscustomobject] $result
}

function Write-State {
    param($State)
    if ($Json) { $State | ConvertTo-Json -Depth 7; return }
    Write-Host "AI NixOS WSL: $($State.Status)"
    Write-Host "  Distribution: $($State.Distribution) (running=$($State.Running))"
    Write-Host "  Daily user: $($State.DailyUser); maintenance owner: $($State.MaintenanceUser)"
    Write-Host "  Sources: $($State.Sources); store=$($State.StoreIntegrity); commands=$($State.CommandIntegrity); boundary=$($State.BoundaryIntegrity)"
    Write-Host "  nono: version=$($State.NonoVersion); owner=$($State.NonoOwner); setup=$($State.NonoSetup); NetworkEnforcement=$($State.NetworkEnforcement)"
    Write-Host "  Detail: $($State.Detail)"
}

function Send-BytesToGuest {
    param([byte[]] $Bytes, [string] $Destination, [string] $Mode = '0644')
    $base64 = [Convert]::ToBase64String($Bytes)
    $base64 | & wsl.exe -d $distribution -u root -- sh -c "umask 022; base64 --decode > '$Destination' && chmod '$Mode' '$Destination'"
    if ($LASTEXITCODE -ne 0) { throw "Failed to stream '$Destination' into '$distribution'." }
}

$before = Get-LiveState
if ($Mode -eq 'Plan') {
    $plan = [pscustomobject]@{
        SchemaVersion = 1; Distribution = $distribution; DailyUser = $dailyUser; MaintenanceUser = $maintenanceUser
        Status = $before.Status; Release = $configuration.ReleaseTag; DownloadBytes = $configuration.AssetSizeBytes
        Actions = @('verify pinned NixOS-WSL image', 'install only when absent', 'stream locked sources without Windows mounts', 'build and restart only AI NixOS', 'run brew install nono as maintenance owner', 'verify full integrity and secure nono enforcement')
        NetworkRequired = $true; TerminatesDistribution = $true; UnregistersDistribution = $false
    }
    if ($Json) { $plan | ConvertTo-Json -Depth 6 } else { $plan | Format-List | Out-Host }
    exit 0
}
if ($Mode -eq 'Test') { Write-State $before; if ($before.Status -eq 'compliant') { exit 0 } elseif ($before.Status -eq 'altered') { exit 2 } else { exit 1 } }

foreach ($fileName in @($configuration.SourceFiles)) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDirectory $fileName) -PathType Leaf)) { throw "Missing locked AI Nix source: nixos-ai/$fileName" }
}

if (-not $before.Installed) {
    $assetDirectory = Split-Path -Parent $assetPath
    New-Item -ItemType Directory -Path $assetDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf) -or (Get-FileHash $assetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configuration.AssetSha256) {
        Write-Host "Downloading pinned NixOS-WSL $($configuration.ReleaseTag) image."
        Invoke-WebRequest -UseBasicParsing -Uri $configuration.AssetUrl -OutFile $assetPath
    }
    if ((Get-FileHash $assetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configuration.AssetSha256) { throw 'AI NixOS-WSL image SHA-256 mismatch.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $installLocation) -Force | Out-Null
    & wsl.exe --install --from-file $assetPath --name $distribution --location $installLocation --version 2 --no-launch
    if ($LASTEXITCODE -ne 0) { throw "Failed to install AI NixOS distribution '$distribution'." }
} elseif ((Invoke-AiGuestRead root @('cat', '/etc/os-release')).Text -notmatch '(?m)^ID=nixos$') {
    throw "Distribution '$distribution' exists but is not NixOS; refusing to replace or unregister it."
}

& wsl.exe -d $distribution -u root -- install -d -m 0755 /etc/nixos
if ($LASTEXITCODE -ne 0) { throw 'Failed to create /etc/nixos in AI NixOS.' }
foreach ($fileName in @($configuration.SourceFiles)) {
    Send-BytesToGuest ([IO.File]::ReadAllBytes((Join-Path $sourceDirectory $fileName))) "/etc/nixos/$fileName"
}
Send-BytesToGuest ([Text.Encoding]::UTF8.GetBytes((Get-LocalNixSource))) '/etc/nixos/local.nix'

Write-Host "Building the locked AI NixOS generation for '$distribution'."
& wsl.exe -d $distribution -u root -- nixos-rebuild boot --flake "/etc/nixos#$($configuration.FlakeTarget)"
if ($LASTEXITCODE -ne 0) { throw 'AI NixOS rebuild failed.' }
Write-Host "Restarting only '$distribution' to activate its restricted boundary."
& wsl.exe --terminate $distribution | Out-Null
& wsl.exe -d $distribution -u root -- true
if ($LASTEXITCODE -ne 0) { throw 'AI NixOS did not start after rebuild.' }

$brew = $configuration.Nono.BrewPrefix + '/bin/brew'
$brewCheck = Invoke-AiGuestRead $maintenanceUser @($brew, '--version')
if ($brewCheck.ExitCode -ne 0) {
    Write-Host 'Installing Homebrew under the non-login AI maintenance identity.'
    & wsl.exe -d $distribution -u $maintenanceUser -- env HOME=/home/linuxbrew NONINTERACTIVE=1 /bin/bash -c '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    if ($LASTEXITCODE -ne 0) { throw 'Homebrew bootstrap failed inside AI NixOS.' }
}
Write-Host 'Running the declared AI sandbox package command: brew install nono'
& wsl.exe -d $distribution -u $maintenanceUser -- env HOME=/home/linuxbrew $brew install nono
if ($LASTEXITCODE -ne 0) { throw 'brew install nono failed inside AI NixOS.' }
& wsl.exe -d $distribution -u $maintenanceUser -- env HOME=/home/linuxbrew $brew pin nono
if ($LASTEXITCODE -ne 0) { throw 'Failed to pin the reviewed nono formula version.' }

$after = Get-LiveState
Write-State $after
if ($after.Status -ne 'compliant') { throw "AI NixOS did not reach the declared state: $($after.Detail)" }
