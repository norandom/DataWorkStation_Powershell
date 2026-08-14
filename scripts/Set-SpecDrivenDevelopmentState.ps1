[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\spec-driven-development.psd1')
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Stop).Source
$downloadDirectory = Join-Path $env:LOCALAPPDATA 'PowerShellWorkstation\downloads'
$wheel = Join-Path $downloadDirectory (Split-Path -Leaf $configuration.Url)

function Get-SpecDrivenDevelopmentState {
    $toolList = & $uv tool list --show-version-specifiers 2>$null | Out-String
    $toolListOk = $LASTEXITCODE -eq 0
    $packagePattern = '(?m)^{0}\s+v{1}(?:\s|$)' -f
        [regex]::Escape($configuration.Package), [regex]::Escape($configuration.Version)
    $packageOk = $toolListOk -and $toolList -match $packagePattern

    $command = Get-Command $configuration.Executable -CommandType Application -ErrorAction Ignore
    $commandOk = $false
    if ($command) {
        $help = & $command.Source --help 2>$null | Out-String
        $commandOk = $LASTEXITCODE -eq 0 -and $help -match 'EARS/TDD Spec Kit policy'
    }

    @(
        [pscustomobject]@{
            Resource = 'SpecKitEarsTddPackage'
            State = if ($packageOk) { 'compliant' } else { 'drift detected' }
            Detail = "release $($configuration.ReleaseTag); specify-cli==$($configuration.SpecifyCliVersion)"
        }
        [pscustomobject]@{
            Resource = 'EarsSddCommand'
            State = if ($commandOk) { 'compliant' } else { 'drift detected' }
            Detail = if ($command) { $command.Source } else { $configuration.Executable }
        }
    )
}

function Test-SpecDrivenDevelopmentState {
    $state = @(Get-SpecDrivenDevelopmentState)
    -not @($state | Where-Object State -ne 'compliant').Count
}

function Install-SpecDrivenDevelopmentTool {
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $downloadRequired = $Mode -eq 'Reinitialize' -or -not (Test-Path -LiteralPath $wheel -PathType Leaf)
    if (-not $downloadRequired) {
        $cachedHash = (Get-FileHash -LiteralPath $wheel -Algorithm SHA256).Hash.ToLowerInvariant()
        $downloadRequired = $cachedHash -ne $configuration.Sha256
    }

    if ($downloadRequired) {
        & curl.exe --fail --location --retry 3 --output $wheel $configuration.Url
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $wheel -PathType Leaf)) {
            throw "Spec Kit EARS/TDD release download failed: $LASTEXITCODE"
        }
    }

    $actualHash = (Get-FileHash -LiteralPath $wheel -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $configuration.Sha256) {
        throw "Spec Kit EARS/TDD wheel hash mismatch: $actualHash"
    }

    & $uv tool install --force $wheel
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install Spec Kit EARS/TDD: $LASTEXITCODE" }
}

$state = @(Get-SpecDrivenDevelopmentState)
if ($Mode -eq 'Test') {
    $state | Format-Table -AutoSize | Out-Host
    if ($state.State -contains 'drift detected') { exit 1 }
    exit 0
}

if ($Mode -eq 'Reinitialize' -or -not (Test-SpecDrivenDevelopmentState)) {
    Install-SpecDrivenDevelopmentTool
}

$finalState = @(Get-SpecDrivenDevelopmentState)
$finalState | Format-Table -AutoSize | Out-Host
if ($finalState.State -contains 'drift detected') {
    throw 'Spec-driven development tools did not reach the requested state.'
}

Write-Host "Spec-driven development state '$Mode' completed successfully."
