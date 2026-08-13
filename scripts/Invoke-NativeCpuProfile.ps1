[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Start', 'Stop', 'Cancel', 'Status', 'Open')]
    [string] $Action,

    [Parameter(Position = 1)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string] $Name,

    [string] $WorkingDirectory = (Get-Location).Path,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$wptRoot = 'C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit'
$wpr = Join-Path $wptRoot 'wpr.exe'
$wpa = Join-Path $wptRoot 'wpa.exe'
if (-not (Test-Path -LiteralPath $wpr -PathType Leaf)) { throw "WPT recorder is missing: $wpr" }

function Write-Result([object] $Value) {
    if ($Json) { $Value | ConvertTo-Json -Depth 5 } else { $Value }
}

if ($Action -eq 'Status' -and -not $Name) {
    $root = [IO.Path]::GetFullPath($WorkingDirectory)
    $rows = Get-ChildItem -LiteralPath $root -Directory -Filter 'profile-native-*' -ErrorAction Ignore | ForEach-Object {
        $stateFile = Join-Path $_.FullName 'state.json'
        if (Test-Path -LiteralPath $stateFile) { Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json }
    }
    Write-Result @($rows)
    return
}

if (-not $Name) { throw "Name is required for action '$Action'." }
$captureRoot = [IO.Path]::GetFullPath((Join-Path $WorkingDirectory "profile-native-$Name"))
$stateFile = Join-Path $captureRoot 'state.json'
$etlFile = Join-Path $captureRoot 'cpu.etl'

if ($Action -eq 'Start') {
    if (Test-Path -LiteralPath $stateFile) {
        $existing = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        if ($existing.Active) { throw "Native profile '$Name' is already marked active." }
    }
    New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
    $instance = 'PSW_CPU_' + ($Name -replace '[^A-Za-z0-9_]', '_')
    & sudo.exe $wpr -start CPU -filemode -instancename $instance
    if ($LASTEXITCODE -ne 0) { throw "WPR failed to start: $LASTEXITCODE" }
    $state = [ordered]@{
        Name = $Name
        Kind = 'NativeCPU'
        Active = $true
        Instance = $instance
        Started = (Get-Date).ToString('o')
        Stopped = $null
        Trace = $etlFile
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    Write-Result ([pscustomobject]$state)
    return
}

if (-not (Test-Path -LiteralPath $stateFile -PathType Leaf)) { throw "Profile state not found: $stateFile" }
$state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json

switch ($Action) {
    'Stop' {
        if (-not $state.Active) { throw "Native profile '$Name' is not active." }
        & sudo.exe $wpr -stop $etlFile "Native CPU profile: $Name" -compress -instancename $state.Instance
        if ($LASTEXITCODE -ne 0) { throw "WPR failed to stop and save the trace: $LASTEXITCODE" }
        $state.Active = $false
        $state.Stopped = (Get-Date).ToString('o')
        $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
        Write-Result $state
    }
    'Cancel' {
        if ($state.Active) {
            & sudo.exe $wpr -cancel -instancename $state.Instance
            if ($LASTEXITCODE -ne 0) { throw "WPR failed to cancel: $LASTEXITCODE" }
            $state.Active = $false
            $state.Stopped = (Get-Date).ToString('o')
            $state | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
        }
        Write-Result $state
    }
    'Status' { Write-Result $state }
    'Open' {
        if (-not (Test-Path -LiteralPath $etlFile -PathType Leaf)) { throw "Trace not found: $etlFile" }
        if (-not (Test-Path -LiteralPath $wpa -PathType Leaf)) { throw "WPA is missing: $wpa" }
        Start-Process -FilePath $wpa -ArgumentList @(('"{0}"' -f $etlFile))
        Write-Result ([pscustomobject]@{ Viewer='WPA'; Trace=$etlFile })
    }
}
