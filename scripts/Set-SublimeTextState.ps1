[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\sublime-text.psd1')
$installDirectory = [Environment]::ExpandEnvironmentVariables($configuration.InstallDirectory)

function Test-SublimeTextPathEntry {
    param([AllowNull()][string] $PathValue, [string] $Directory)

    @($PathValue -split ';' | Where-Object {
        [Environment]::ExpandEnvironmentVariables($_.Trim().Trim('"')).TrimEnd('\') -ieq $Directory.TrimEnd('\')
    }).Count -gt 0
}

function Get-SublimeTextUserPath {
    param([AllowNull()][string] $PathValue, [string] $Directory)

    if (Test-SublimeTextPathEntry -PathValue $PathValue -Directory $Directory) { return $PathValue }
    if ([string]::IsNullOrEmpty($PathValue)) { return $Directory }
    $PathValue.TrimEnd(';') + ';' + $Directory
}

function Get-SublimeTextState {
    param([string] $Directory, [AllowNull()][string] $UserPath)

    $commandPath = Join-Path $Directory $configuration.Command
    $installed = Test-Path -LiteralPath $commandPath -PathType Leaf
    $onUserPath = Test-SublimeTextPathEntry -PathValue $UserPath -Directory $Directory
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'SublimeTextPath'
        State = if ($installed -and $onUserPath) { 'compliant' } else { 'drift detected' }
        Optional = $true
        Installed = $installed
        OnUserPath = $onUserPath
        Path = $commandPath
    }
}

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$result = Get-SublimeTextState -Directory $installDirectory -UserPath $userPath
if ($Mode -ne 'Test') {
    if (-not $result.Installed) {
        throw "Sublime Text is not installed at '$installDirectory'. Install it there or update config/sublime-text.psd1 before enabling this module."
    }
    $desiredPath = Get-SublimeTextUserPath -PathValue $userPath -Directory $installDirectory
    if ($desiredPath -cne $userPath) {
        [Environment]::SetEnvironmentVariable('Path', $desiredPath, 'User')
    }
    $env:Path = Get-SublimeTextUserPath -PathValue $env:Path -Directory $installDirectory
    $result = Get-SublimeTextState -Directory $installDirectory -UserPath ([Environment]::GetEnvironmentVariable('Path', 'User'))
    if ($result.State -ne 'compliant') { throw 'Sublime Text user PATH did not become compliant.' }
}
if ($Json) { $result | ConvertTo-Json -Depth 4 }
else { $result | Format-Table Resource,State,Installed,OnUserPath,Path -AutoSize -Wrap | Out-Host }
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
