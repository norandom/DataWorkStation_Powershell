[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageFile = Join-Path $repositoryRoot '.config\caffeine.winget'
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\caffeine.psd1')
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$startupApprovedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'

function Get-CaffeinePath {
    foreach ($commandName in $configuration.Commands) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction Ignore
        if ($command) { return $command.Source }
        $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        $match = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter $commandName -ErrorAction Ignore |
            Where-Object FullName -Like "*$($configuration.PackageId)*" |
            Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    $null
}

function Get-RegistryValueOrNull {
    param([string] $Key, [string] $Name)
    $item = Get-ItemProperty -Path $Key -ErrorAction Ignore
    if (-not $item) { return $null }
    $property = $item.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    $null
}

if ($Mode -ne 'Test') {
    & winget.exe configure --file $packageFile --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Caffeine WinGet Configuration failed with exit code $LASTEXITCODE." }
}

$path = Get-CaffeinePath
$expectedStartup = if ($path) {
    (@('"' + $path + '"') + @($configuration.StartupArguments)) -join ' '
} else { $null }
if ($Mode -ne 'Test' -and $path) {
    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -Path $runKey -Name $configuration.StartupValueName -Value $expectedStartup -Type String
    $approval = Get-RegistryValueOrNull -Key $startupApprovedKey -Name $configuration.StartupValueName
    if ($approval -is [byte[]] -and $approval.Count -gt 0 -and $approval[0] -eq 3) {
        Remove-ItemProperty -Path $startupApprovedKey -Name $configuration.StartupValueName
    }
}
$startupCommand = Get-RegistryValueOrNull -Key $runKey -Name $configuration.StartupValueName
$startupApproval = Get-RegistryValueOrNull -Key $startupApprovedKey -Name $configuration.StartupValueName
$startupDisabled = $startupApproval -is [byte[]] -and $startupApproval.Count -gt 0 -and $startupApproval[0] -eq 3
$startupEnabled = $expectedStartup -and $startupCommand -eq $expectedStartup -and -not $startupDisabled
$result = [pscustomobject]@{
    SchemaVersion = 1
    Resource = 'CaffeinePackage'
    State = if ($path -and $startupEnabled) { 'compliant' } else { 'drift detected' }
    PackageId = $configuration.PackageId
    Command = if ($path) { Split-Path -Leaf $path } else { $configuration.PreferredCommand }
    Path = $path
    Runtime = if (Get-Process caffeine,caffeine64,caffeine32 -ErrorAction Ignore) { 'running' } else { 'not running' }
    Startup = if ($startupEnabled) { 'enabled' } else { 'drift detected' }
    StartupCommand = $startupCommand
}
if ($Json) {
    $result | ConvertTo-Json -Depth 4
} else {
    $result | Format-Table Resource,State,PackageId,Runtime,Startup,Path -AutoSize -Wrap | Out-Host
}
if ($Mode -ne 'Test' -and $result.State -ne 'compliant') { throw 'Caffeine package or enabled startup state did not become compliant.' }
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
