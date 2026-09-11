[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageFile = Join-Path $repositoryRoot '.config\audio-switcher.winget'
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\audio-switcher.psd1')

function Get-AudioSwitcherCommand {
    $command = Get-Command $configuration.Command -CommandType Application -ErrorAction Ignore |
        Select-Object -First 1
    if ($command) { return $command }

    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter $configuration.Command -ErrorAction Ignore |
        Where-Object FullName -Like "*$($configuration.PackageId)*" |
        Select-Object -First 1
}

if ($Mode -ne 'Test') {
    & winget.exe configure --file $packageFile --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Audio Switcher WinGet Configuration failed with exit code $LASTEXITCODE." }
}

$command = Get-AudioSwitcherCommand
$result = [pscustomobject]@{
    SchemaVersion = 1
    Resource = 'AudioSwitcherPackage'
    State = if ($command) { 'compliant' } else { 'drift detected' }
    PackageId = $configuration.PackageId
    Command = $configuration.Command
    Path = if ($command) {
        if ($command.PSObject.Properties['Source']) { $command.Source } else { $command.FullName }
    } else { $null }
    Homepage = $configuration.Homepage
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
} else {
    $result | Format-Table Resource,State,PackageId,Command,Path -AutoSize -Wrap | Out-Host
}

if ($Mode -ne 'Test' -and $result.State -ne 'compliant') { throw 'Audio Switcher package did not become compliant.' }
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
