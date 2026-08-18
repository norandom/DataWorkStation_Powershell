[CmdletBinding()]
param([Parameter(Mandatory = $true, Position = 0)][string] $Path)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
$wpa = 'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\wpa.exe'
$speedscope = Join-Path $env:APPDATA 'npm\speedscope.cmd'
$dotnetTrace = Join-Path $env:USERPROFILE '.dotnet\tools\dotnet-trace.exe'
$qViewCandidates = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\qView\qView.exe'),
    'C:\Program Files\qView\qView.exe'
)

if ($resolved -like '*.etl') {
    if (-not (Test-Path -LiteralPath $wpa -PathType Leaf)) { throw "WPA is missing: $wpa" }
    Start-Process -FilePath $wpa -ArgumentList @(('"{0}"' -f $resolved))
    return
}

if ($resolved -like '*.nettrace') {
    if (-not (Test-Path -LiteralPath $dotnetTrace -PathType Leaf)) { throw "dotnet-trace is missing: $dotnetTrace" }
    $base = [IO.Path]::Combine((Split-Path -Parent $resolved), [IO.Path]::GetFileNameWithoutExtension($resolved))
    & $dotnetTrace convert $resolved --format Speedscope --output $base
    if ($LASTEXITCODE -ne 0) { throw "dotnet-trace conversion failed: $LASTEXITCODE" }
    $resolved = "$base.speedscope.json"
}

if ($resolved -like '*.speedscope.json') {
    if (-not (Test-Path -LiteralPath $speedscope -PathType Leaf)) { throw "Speedscope is missing: $speedscope" }
    Start-Process -FilePath $speedscope -ArgumentList @(('"{0}"' -f $resolved))
    return
}

if ($resolved -like '*.svg') {
    $qView = $qViewCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $qView) { throw 'qView is missing. Apply the base Packages desired state before opening SVG profiles.' }
    Start-Process -FilePath $qView -ArgumentList @(('"{0}"' -f $resolved))
    return
}

if ($resolved -like '*.html' -or $resolved -like '*.htm') {
    Start-Process -FilePath $resolved
    return
}

throw "No profile viewer is registered for: $resolved"
