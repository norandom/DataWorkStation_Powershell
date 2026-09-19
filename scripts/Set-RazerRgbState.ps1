[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure')][string] $Mode = 'Test',
    [switch] $RemoveSynapse,
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\razer-rgb.psd1')
$root = Join-Path $env:LOCALAPPDATA 'DataWorkStation\RazerRgb'
$openRgb = Join-Path $root 'OpenRGB-1.0\OpenRGB Windows 64-bit\OpenRGB.exe'
$helper = Join-Path $root 'RazerReactive.exe'
$source = Join-Path $PSScriptRoot 'razer-rgb\RazerReactive.cs'
$launcher = Join-Path $root 'Start-RazerRgb.ps1'
$launcherSource = Join-Path $PSScriptRoot 'Start-RazerRgb.ps1'
$configPath = Join-Path $root 'config\OpenRGB.json'
# OpenRGB detector names are case-sensitive, including distinct GPU spelling variants.
$detectors = [Collections.Generic.Dictionary[string,bool]]::new([StringComparer]::Ordinal)
foreach ($name in (Get-Content (Join-Path $repositoryRoot 'config\openrgb-1.0-detectors.json') -Raw | ConvertFrom-Json)) { $detectors[$name] = $false }
foreach ($name in $configuration.Detectors) {
    if (-not $detectors.ContainsKey($name)) { throw "Unknown OpenRGB detector: $name" }
    $detectors[$name] = $true
}
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$startupName = 'DataWorkStation Razer RGB'
$startup = '"' + (Join-Path $PSHOME 'pwsh.exe') + '" -NoLogo -NoProfile -WindowStyle Hidden -File "' + $launcher + '"'
$uninstallKey = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
$uninstallKey32 = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
function Get-SynapseRegistration {
    @(Get-ItemProperty $uninstallKey, $uninstallKey32 -ErrorAction Ignore | Where-Object DisplayName -EQ 'Razer Synapse')
}
if ($Mode -eq 'Test' -and $RemoveSynapse) { throw '-RemoveSynapse requires -Mode Ensure.' }
if ($Mode -eq 'Ensure') {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    if (-not (Test-Path -LiteralPath $openRgb)) {
        $archive = Join-Path $root 'OpenRGB-1.0.zip'
        if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest $configuration.ArchiveUrl -OutFile $archive }
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $configuration.ArchiveSha256) { throw 'OpenRGB archive hash mismatch.' }
        Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $root 'OpenRGB-1.0') -Force
    }
    $receiptPath = Join-Path $root 'helper-source.sha256'
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $previousHash = if (Test-Path $receiptPath) { (Get-Content $receiptPath -Raw).Trim() } else { '' }
    # Restart both owned processes so configuration-only changes take effect too.
    Get-Process RazerReactive -ErrorAction Ignore | Where-Object Path -EQ $helper | Stop-Process
    if (-not (Test-Path $helper) -or $previousHash -ne $sourceHash) {
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        & $compiler /nologo /target:winexe /reference:System.Windows.Forms.dll ('/out:' + $helper) $source | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Reactive helper compilation failed.' }
        Set-Content -LiteralPath $receiptPath -Value $sourceHash
    }
    $configDir = Join-Path $root 'config'
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    $desired = @{ Detectors = @{ detectors = $detectors }; Server = @{ all_controllers = $true; default_host = '127.0.0.1'; default_port = $configuration.Port } }
    # This private config belongs exclusively to the optional module.
    Get-Process OpenRGB -ErrorAction Ignore | Where-Object Path -EQ $openRgb | Stop-Process
    $desired | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath
    [pscustomobject]$configuration | Select-Object BaseColor,PressColor,DurationMilliseconds,Port | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'theme.json')
    Copy-Item -LiteralPath $launcherSource -Destination $launcher -Force
    New-Item -Path $runKey -Force | Out-Null
    Set-ItemProperty -LiteralPath $runKey -Name $startupName -Value $startup
    $approvedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
    $approval = (Get-ItemProperty -LiteralPath $approvedKey -Name $startupName -ErrorAction Ignore).$startupName
    if ($approval -and $approval[0] -eq 3) { Remove-ItemProperty -LiteralPath $approvedKey -Name $startupName }
    if ($RemoveSynapse) {
        foreach ($registration in (Get-SynapseRegistration)) {
            if ($registration.UninstallString -notmatch '^"([^"]+)"\s+(.+)$') { throw 'Unrecognized Synapse uninstall command; use Windows Installed Apps.' }
            $uninstaller = $Matches[1]; $arguments = $Matches[2]
            Write-Host 'Removing Razer Synapse with its registered uninstaller.'
            $process = Start-Process -FilePath $uninstaller -ArgumentList $arguments -PassThru -Wait
            if ($process.ExitCode -notin @(0,3010)) { throw "Synapse uninstaller returned $($process.ExitCode)." }
        }
        if (Get-SynapseRegistration) { throw 'Synapse remains registered; finish its uninstaller before continuing.' }
    }
    & $launcher
}
$registration = @(Get-SynapseRegistration)
$actualStartup = (Get-ItemProperty -LiteralPath $runKey -Name $startupName -ErrorAction Ignore).$startupName
$installed = (Test-Path -LiteralPath $openRgb) -and (Test-Path -LiteralPath $helper) -and (Test-Path -LiteralPath $launcher)
$startupApproval = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Name $startupName -ErrorAction Ignore).$startupName
$startupEnabled = $actualStartup -eq $startup -and -not ($startupApproval -and $startupApproval[0] -eq 3)
$sourceReceipt = Join-Path $root 'helper-source.sha256'
$sourceCurrent = (Test-Path $sourceReceipt) -and ((Get-Content $sourceReceipt -Raw).Trim() -eq (Get-FileHash $source -Algorithm SHA256).Hash)
$launcherCurrent = (Test-Path $launcher) -and ((Get-FileHash $launcher -Algorithm SHA256).Hash -eq (Get-FileHash $launcherSource -Algorithm SHA256).Hash)
$detectorsCurrent = $false
if (Test-Path -LiteralPath $configPath) {
    try {
        $actualConfig = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
        $actualDetectors = $actualConfig.Detectors.detectors
        $detectorsCurrent = $actualDetectors -is [System.Collections.IDictionary]
        # OpenRGB removes detectors not compiled for Windows when saving its settings.
        foreach ($name in $configuration.Detectors) {
            if (-not $detectorsCurrent) { break }
            if (-not $actualDetectors.Contains($name) -or $actualDetectors[$name] -isnot [bool] -or -not $actualDetectors[$name]) { $detectorsCurrent = $false }
        }
        if ($detectorsCurrent) {
            foreach ($entry in $actualDetectors.GetEnumerator()) {
                if ($entry.Value -isnot [bool] -or ($entry.Value -and $entry.Key -cnotin $configuration.Detectors)) { $detectorsCurrent = $false; break }
            }
        }
        $detectorsCurrent = $detectorsCurrent -and $actualConfig.Server.default_host -eq '127.0.0.1' -and $actualConfig.Server.default_port -eq $configuration.Port -and $actualConfig.Server.all_controllers -eq $true
    } catch { $detectorsCurrent = $false }
}
$themeCurrent = $false
$themePath = Join-Path $root 'theme.json'
if (Test-Path $themePath) {
    try {
        $theme = Get-Content $themePath -Raw | ConvertFrom-Json
        $themeCurrent = $theme.BaseColor -eq $configuration.BaseColor -and $theme.PressColor -eq $configuration.PressColor -and $theme.DurationMilliseconds -eq $configuration.DurationMilliseconds -and $theme.Port -eq $configuration.Port
    } catch { $themeCurrent = $false }
}
$running = @(Get-Process RazerReactive -ErrorAction Ignore | Where-Object Path -EQ $helper).Count -gt 0
$result = [pscustomobject]@{
    Resource = 'RazerRgb'; Optional = $true
    State = if ($installed -and $startupEnabled -and $sourceCurrent -and $launcherCurrent -and $themeCurrent -and $detectorsCurrent) { 'compliant' } else { 'drift detected' }
    Version = $configuration.Version
    Startup = if ($startupEnabled) { 'user sign-in' } else { 'missing or disabled' }
    Synapse = if ($registration.Count) { 'installed' } else { 'absent' }
    Runtime = if ($running) { 'running' } else { 'stopped' }
    DetectorsCurrent = $detectorsCurrent
    LastConnection = if (Test-Path (Join-Path $root 'runtime-status.txt')) { Get-Content (Join-Path $root 'runtime-status.txt') -Raw } else { 'not started' }
    MouseLighting = 'unmanaged; Basilisk V3 Pro remains on Bluetooth'
}
if ($Json) { $result | ConvertTo-Json } else { $result | Format-List | Out-Host }
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
