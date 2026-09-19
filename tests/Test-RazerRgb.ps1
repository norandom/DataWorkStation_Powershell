[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('razer-rgb-test-' + [guid]::NewGuid().ToString('N') + '.dll')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:library /reference:System.Windows.Forms.dll ('/out:' + $temp) (Join-Path $root 'scripts\razer-rgb\RazerReactive.cs')
if ($LASTEXITCODE -ne 0) { throw 'Helper compilation failed.' }
[void][Reflection.Assembly]::Load([IO.File]::ReadAllBytes($temp))
Remove-Item -LiteralPath $temp
$blue = [uint32]0xff0000
$white = [uint32]0xffffff
if ([WorkstationRgb.Effect]::Color(3000, 1000, $blue, $white) -ne $white) { throw 'Press must turn white immediately.' }
if ([WorkstationRgb.Effect]::Color(3000, 2999, $blue, $white) -ne $white) { throw 'White must last the full two seconds.' }
if ([WorkstationRgb.Effect]::Color(3000, 3000, $blue, $white) -ne $blue) { throw 'Deadline must return to blue.' }
if ([WorkstationRgb.Effect]::Color(0, 1000, $blue, $white) -ne $blue) { throw 'Untouched keys must remain blue.' }
if ([WorkstationRgb.Effect]::KeyName(0x15, $false) -ne 'Y') { throw 'Physical mapping must not swap German Y/Z positions.' }
if ([WorkstationRgb.Effect]::KeyName(0x1d, $true) -ne 'Right Control') { throw 'Extended modifiers must map independently.' }
if (-not [WorkstationRgb.Effect]::Matches('Key: \ (ISO)', [WorkstationRgb.Effect]::KeyName(86, $false))) { throw 'ISO extra key must map.' }
if (-not [WorkstationRgb.Effect]::Matches('Key: \ (ANSI)', [WorkstationRgb.Effect]::KeyName(43, $false))) { throw 'ANSI backslash must map.' }
$catalog = Import-PowerShellDataFile (Join-Path $root 'config\workstation-modules.psd1')
$module = $catalog.Modules | Where-Object Name -EQ RazerRgb
if (-not $module -or $module.Default -or $module.SupportedModes -contains 'Reinitialize') { throw 'Module must remain optional and non-destructive.' }
$detectors = Get-Content (Join-Path $root 'config\openrgb-1.0-detectors.json') -Raw | ConvertFrom-Json
$settings = Import-PowerShellDataFile (Join-Path $root 'config\razer-rgb.psd1')
foreach ($name in $settings.Detectors) { if ($name -notin $detectors) { throw "Unknown detector $name" } }

# Exercise the read-only resource against private fixtures; never start RGB or input capture.
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('razer-rgb-state-test-' + [guid]::NewGuid().ToString('N'))
$fixtureConfig = Join-Path $fixtureRoot 'DataWorkStation\RazerRgb\config'
$fixturePath = Join-Path $fixtureConfig 'OpenRGB.json'
$savedLocalAppData = $env:LOCALAPPDATA
try {
    New-Item -ItemType Directory -Path $fixtureConfig -Force | Out-Null
    $env:LOCALAPPDATA = $fixtureRoot
    $expectedDetectors = @{}
    foreach ($name in $detectors) { $expectedDetectors[$name] = $name -in $settings.Detectors }
    $fixture = @{ Detectors = @{ detectors = $expectedDetectors }; Server = @{ all_controllers = $true; default_host = '127.0.0.1'; default_port = $settings.Port } }
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixturePath
    $resource = Join-Path $root 'scripts\Set-RazerRgbState.ps1'
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if (-not $result.DetectorsCurrent) { throw 'Declared keyboard-only detector settings must pass inspection without a connected mouse controller.' }
    if ($result.Runtime -ne 'stopped' -or (Test-Path (Join-Path $fixtureRoot 'DataWorkStation\RazerRgb\RazerReactive.exe'))) { throw 'Test must not install or start the helper.' }

    $expectedDetectors.Remove('Linux LED')
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixturePath
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if (-not $result.DetectorsCurrent) { throw 'Omitted disabled platform-specific detectors must not cause drift.' }

    $expectedDetectors.Remove('Razer Huntsman Mini')
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixturePath
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if ($result.DetectorsCurrent) { throw 'The declared keyboard detector must remain enabled.' }
    $expectedDetectors['Razer Huntsman Mini'] = $true

    $expectedDetectors['Razer Basilisk V3 Pro (Wireless)'] = $true
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixturePath
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if ($result.DetectorsCurrent) { throw 'An enabled mouse detector must be reported as drift.' }
    $expectedDetectors['Razer Basilisk V3 Pro (Wireless)'] = $false
    $fixture.Server.default_host = '0.0.0.0'
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $fixturePath
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if ($result.DetectorsCurrent) { throw 'A non-local SDK endpoint must be reported as drift.' }

    Set-Content -LiteralPath $fixturePath -Value '{broken'
    $result = (& pwsh -NoProfile -File $resource -Mode Test -Json) | ConvertFrom-Json
    if ($result.DetectorsCurrent) { throw 'Malformed detector configuration must be reported as drift.' }
} finally {
    $env:LOCALAPPDATA = $savedLocalAppData
    if (Test-Path -LiteralPath $fixturePath) { Remove-Item -LiteralPath $fixturePath }
    # Only remove the known empty fixture directories, without recursive deletion.
    foreach ($directory in @($fixtureConfig, (Split-Path $fixtureConfig), (Join-Path $fixtureRoot 'DataWorkStation'), $fixtureRoot)) {
        if (Test-Path -LiteralPath $directory) { [IO.Directory]::Delete($directory) }
    }
}
Write-Output 'Razer RGB: compiler, timer boundaries, physical key mappings, optional module, and read-only configuration drift checks passed.'
