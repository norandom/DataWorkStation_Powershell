[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Json output selection is consumed by the nested state renderer.')]
[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\mpv.psd1')
if ([int] $configuration.SchemaVersion -ne 1) { throw "Unsupported mpv state schema: $($configuration.SchemaVersion)" }
$packageConfiguration = Join-Path $repositoryRoot ([string] $configuration.PackageConfiguration)
$managedConfiguration = Join-Path $repositoryRoot ([string] $configuration.ManagedConfiguration)
$userConfiguration = [Environment]::ExpandEnvironmentVariables([string] $configuration.UserConfiguration)
$commandPath = [Environment]::ExpandEnvironmentVariables([string] $configuration.CommandPath)
$backupDirectory = Join-Path $repositoryRoot ([string] $configuration.BackupDirectory)
$managedBlock = (Get-Content -LiteralPath $managedConfiguration -Raw).Trim()
$beginMarker = [string] $configuration.ManagedBlockBegin
$endMarker = [string] $configuration.ManagedBlockEnd
$blockPattern = '(?ms)^' + [regex]::Escape($beginMarker) + '.*?^' + [regex]::Escape($endMarker) + '\s*'

function Get-DesiredMpvConfiguration {
    param([AllowEmptyString()][string] $Existing)

    if ($Existing -match $blockPattern) {
        return [regex]::Replace($Existing, $blockPattern, $managedBlock + [Environment]::NewLine)
    }
    if ([string]::IsNullOrWhiteSpace($Existing)) { return $managedBlock + [Environment]::NewLine }
    $Existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $managedBlock + [Environment]::NewLine
}

function Get-MpvExecutable {
    $command = Get-Command mpv.exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if ($command) { return $command.Source }
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    Get-ChildItem -Path (Join-Path $packageRoot 'mpv-player.mpv-CI.MSVC_*\mpv.exe') -File -ErrorAction Ignore |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Test-MpvPackage {
    $null = @(& winget.exe list --id ([string] $configuration.PackageId) --exact --source winget --accept-source-agreements --disable-interactivity 2>$null)
    $LASTEXITCODE -eq 0
}

function Get-DesiredMpvCommand {
    param([Parameter(Mandatory = $true)][string] $Executable)
    "@echo off`r`n`"$Executable`" %*`r`nexit /b %ERRORLEVEL%`r`n"
}

function Get-MpvState {
    $installed = Test-MpvPackage
    $executable = if ($installed) { Get-MpvExecutable } else { $null }
    $existing = if (Test-Path -LiteralPath $userConfiguration -PathType Leaf) { Get-Content -LiteralPath $userConfiguration -Raw } else { '' }
    $desired = Get-DesiredMpvConfiguration -Existing $existing
    $configCompliant = $existing.TrimEnd() -ceq $desired.TrimEnd()
    $hardwareDecoderAvailable = $false
    $commandCompliant = $false
    $version = ''
    if ($executable) {
        $version = [string] (Get-Item -LiteralPath $executable).VersionInfo.ProductVersion
        $decoderOutput = (& $executable --no-config --hwdec=help 2>&1 | Out-String)
        $hardwareDecoderAvailable = $LASTEXITCODE -eq 0 -and $decoderOutput -match "(?m)^\s*$([regex]::Escape([string] $configuration.RequiredHardwareDecoder))(?:\s|\()"
        $desiredCommand = Get-DesiredMpvCommand -Executable $executable
        $commandCompliant = (Test-Path -LiteralPath $commandPath -PathType Leaf) -and
            (Get-Content -LiteralPath $commandPath -Raw) -ceq $desiredCommand
    }
    [pscustomobject][ordered]@{
        SchemaVersion = 1
        PackageId = [string] $configuration.PackageId
        Installed = $installed
        Executable = [string] $executable
        Version = $version
        UserConfiguration = $userConfiguration
        CommandPath = $commandPath
        CommandCompliant = $commandCompliant
        ConfigurationCompliant = $configCompliant
        HardwareDecoder = [string] $configuration.RequiredHardwareDecoder
        HardwareDecoderAvailable = $hardwareDecoderAvailable
        Compliant = $installed -and [bool] $executable -and $configCompliant -and $commandCompliant -and $hardwareDecoderAvailable
    }
}

function Write-MpvState {
    param([object] $State)
    if ($Json) { $State | ConvertTo-Json -Depth 5; return }
    Write-Host "mpv desired state: $(if ($State.Compliant) { 'compliant' } else { 'drift detected' })"
    Write-Host "  Package: $($State.PackageId); installed=$($State.Installed); version=$($State.Version)"
    Write-Host "  GPU decode: $($State.HardwareDecoder); available=$($State.HardwareDecoderAvailable)"
    Write-Host "  Config: $($State.UserConfiguration); compliant=$($State.ConfigurationCompliant)"
    Write-Host "  Command: $($State.CommandPath); compliant=$($State.CommandCompliant)"
}

$state = Get-MpvState
if ($Mode -eq 'Test') {
    Write-MpvState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if (-not $state.Installed -or $Mode -eq 'Reinitialize') {
    & winget.exe configure --file $packageConfiguration --accept-configuration-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "mpv WinGet Configuration failed with exit code $LASTEXITCODE." }
}

$existing = if (Test-Path -LiteralPath $userConfiguration -PathType Leaf) { Get-Content -LiteralPath $userConfiguration -Raw } else { '' }
$desired = Get-DesiredMpvConfiguration -Existing $existing
if ($existing.TrimEnd() -cne $desired.TrimEnd() -or $Mode -eq 'Reinitialize') {
    $userDirectory = Split-Path -Parent $userConfiguration
    New-Item -ItemType Directory -Path $userDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $userConfiguration -PathType Leaf) {
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        Copy-Item -LiteralPath $userConfiguration -Destination (Join-Path $backupDirectory "mpv-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).conf")
    }
    [IO.File]::WriteAllText($userConfiguration, $desired, [Text.UTF8Encoding]::new($false))
}

$executable = Get-MpvExecutable
if (-not $executable) { throw 'WinGet reported mpv installed, but mpv.exe could not be located.' }
$desiredCommand = Get-DesiredMpvCommand -Executable $executable
$existingCommand = if (Test-Path -LiteralPath $commandPath -PathType Leaf) { Get-Content -LiteralPath $commandPath -Raw } else { '' }
if ($existingCommand -cne $desiredCommand -or $Mode -eq 'Reinitialize') {
    New-Item -ItemType Directory -Path (Split-Path -Parent $commandPath) -Force | Out-Null
    [IO.File]::WriteAllText($commandPath, $desiredCommand, [Text.ASCIIEncoding]::new())
}

$verified = Get-MpvState
if (-not $verified.Compliant) { throw 'mpv package, GPU decoder, or managed configuration did not converge.' }
Write-MpvState $verified
