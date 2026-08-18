[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\native-development.psd1')

function Get-VsWherePath {
    $candidate = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    $command = Get-Command vswhere.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($command) { return $command.Source }
    $null
}

function Get-MsvcInstance {
    $vswhere = Get-VsWherePath
    if (-not $vswhere) { return $null }
    $arguments = @('-latest', '-products', 'Microsoft.VisualStudio.Product.BuildTools', '-format', 'json', '-utf8')
    foreach ($component in $configuration.Msvc.RequiredComponents) { $arguments += @('-requires', $component) }
    $json = @(& $vswhere @arguments 2>$null) -join "`n"
    if (-not $json) { return $null }
    $instances = @($json | ConvertFrom-Json)
    if ($instances.Count -gt 0) { return $instances[0] }
    $null
}

function Get-MsvcState {
    $instance = Get-MsvcInstance
    $checks = [ordered]@{
        StandaloneBuildTools = [bool] $instance
        RequiredComponents = [bool] $instance
        X64DeveloperCommand = ($instance -and (Test-Path -LiteralPath (Join-Path $instance.installationPath 'Common7\Tools\VsDevCmd.bat') -PathType Leaf))
        LegacyUserCCAbsent = [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('CC', 'User'))
        LegacyUserCXXAbsent = [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable('CXX', 'User'))
    }
    [pscustomobject]@{
        SchemaVersion = 1; Resource = 'MsvcBuildTools'; State = if ($checks.Values -contains $false) { 'drift detected' } else { 'compliant' }
        Changed = $false; PackageId = $configuration.Msvc.PackageId
        InstallationPath = if ($instance) { $instance.installationPath } else { $null }
        Version = if ($instance) { $instance.installationVersion } else { $null }
        RequiredComponents = @($configuration.Msvc.RequiredComponents); Privileged = $true; RestartRequired = $false
        Checks = [pscustomobject] $checks
    }
}

function Write-MsvcState {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 6; return }
    Write-Host "MSVC Build Tools: $($State.State)"
    Write-Host "  installation: $($State.InstallationPath)"
    Write-Host '  repair impact: privileged standalone Build Tools install; no automatic restart'
    foreach ($component in $State.RequiredComponents) { Write-Host "  component: $component" }
}

$before = Get-MsvcState
if ($Mode -eq 'Test') {
    Write-MsvcState $before -AsJson:$Json
    if ($before.State -ne 'compliant') { exit 1 }
    exit 0
}
$packageDrift = -not $before.Checks.StandaloneBuildTools -or
    -not $before.Checks.RequiredComponents -or
    -not $before.Checks.X64DeveloperCommand
if ($packageDrift -or $Mode -eq 'Reinitialize') {
    $override = @('--wait', '--quiet', '--norestart')
    foreach ($component in $configuration.Msvc.RequiredComponents) { $override += @('--add', $component) }
    $arguments = @('install', '--id', $configuration.Msvc.PackageId, '--exact', '--source', 'winget', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity', '--override', ($override -join ' '))
    if ($Mode -eq 'Reinitialize') { $arguments += '--force' }
    & winget.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Build Tools installer failed with exit code $LASTEXITCODE." }
}
[Environment]::SetEnvironmentVariable('CC', $null, 'User')
[Environment]::SetEnvironmentVariable('CXX', $null, 'User')
$after = Get-MsvcState
$after.Changed = ($before.State -ne 'compliant' -or $Mode -eq 'Reinitialize')
Write-MsvcState $after -AsJson:$Json
if ($after.State -ne 'compliant') { throw 'MSVC Build Tools did not reach the declared component state; a restart may be pending.' }
