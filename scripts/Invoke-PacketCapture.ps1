[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Stop', 'Status', 'Counters')]
    [string] $Action,

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')]
    [string] $Name,

    [string[]] $Port,

    [string] $WorkingDirectory,
    [string] $ConfigurationPath,
    [switch] $AllComponents,
    [ValidateRange(5, 600)][int] $Seconds = 90,
    [ValidateRange(16, 1024)][int] $MaxSizeMiB = 64,
    [ValidateRange(0, 65535)][int] $PacketSizeBytes = 256,
    [switch] $Plan,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) { $WorkingDirectory = (Import-WorkstationConfiguration -ConfigurationPath $ConfigurationPath).Paths.Traces }
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $Plan -and -not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}
if (-not (Get-Command pktmon.exe -CommandType Application -ErrorAction Ignore)) {
    throw 'PktMon is not available on this Windows installation.'
}

if ($Plan -and $Action -ne 'Start') { throw 'Plan is only available for Start.' }
if ($Action -in @('Status', 'Counters')) {
    $nativeText = @(& pktmon.exe $Action.ToLowerInvariant() 2>&1)
    $nativeCode = $LASTEXITCODE
    if ($Json) { [pscustomobject]@{ Action = $Action; ExitCode = $nativeCode; NativeText = $nativeText } | ConvertTo-Json -Depth 3 }
    else { $nativeText }
    exit $nativeCode
}
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
if ($Plan) {
    $planned = [pscustomobject]@{ Name = $Name; Directory = (Join-Path $workingRoot "pcap-$Name"); Seconds = $Seconds; MaxSizeMiB = $MaxSizeMiB; PacketSizeBytes = $PacketSizeBytes; Ports = $capturePorts; AllComponents = [bool] $AllComponents; RequiresAdministrator = $true; ExistingFilters = 'Refuse unless empty; never overwrite external filters' }
    if ($Json) { $planned | ConvertTo-Json } else { $planned | Format-List }
    return
}
if ($Action -eq 'Start' -and -not (Test-Path -LiteralPath $workingRoot)) { New-Item -ItemType Directory -Path $workingRoot -Force | Out-Null }
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

$captureMutex = [Threading.Mutex]::new($false, 'Global\PowerShellWorkstationPktMon')
$lockTaken = $false
try {
try { $lockTaken = $captureMutex.WaitOne(30000) } catch [Threading.AbandonedMutexException] { $lockTaken = $true }
if (-not $lockTaken) { throw 'Another managed PktMon operation is in progress.' }
if ($Action -eq 'Start') {
    if (Test-Path -LiteralPath $captureRoot) {
        throw "Capture directory already exists; choose another name: $captureRoot"
    }

    $status = & pktmon.exe status 2>&1
    $statusText = $status -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $statusText -notmatch '(?i)not running|is stopped') {
        throw "PktMon is already active. Stop the existing capture first.`n$($status -join [Environment]::NewLine)"
    }

    $existingFilters = @(& pktmon.exe filter list 2>&1) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0 -or $existingFilters -notmatch '(?i)^\s*(?:No (?:packet )?filters|There are no (?:packet )?filters)') {
        throw 'Existing or unrecognized PktMon filters; leave them intact and resolve their ownership before capturing.'
    }
    New-Item -ItemType Directory -Path $captureRoot -Force | Out-Null
    $captureStarted = $false
    $ownedFilters = $null

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

        $ownedFilters = @(& pktmon.exe filter list 2>&1) -join [Environment]::NewLine
        if ($LASTEXITCODE -ne 0) { throw 'Could not snapshot capture filters.' }
        $arguments = @('start', '--capture', '--pkt-size', "$PacketSizeBytes", '--file-name', $etlFile, '--file-size', "$MaxSizeMiB", '--log-mode', 'circular')
        if (-not $AllComponents) { $arguments += @('--comp', 'nics') }
        & pktmon.exe @arguments
        if ($LASTEXITCODE -ne 0) { throw "PktMon capture failed to start with exit code $LASTEXITCODE." }
        $captureStarted = $true

        [pscustomobject]@{
            Name = $Name
            Status = 'Active'
            StartedUtc = (Get-Date).ToUniversalTime().ToString('o')
            CaptureDirectory = $captureRoot
            Ports = $capturePorts
            Components = if ($AllComponents) { 'All' } else { 'NICs' }
            PacketSizeBytes = $PacketSizeBytes
            MaximumSizeMiB = $MaxSizeMiB
            Seconds = $Seconds
            OwnedFilters = $ownedFilters
        } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
        $worker = Join-Path $PSScriptRoot 'Stop-PacketCaptureAfterDelay.ps1'
        $shellPath = (Get-Process -Id $PID).Path
        Start-Process -FilePath $shellPath -ArgumentList @('-NoLogo', '-NoProfile', '-File', ('"' + $worker + '"'), '-SessionFile', ('"' + $sessionFile + '"')) -WindowStyle Hidden -ErrorAction Stop | Out-Null
    } catch {
        if ($captureStarted) {
            $failedStatus = @(& pktmon.exe status 2>&1) -join [Environment]::NewLine
            if ($failedStatus.IndexOf($etlFile, [StringComparison]::OrdinalIgnoreCase) -ge 0) { & pktmon.exe stop 2>$null | Out-Null }
        }
        $failedFilters = @(& pktmon.exe filter list 2>&1) -join [Environment]::NewLine
        if ($null -ne $ownedFilters -and $failedFilters -ceq $ownedFilters) { & pktmon.exe filter remove 2>$null | Out-Null }
        throw
    }

    if ($Json) { Get-Content -LiteralPath $sessionFile -Raw }
    else { Write-Host "Packet capture started: $captureRoot; automatic stop in $Seconds seconds. Early stop: pcap-stop $Name" }
    exit 0
}

