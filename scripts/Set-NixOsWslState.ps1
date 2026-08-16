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
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\nixos-wsl.psd1')
$distribution = $wslEnvironment[$configuration.DistributionVariable]
$linuxUser = $wslEnvironment[$configuration.UserVariable]
$sourceDirectory = Join-Path $repositoryRoot 'nixos'
$stateDirectory = Join-Path $repositoryRoot 'state\nixos-wsl'
$assetPath = Join-Path $stateDirectory "$($configuration.ReleaseTag)\nixos.wsl"
$installLocation = [Environment]::ExpandEnvironmentVariables($configuration.InstallLocation)

function Get-InstalledDistributions {
    @(& wsl.exe --list --quiet 2>$null | ForEach-Object { ("$_" -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Test-NixOsDistribution {
    if ($distribution -notin @(Get-InstalledDistributions)) { return $false }
    $release = @(& wsl.exe -d $distribution -u root -- cat /etc/os-release 2>$null)
    $LASTEXITCODE -eq 0 -and @($release | Where-Object { $_ -eq 'ID=nixos' }).Count -eq 1
}

function Get-LocalNixSource {
    $template = Get-Content -LiteralPath (Join-Path $sourceDirectory 'local.nix.in') -Raw
    $template.Replace('@WSL_NIXOS_USER@', $linuxUser)
}

function Get-StringSha256 {
    param([Parameter(Mandatory = $true)][string] $Value)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    ([Convert]::ToHexString($hash)).ToLowerInvariant()
}

function Get-GuestSourceHash {
    param([Parameter(Mandatory = $true)][string] $FileName)
    $value = & wsl.exe -d $distribution -u root -- sha256sum "/etc/nixos/$FileName" 2>$null
    if ($LASTEXITCODE -ne 0 -or "$value" -notmatch '^([a-f0-9]{64})\s') { return $null }
    $Matches[1]
}

function Test-DeployedSources {
    if (-not (Test-NixOsDistribution)) { return $false }
    foreach ($fileName in @($configuration.SourceFiles)) {
        $sourcePath = Join-Path $sourceDirectory $fileName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { return $false }
        $expected = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ((Get-GuestSourceHash -FileName $fileName) -cne $expected) { return $false }
    }
    (Get-GuestSourceHash -FileName 'local.nix') -ceq (Get-StringSha256 -Value (Get-LocalNixSource))
}

function Get-LiveState {
    $result = [ordered]@{
        SchemaVersion = 1
        Distribution = $distribution
        User = $linuxUser
        Installed = $false
        Sources = 'missing'
        Status = 'drifted'
        StoreIntegrity = 'not-checked'
        SourceIntegrity = 'not-checked'
        CommandIntegrity = 'not-checked'
        Detail = "NixOS WSL distribution '$distribution' is not installed."
    }
    if (-not (Test-NixOsDistribution)) { return [pscustomobject] $result }

    $result.Installed = $true
    $result.Sources = if (Test-DeployedSources) { 'matched' } else { 'drifted' }
    $raw = @(& wsl.exe -d $distribution -u $linuxUser -- workstation-self-check --json 2>$null)
    $exitCode = $LASTEXITCODE
    if ($raw) {
        try {
            $guest = ($raw -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
            $result.Status = [string] $guest.status
            $result.StoreIntegrity = [string] $guest.storeIntegrity
            $result.SourceIntegrity = [string] $guest.sourceIntegrity
            $result.CommandIntegrity = [string] $guest.commandIntegrity
            $result.Detail = [string] $guest.detail
        } catch {
            $result.Status = 'drifted'
            $result.Detail = 'The NixOS self-check did not return valid JSON.'
        }
    } else {
        $result.Status = 'drifted'
        $result.Detail = 'The NixOS self-check command is missing or could not run.'
    }
    if ($result.Sources -ne 'matched' -and $result.Status -eq 'compliant') {
        $result.Status = 'drifted'
        $result.Detail = 'Repository Nix sources differ from the files deployed in NixOS.'
    }
    if ($exitCode -eq 2) { $result.Status = 'altered' }
    [pscustomobject] $result
}

function Write-State {
    param([Parameter(Mandatory = $true)] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 5; return }
    Write-Host "NixOS WSL: $($State.Status)"
    Write-Host "  Distribution: $($State.Distribution)"
    Write-Host "  User: $($State.User)"
    Write-Host "  Repository sources: $($State.Sources)"
    Write-Host "  Store integrity: $($State.StoreIntegrity)"
    Write-Host "  Source integrity: $($State.SourceIntegrity)"
    Write-Host "  Command integrity: $($State.CommandIntegrity)"
    Write-Host "  Detail: $($State.Detail)"
}

if ($Mode -eq 'Plan') {
    $plan = [pscustomobject]@{
        SchemaVersion = 1
        Distribution = $distribution
        User = $linuxUser
        Release = $configuration.ReleaseTag
        DownloadBytes = $configuration.AssetSizeBytes
        InstallLocation = $installLocation
        Packages = @('helm', 'kubectl', 'pulumi', 'openssh')
        Actions = @('verify pinned NixOS-WSL asset', 'install only when absent', 'deploy locked flake', 'build boot generation', 'restart only NixOS', 'run integrity self-check')
        NetworkRequired = $true
        TerminatesDistribution = $true
        UnregistersDistribution = $false
    }
    if ($Json) { $plan | ConvertTo-Json -Depth 5 } else { $plan | Format-List | Out-Host }
    exit 0
}

if ($Mode -eq 'Test') {
    $state = Get-LiveState
    Write-State -State $state
    if ($state.Status -eq 'compliant') { exit 0 }
    if ($state.Status -eq 'altered') { exit 2 }
    exit 1
}

foreach ($fileName in @($configuration.SourceFiles)) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceDirectory $fileName) -PathType Leaf)) {
        throw "Missing locked Nix source: nixos/$fileName"
    }
}

if ($Mode -eq 'Ensure' -and (Test-NixOsDistribution) -and (Test-DeployedSources)) {
    $currentState = Get-LiveState
    if ($currentState.Status -eq 'compliant' -and $currentState.Sources -eq 'matched') {
        Write-State -State $currentState
        exit 0
    }
}

if (-not (Test-NixOsDistribution)) {
    if ($distribution -in @(Get-InstalledDistributions)) {
        throw "Distribution '$distribution' exists but is not NixOS. Refusing to replace or unregister it."
    }
    $assetDirectory = Split-Path -Parent $assetPath
    New-Item -ItemType Directory -Path $assetDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configuration.AssetSha256) {
        Write-Host "Downloading pinned NixOS-WSL $($configuration.ReleaseTag) asset ($($configuration.AssetSizeBytes) bytes)."
        Invoke-WebRequest -UseBasicParsing -Uri $configuration.AssetUrl -OutFile $assetPath
    }
    $actualHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $configuration.AssetSha256) { throw 'NixOS-WSL asset hash mismatch.' }
    New-Item -ItemType Directory -Path (Split-Path -Parent $installLocation) -Force | Out-Null
    Write-Host "Installing NixOS WSL as '$distribution' in '$installLocation'."
    & wsl.exe --install --from-file $assetPath --name $distribution --location $installLocation --version 2 --no-launch
    if ($LASTEXITCODE -ne 0) { throw 'NixOS WSL installation failed.' }
}

