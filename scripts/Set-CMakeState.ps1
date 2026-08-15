[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\native-development.psd1')

function Find-NativePackageCommand {
    param([string] $Name, [string[]] $Candidates, [string] $PackagePattern)
    $command = Get-Command $Name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($command) { return $command.Source }
    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $packageRoot -PathType Container) {
        $match = Get-ChildItem -LiteralPath $packageRoot -Directory -Filter $PackagePattern -ErrorAction Ignore |
            ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter $Name -Recurse -ErrorAction Ignore } |
            Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    $null
}

function Get-CMakeState {
    $cmakePath = Find-NativePackageCommand -Name 'cmake.exe' -Candidates @((Join-Path $env:ProgramFiles 'CMake\bin\cmake.exe')) -PackagePattern 'Kitware.CMake_*'
    $ninjaPath = Find-NativePackageCommand -Name 'ninja.exe' -Candidates @() -PackagePattern 'Ninja-build.Ninja_*'
    $generator = [Environment]::GetEnvironmentVariable('CMAKE_GENERATOR', 'User')
    $checks = [ordered]@{
        CMakePackage = [bool] $cmakePath
        NinjaPackage = [bool] $ninjaPath
        CMAKE_GENERATOR = $generator -eq $configuration.Environment.CMakeGenerator
    }
    [pscustomobject]@{
        SchemaVersion = 1; Resource = 'CMake'; State = if ($checks.Values -contains $false) { 'drift detected' } else { 'compliant' }
        Changed = $false; CMake = $cmakePath; Ninja = $ninjaPath
        Generator = $generator; Checks = [pscustomobject] $checks
    }
}

function Write-CMakeState {
    param([object] $State, [switch] $AsJson)
    if ($AsJson) { $State | ConvertTo-Json -Depth 5; return }
    $State | Format-List Resource,State,Changed,CMake,Ninja,Generator | Out-Host
}

$before = Get-CMakeState
if ($Mode -eq 'Test') {
    Write-CMakeState $before -AsJson:$Json
    if ($before.State -ne 'compliant') { exit 1 }
    exit 0
}
foreach ($file in @('.config\cmake.winget', '.config\ninja.winget')) {
    & winget.exe configure --file (Join-Path $repositoryRoot $file) --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "$file WinGet Configuration failed with exit code $LASTEXITCODE." }
}
[Environment]::SetEnvironmentVariable('CMAKE_GENERATOR', $configuration.Environment.CMakeGenerator, 'User')
$env:CMAKE_GENERATOR = $configuration.Environment.CMakeGenerator
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$machinePath;$userPath"
$after = Get-CMakeState
$after.Changed = ($before.State -ne 'compliant' -or $Mode -eq 'Reinitialize')
Write-CMakeState $after -AsJson:$Json
if ($after.State -ne 'compliant') { throw 'CMake and Ninja did not reach the declared state.' }
