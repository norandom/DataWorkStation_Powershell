[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\repository-lint.psd1')
$requiredAnalyzerVersion = [string] $configuration.PSScriptAnalyzerVersion
$requiredPreCommitVersion = [string] $configuration.PreCommitVersion
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Stop).Source
. (Join-Path $PSScriptRoot 'Resolve-RepositoryLinter.ps1')

function Get-NativeLinterVersion {
    param([string] $Executable)
    $text = @(& $Executable --version 2>&1) -join ' '
    if ($LASTEXITCODE -ne 0) { return $null }
    $match = [regex]::Match($text, '\d+\.\d+\.\d+')
    if (-not $match.Success) { return $null }
    [version] $match.Value
}

function Install-NativeLinter {
    param([hashtable] $Tool)
    $executable = Resolve-RepositoryLinter -Tool $Tool
    $version = if ($executable) { Get-NativeLinterVersion -Executable $executable } else { $null }
    $minimumVersion = [version] $Tool.MinimumVersion
    if ($version -and $version -ge $minimumVersion) { return }

    $operation = if ($executable) { 'upgrade' } else { 'install' }
    & winget.exe $operation --id $Tool.PackageId --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "WinGet failed to $operation $($Tool.Name): $LASTEXITCODE" }

    $executable = Resolve-RepositoryLinter -Tool $Tool -Require
    $version = Get-NativeLinterVersion -Executable $executable
    if (-not $version -or $version -lt $minimumVersion) {
        throw "$($Tool.Name) $minimumVersion or newer is required; resolved version was $version."
    }
}

$module = Get-Module -ListAvailable PSScriptAnalyzer |
    Where-Object Version -eq $requiredAnalyzerVersion |
    Select-Object -First 1
if (-not $module) {
    $installer = Get-Command Install-PSResource -ErrorAction Ignore
    if (-not $installer) { throw 'Install-PSResource is required to install the pinned PSScriptAnalyzer module.' }
    Install-PSResource -Name PSScriptAnalyzer -Version $requiredAnalyzerVersion -Scope CurrentUser -Repository PSGallery -TrustRepository -Quiet
}

foreach ($tool in @($configuration.Tools)) { Install-NativeLinter -Tool $tool }

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
& (Join-Path $PSScriptRoot 'Invoke-RepositoryLint.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Repository pre-commit hooks and native linters installed.'