if (-not (Test-NixOsDistribution)) { throw "Distribution '$distribution' did not start as NixOS." }

$temporaryDirectory = Join-Path $stateDirectory 'deploy'
New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
$localSource = Get-LocalNixSource
[IO.File]::WriteAllText((Join-Path $temporaryDirectory 'local.nix'), $localSource, [Text.UTF8Encoding]::new($false))
$linuxRepository = (& wsl.exe -d $distribution -u root -- wslpath -a -u $repositoryRoot.Replace('\', '\\')).Trim()
$linuxTemporary = (& wsl.exe -d $distribution -u root -- wslpath -a -u $temporaryDirectory.Replace('\', '\\')).Trim()
if (-not $linuxRepository -or -not $linuxTemporary) { throw 'Failed to translate Nix deployment paths into WSL.' }

& wsl.exe -d $distribution -u root -- install -d -m 0755 /etc/nixos
if ($LASTEXITCODE -ne 0) { throw 'Failed to prepare /etc/nixos.' }
foreach ($fileName in @($configuration.SourceFiles)) {
    & wsl.exe -d $distribution -u root -- install -m 0644 "$linuxRepository/nixos/$fileName" "/etc/nixos/$fileName"
    if ($LASTEXITCODE -ne 0) { throw "Failed to deploy nixos/$fileName." }
}
& wsl.exe -d $distribution -u root -- install -m 0644 "$linuxTemporary/local.nix" /etc/nixos/local.nix
if ($LASTEXITCODE -ne 0) { throw 'Failed to deploy the local NixOS user selection.' }

Write-Host "Building the locked NixOS boot generation for '$distribution'."
& wsl.exe -d $distribution -u root -- nixos-rebuild boot --flake "/etc/nixos#$($configuration.FlakeTarget)"
if ($LASTEXITCODE -ne 0) { throw 'nixos-rebuild boot failed.' }

Write-Host "Restarting only '$distribution' to activate the boot generation."
& wsl.exe --terminate $distribution | Out-Null
& wsl.exe -d $distribution -u root -- true
if ($LASTEXITCODE -ne 0) { throw 'NixOS failed to start after rebuilding.' }
& wsl.exe --terminate $distribution | Out-Null
$activeDefaultUser = (& wsl.exe -d $distribution -- id -un 2>$null).Trim()
if ($LASTEXITCODE -ne 0 -or $activeDefaultUser -ne $linuxUser) {
    throw "The activated NixOS generation did not select '$linuxUser' as its default user."
}

$state = Get-LiveState
Write-State -State $state
if ($state.Status -ne 'compliant') { throw "NixOS WSL did not reach the requested state: $($state.Status). $($state.Detail)" }
