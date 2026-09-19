[CmdletBinding()]
param(
    [ValidateSet('Status', 'Plan', 'Events', 'Candidates')][string] $Action = 'Status',
    [ValidateRange(1, 2000)][int] $Last = 100,
    [datetimeoffset] $SinceUtc = [datetimeoffset]::MinValue,
    [string] $Directory = (Join-Path $env:ProgramData 'DataWorkStationMemoryLimits'),
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
$policy = Import-PowerShellDataFile (Join-Path (Split-Path -Parent $PSScriptRoot) 'config\workload-memory-limits.psd1')
if ($Action -eq 'Candidates') {
    $installDirectory = Join-Path $env:ProgramFiles $policy.ServiceName
    $executable = Join-Path $installDirectory 'MemoryLimits.exe'
    $installedPolicy = Join-Path $installDirectory 'policy.json'
    if (-not (Test-Path -LiteralPath $executable) -or -not (Test-Path -LiteralPath $installedPolicy)) { throw 'Install the declared memory service before inspecting candidates.' }
    $result = (& $executable --guard-candidates $installedPolicy) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or -not $result.observationOnly) { throw 'Candidate inspection failed; reconcile the installed memory service.' }
    if ($Json) { $result | ConvertTo-Json -Depth 8 }
    else {
        Write-Host 'Read-only candidates under the installed policy, ranked by private bytes. No action is requested.'
        Write-Host 'Run this command with sudo for the service account visibility; inaccessible processes are excluded.'
        $result.candidates | Select-Object pid,name,session,@{n='Private GiB';e={[math]::Round($_.privateBytes / 1GB, 2)}},creationFileTimeUtc | Format-Table | Out-Host
        $result.excludedCounts | Format-List | Out-Host
    }
    return
}
if ($Action -eq 'Events') {
    $events = [Collections.Generic.List[object]]::new()
    $malformed = 0
    $paths = @((Join-Path $Directory 'earlyoom.jsonl.previous'), (Join-Path $Directory 'earlyoom.jsonl'))
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        foreach ($line in Get-Content -LiteralPath $path -Tail $Last) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $row = $line | ConvertFrom-Json
                if ($row.schemaVersion -ne 1 -or -not $row.utc -or -not $row.action) { throw 'Unrecognized event schema.' }
                $timestamp = if ($row.utc -is [datetime]) { [datetimeoffset]$row.utc } else { [datetimeoffset]::Parse([string]$row.utc, [Globalization.CultureInfo]::InvariantCulture) }
                if ($timestamp -ge $SinceUtc) { $events.Add($row) }
            } catch { $malformed++ }
        }
    }
    $result = [pscustomobject]@{ Directory = $Directory; Coverage = 'Bounded tail of current and previous logs'; MalformedLines = $malformed; Events = @($events | Sort-Object { [datetimeoffset]$_.utc } | Select-Object -Last $Last) }
    if ($Json) { $result | ConvertTo-Json -Depth 12 }
    else {
        Write-Host "Early-OOM events: $($result.Events.Count); malformed/incomplete lines: $malformed"
        $result.Events | Select-Object utc,action,mode,@{n='Process';e={$_.candidate.name}},@{n='PID';e={$_.candidate.pid}},@{n='RAM available %';e={[math]::Round($_.memory.PhysicalAvailablePercent,2)}},@{n='Commit remaining %';e={[math]::Round($_.memory.CommitHeadroomPercent,2)}},detail | Format-Table -Wrap | Out-Host
    }
    return
}
$runtimePath = Join-Path $Directory 'status.json'
$runtime = if (Test-Path -LiteralPath $runtimePath) { Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json } else { $null }
$os = Get-CimInstance Win32_OperatingSystem
$memory = Get-CimInstance Win32_PerfRawData_PerfOS_Memory
$physical = [uint64]$os.TotalVisibleMemorySize * 1KB
$commitLimit = [uint64]$memory.CommitLimit
$pagefiles = @(Get-CimInstance Win32_PageFileUsage | Select-Object AllocatedBaseSize,CurrentUsage)
$result = [pscustomobject]@{
    Action = $Action
    Policy = $policy.EarlyOom
    PhysicalTotalGiB = [math]::Round($physical / 1GB, 2)
    PagefileAllocatedGiB = [math]::Round(($pagefiles | Measure-Object AllocatedBaseSize -Sum).Sum / 1024, 2)
    CommitLimitGiB = [math]::Round($commitLimit / 1GB, 2)
    AvailablePhysicalGiB = [math]::Round([uint64]$memory.AvailableBytes / 1GB, 2)
    CommitHeadroomGiB = [math]::Round([math]::Max([double]0, [double]$commitLimit - [double]$memory.CommittedBytes) / 1GB, 2)
    PhysicalThresholdGiB = [math]::Round($physical * $policy.EarlyOom.AvailablePhysicalPercent / 100 / 1GB, 2)
    CommitThresholdGiB = [math]::Round($commitLimit * $policy.EarlyOom.CommitHeadroomPercent / 100 / 1GB, 2)
    EmergencyCommitThresholdGiB = [math]::Round($commitLimit * $policy.EarlyOom.EmergencyCommitHeadroomPercent / 100 / 1GB, 2)
    RuntimeFresh = [bool]($runtime -and ([datetime]::UtcNow - [datetime]$runtime.utc).TotalSeconds -lt 20)
    Runtime = $runtime.earlyOom
    EventsPath = Join-Path $Directory 'earlyoom.jsonl'
}
if ($Json) { $result | ConvertTo-Json -Depth 10 } else { $result | Format-List | Out-Host }
