[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\developer-tools.psd1')
$codeqlRoot = Join-Path $env:LOCALAPPDATA "Programs\CodeQL\$($configuration.CodeQL.Version)\codeql"
$codeql = Join-Path $codeqlRoot 'codeql.exe'
$uv = (Get-Command uv.exe -ErrorAction Stop).Source
$poolMonState = Join-Path $PSScriptRoot 'Set-PoolMonState.ps1'
$packMarker = Join-Path $env:LOCALAPPDATA "PowerShellWorkstation\trailofbits-codeql-packs-$($configuration.CodeQL.Version).ready"

function Get-Aria2Path {
    $command = Get-Command aria2c.exe -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }
    Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter aria2c.exe -File -ErrorAction Ignore |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

function Test-Semgrep {
    $output = & $uv tool list 2>$null
    $LASTEXITCODE -eq 0 -and $output -match '(?m)^semgrep\s'
}

function Test-Rsync {
    & wsl.exe -d $configuration.DebianDistribution -- sh -lc 'command -v rsync >/dev/null 2>&1'
    $LASTEXITCODE -eq 0
}

function Test-CodeQL {
    if (-not (Test-Path -LiteralPath $codeql -PathType Leaf)) { return $false }
    $version = & $codeql version --format terse 2>$null
    $LASTEXITCODE -eq 0 -and "$version" -like "$($configuration.CodeQL.Version)*"
}

function Test-Ttd {
    $package = Get-AppxPackage -Name Microsoft.TimeTravelDebugging -ErrorAction Ignore
    $package -and [version]$package.Version -ge [version]$configuration.TTD.Version
}

function Install-Ttd {
    $downloadDirectory = Join-Path $env:LOCALAPPDATA 'PowerShellWorkstation\downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $bundle = Join-Path $downloadDirectory "TTD-$($configuration.TTD.Version).msixbundle"
    $aria2 = Get-Aria2Path
    $ariaExitCode = 1
    if ($aria2) {
        & $aria2 --continue=true --max-connection-per-server=3 --split=3 --dir=$downloadDirectory --out=(Split-Path -Leaf $bundle) $configuration.TTD.Url
        $ariaExitCode = $LASTEXITCODE
    }
    if ($ariaExitCode -ne 0 -or -not (Test-Path -LiteralPath $bundle) -or (Get-Item -LiteralPath $bundle).Length -eq 0) {
        & curl.exe --fail --location --retry 3 --output $bundle $configuration.TTD.Url
    }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $bundle)) { throw 'TTD download failed.' }
    $signature = Get-AuthenticodeSignature -LiteralPath $bundle
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike 'CN=Microsoft Corporation*') {
        throw "TTD package signature validation failed: $($signature.Status)"
    }
    Add-AppxPackage -Path $bundle
}

function Install-CodeQL {
    $aria2 = Get-Aria2Path
    if (-not $aria2) { throw 'aria2c is required before CodeQL can be installed.' }
    $downloadDirectory = Join-Path $env:LOCALAPPDATA 'PowerShellWorkstation\downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $archiveName = "codeql-win64-v$($configuration.CodeQL.Version).zip"
    $archive = Join-Path $downloadDirectory $archiveName
    & $aria2 --continue=true --max-connection-per-server=3 --split=3 --dir=$downloadDirectory --out=$archiveName $configuration.CodeQL.Url
    if ($LASTEXITCODE -ne 0) { throw "CodeQL download failed with exit code $LASTEXITCODE." }
    $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $configuration.CodeQL.Sha256) { throw "CodeQL archive hash mismatch: $actualHash" }
    $versionRoot = Split-Path -Parent $codeqlRoot
    New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $versionRoot -Force
}

$checks = [ordered]@{
    CodeQL = Test-CodeQL
    TrailOfBitsPacks = Test-Path -LiteralPath $packMarker
    SemgrepCE = Test-Semgrep
    DebianRsync = Test-Rsync
    TTD = Test-Ttd
}

if ($Mode -eq 'Test') {
    $checks.GetEnumerator() | ForEach-Object { Write-Host ("{0}: {1}" -f $_.Key, $(if ($_.Value) { 'compliant' } else { 'drift detected' })) }
    & (Get-Command pwsh.exe -ErrorAction Stop).Source -NoLogo -NoProfile -File $poolMonState -Mode Test
    $poolExit = $LASTEXITCODE
    if ($checks.Values -contains $false -or $poolExit -ne 0) { exit 1 }
    exit 0
}

if (-not $checks.CodeQL) { Install-CodeQL }
if (-not $checks.SemgrepCE -or $Mode -eq 'Reinitialize') {
    & $uv tool install --upgrade semgrep
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install Semgrep CE: $LASTEXITCODE" }
}
if (-not $checks.DebianRsync) {
    & wsl.exe -d $configuration.DebianDistribution -u root -- bash -lc 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y rsync'
    if ($LASTEXITCODE -ne 0) { throw "Debian failed to install rsync: $LASTEXITCODE" }
}
if (-not $checks.TTD) { Install-Ttd }

& $poolMonState -Mode $Mode
if ($LASTEXITCODE -ne 0) { throw "PoolMon state failed: $LASTEXITCODE" }

if (-not (Test-CodeQL) -or -not (Test-Semgrep) -or -not (Test-Rsync) -or -not (Test-Ttd)) {
    throw 'Developer tools did not reach the requested state.'
}

if ($Mode -eq 'Reinitialize' -or -not (Test-Path -LiteralPath $packMarker)) {
    $packs = @($configuration.TrailOfBitsPacks)
    & $codeql pack download @packs
    if ($LASTEXITCODE -ne 0) { throw "Trail of Bits CodeQL pack download failed: $LASTEXITCODE" }
    New-Item -ItemType File -Path $packMarker -Force | Out-Null
}

Write-Host "Developer tool state '$Mode' completed successfully."
