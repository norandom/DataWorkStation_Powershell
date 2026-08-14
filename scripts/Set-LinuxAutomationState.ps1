[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
$wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\linux-automation.psd1')
$distribution = $wslEnvironment.WSL_DISTRIBUTION
$pyinfra = "/home/$($wslEnvironment.WSL_USER)/.local/bin/pyinfra"

function Test-BrewUv {
    & wsl.exe -d $distribution -- $configuration.Homebrew list --versions $configuration.UvFormula 2>$null | Out-Null
    $LASTEXITCODE -eq 0
}

function Test-Pyinfra {
    $version = & wsl.exe -d $distribution -- sh -lc "'$pyinfra' --version 2>&1"
    $LASTEXITCODE -eq 0 -and "$version" -match "v$([regex]::Escape($configuration.PyinfraVersion))(?:\s|$)"
}

$checks = [ordered]@{
    HomebrewUv = Test-BrewUv
    Pyinfra = Test-Pyinfra
}

if ($Mode -eq 'Test') {
    $checks.GetEnumerator() | ForEach-Object {
        Write-Host ("{0}: {1}" -f $_.Key, $(if ($_.Value) { 'compliant' } else { 'drift detected' }))
    }
    if ($checks.Values -contains $false) { exit 1 }
    exit 0
}

if (-not $checks.HomebrewUv) {
    & wsl.exe -d $distribution -- $configuration.Homebrew install $configuration.UvFormula
    if ($LASTEXITCODE -ne 0) { throw "Homebrew failed to install uv in $distribution." }
}

if (-not $checks.Pyinfra -or $Mode -eq 'Reinitialize') {
    & wsl.exe -d $distribution -- $configuration.Uv tool install --force "pyinfra==$($configuration.PyinfraVersion)"
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install pyinfra in $distribution." }
}

if (-not (Test-BrewUv) -or -not (Test-Pyinfra)) {
    throw "Linux automation did not reach the requested state in $distribution."
}
Write-Host "LinuxAutomation: compliant (pyinfra $($configuration.PyinfraVersion))"
