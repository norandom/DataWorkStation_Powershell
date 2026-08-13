[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Stop', 'Status', 'Counters')]
    [string] $Action,

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string] $Name,

    [string[]] $Port,

    [string] $WorkingDirectory = (Get-Location).Path,
    [switch] $AllComponents
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}
if (-not (Get-Command pktmon.exe -CommandType Application -ErrorAction Ignore)) {
    throw 'PktMon is not available on this Windows installation.'
}

if ($Action -eq 'Status') { & pktmon.exe status; exit $LASTEXITCODE }
if ($Action -eq 'Counters') { & pktmon.exe counters; exit $LASTEXITCODE }
if (-not $Name) { throw "$Action requires a capture name." }

$capturePorts = @()
foreach ($value in @($Port)) {
    foreach ($item in @($value -split ',')) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $parsed = 0
        if (-not [int]::TryParse($item, [ref]$parsed) -or $parsed -lt 1 -or $parsed -gt 65535) {
            throw "Invalid capture port: $item"
        }
        $capturePorts += $parsed
    }
}
$capturePorts = @($capturePorts | Sort-Object -Unique)

$workingRoot = [IO.Path]::GetFullPath($WorkingDirectory)
if (-not (Test-Path -LiteralPath $workingRoot -PathType Container)) {
    throw "Working directory does not exist: $workingRoot"
}
$captureRoot = [IO.Path]::GetFullPath((Join-Path $workingRoot "pcap-$Name"))
if (-not $captureRoot.StartsWith($workingRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The resolved capture path is outside the working directory.'
}
$sessionFile = Join-Path $captureRoot 'session.json'
$etlFile = Join-Path $captureRoot 'capture.etl'
$pcapFile = Join-Path $captureRoot 'capture.pcapng'

if ($Action -eq 'Start') {
    if (Test-Path -LiteralPath $captureRoot) {
        throw "Capture directory already exists; choose another name: $captureRoot"
    }

    $status = & pktmon.exe status 2>&1
    $statusText = $status -join [Environment]::NewLine
    if ($LASTEXITCODE -eq 0 -and $statusText -notmatch '(?i)not running|is stopped') {
        throw "PktMon is already active. Stop the existing capture first.`n$($status -join [Environment]::NewLine)"
    }

    New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
    & pktmon.exe filter remove 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not reset PktMon capture filters.' }

    try {
        foreach ($number in $capturePorts) {
            & pktmon.exe filter add "port-$number" --port $number | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Could not add PktMon filter for port $number." }
        }
        if ($capturePorts.Count -gt 0) {
            & pktmon.exe filter add 'icmp-errors-v4' --transport-protocol ICMP | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Could not add the IPv4 ICMP diagnostic filter.' }
            & pktmon.exe filter add 'icmp-errors-v6' --transport-protocol ICMPv6 | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Could not add the IPv6 ICMP diagnostic filter.' }
        }

        $arguments = @('start', '--capture', '--pkt-size', '256', '--file-name', $etlFile, '--file-size', '64', '--log-mode', 'circular')
        if (-not $AllComponents) { $arguments += @('--comp', 'nics') }
        & pktmon.exe @arguments
        if ($LASTEXITCODE -ne 0) { throw "PktMon capture failed to start with exit code $LASTEXITCODE." }

        [pscustomobject]@{
            Name = $Name
            Status = 'Active'
            StartedUtc = (Get-Date).ToUniversalTime().ToString('o')
            CaptureDirectory = $captureRoot
            Ports = $capturePorts
            Components = if ($AllComponents) { 'All' } else { 'NICs' }
            PacketSizeBytes = 256
            MaximumSizeMiB = 64
        } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
    } catch {
        & pktmon.exe filter remove 2>$null | Out-Null
        throw
    }

    Write-Host "Packet capture started: $captureRoot"
    Write-Warning 'Keep the capture short. PktMon reports a 768 MiB logger memory reservation on this Windows build while recording.'
    Write-Host "Stop and convert it with: pcap-stop $Name"
    exit 0
}

if (-not (Test-Path -LiteralPath $sessionFile -PathType Leaf)) {
    throw "No capture session named '$Name' exists under: $workingRoot"
}
$session = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
if ($session.Status -ne 'Active') { throw "Capture '$Name' is not active." }

try {
    & pktmon.exe stop
    if ($LASTEXITCODE -ne 0) { throw "PktMon failed to stop with exit code $LASTEXITCODE." }
    if (-not (Test-Path -LiteralPath $etlFile -PathType Leaf)) { throw "PktMon did not create: $etlFile" }
    & pktmon.exe etl2pcap $etlFile --out $pcapFile
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pcapFile -PathType Leaf)) {
        throw 'PktMon stopped, but PCAPNG conversion failed. The ETL file has been retained.'
    }
} finally {
    & pktmon.exe filter remove 2>$null | Out-Null
}

$session.Status = 'Completed'
$session | Add-Member -NotePropertyName CompletedUtc -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
$session | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
Write-Host "Packet capture stopped: $pcapFile"
Write-Host "Read it with: pcap $Name"