if (-not (Test-Path -LiteralPath $sessionFile -PathType Leaf)) {
    throw "No capture session named '$Name' exists under: $workingRoot"
}
$session = Get-Content -LiteralPath $sessionFile -Raw | ConvertFrom-Json
if ($session.Status -eq 'Completed') {
    if ($Json) { $session | ConvertTo-Json -Depth 4 } else { Write-Host "Capture already completed: $pcapFile" }
    return
}

try {
    if ($session.Status -eq 'Active') {
        $activeStatus = @(& pktmon.exe status 2>&1) -join [Environment]::NewLine
        if ($LASTEXITCODE -ne 0 -or $activeStatus.IndexOf($etlFile, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw 'Cannot prove ownership of active PktMon capture; refusing to stop it.'
        }
        & pktmon.exe stop | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "PktMon failed to stop with exit code $LASTEXITCODE." }
        $session.Status = 'Stopped'
        $session | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
    }
    if (-not (Test-Path -LiteralPath $etlFile -PathType Leaf)) { throw "PktMon did not create: $etlFile" }
    & pktmon.exe etl2pcap $etlFile --out $pcapFile | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pcapFile -PathType Leaf)) {
        throw 'PktMon stopped, but PCAPNG conversion failed. The ETL file has been retained.'
    }
} finally {
    $currentFilters = @(& pktmon.exe filter list 2>&1) -join [Environment]::NewLine
    $cleanupStatus = @(& pktmon.exe status 2>&1) -join [Environment]::NewLine
    $stoppedForCleanup = $LASTEXITCODE -eq 0 -and $cleanupStatus -match '(?i)not running|is stopped'
    if ($stoppedForCleanup -and $session.Status -ne 'Active' -and $session.PSObject.Properties['OwnedFilters'] -and $currentFilters -ceq $session.OwnedFilters) {
        & pktmon.exe filter remove 2>$null | Out-Null
    }
}

$session.Status = 'Completed'
$session | Add-Member -NotePropertyName CompletedUtc -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
$session | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $sessionFile -Encoding UTF8
if ($Json) { $session | ConvertTo-Json -Depth 4 }
else { Write-Host "Packet capture stopped: $pcapFile"; Write-Host "Read it with: pcap $Name" }
} finally {
    if ($lockTaken) { $captureMutex.ReleaseMutex() }
    $captureMutex.Dispose()
}
