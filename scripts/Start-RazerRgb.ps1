[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'DataWorkStation\RazerRgb'
$settings = Get-Content -LiteralPath (Join-Path $root 'theme.json') -Raw | ConvertFrom-Json
$openRgb = Join-Path $root 'OpenRGB-1.0\OpenRGB Windows 64-bit\OpenRGB.exe'
$helper = Join-Path $root 'RazerReactive.exe'
foreach ($path in @($openRgb, $helper)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing $path; run Set-RazerRgbState.ps1 -Mode Ensure." }
}
$existing = @(Get-Process OpenRGB -ErrorAction Ignore | Where-Object Path -EQ $openRgb)
if (-not $existing) {
    Start-Process -FilePath $openRgb -ArgumentList @('--config', ('"' + (Join-Path $root 'config') + '"'), '--noautoconnect', '--server', '--server-host', '127.0.0.1', '--server-port', $settings.Port) -WindowStyle Hidden | Out-Null
}
if (-not (Get-Process RazerReactive -ErrorAction Ignore | Where-Object Path -EQ $helper)) {
    Start-Process -FilePath $helper -ArgumentList @($settings.Port, $settings.DurationMilliseconds, $settings.BaseColor, $settings.PressColor) -WindowStyle Hidden | Out-Null
}
