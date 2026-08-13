[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requiredAnalyzerVersion = '1.25.0'
$requiredPreCommitVersion = '4.6.2'
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Stop).Source

$module = Get-Module -ListAvailable PSScriptAnalyzer |
    Where-Object Version -eq $requiredAnalyzerVersion |
    Select-Object -First 1
if (-not $module) {
    $installer = Get-Command Install-PSResource -ErrorAction Ignore
    if (-not $installer) { throw 'Install-PSResource is required to install the pinned PSScriptAnalyzer module.' }
    Install-PSResource -Name PSScriptAnalyzer -Version $requiredAnalyzerVersion -Scope CurrentUser -Repository PSGallery -TrustRepository -Quiet
}

Push-Location $repositoryRoot
try {
    & $uv tool install --force "pre-commit==$requiredPreCommitVersion"
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install pre-commit: $LASTEXITCODE" }
    $preCommit = (Get-Command pre-commit.exe -CommandType Application -ErrorAction Stop).Source
    & $preCommit validate-config
    if ($LASTEXITCODE -ne 0) { throw 'The pre-commit configuration is invalid.' }
    & $preCommit install --install-hooks
    if ($LASTEXITCODE -ne 0) { throw 'Unable to install the Git pre-commit hook.' }
} finally {
    Pop-Location
}

& (Join-Path $PSScriptRoot 'Invoke-PowerShellLint.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'PowerShell pre-commit hook installed.'
