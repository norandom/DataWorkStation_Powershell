[CmdletBinding()]
param(
    [switch] $Run,
    [switch] $ConfirmCleanup,
    [ValidateRange(0, 3650)][int] $RetentionDays,
    [switch] $Json,
    [string] $ConfigurationPath,
    [Parameter(DontShow = $true)][switch] $PassThru
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
$configuration = Import-WorkstationConfiguration -RepositoryRoot $repositoryRoot -ConfigurationPath $ConfigurationPath
if (-not $PSBoundParameters.ContainsKey('RetentionDays')) { $RetentionDays = [int] $configuration.Cleanup.Traces.RetentionDays }
$traceRoot = [IO.Path]::GetFullPath([string] $configuration.Paths.Traces)
$traceRootDrive = [IO.Path]::GetPathRoot($traceRoot)
if ($traceRoot.TrimEnd('\') -ieq $traceRootDrive.TrimEnd('\')) { throw 'The trace cleanup root cannot be a drive root.' }

function Test-ActiveTraceDirectory {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)
    foreach ($stateName in @('state.json', 'session.json')) {
        $statePath = Join-Path $LiteralPath $stateName
        if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { continue }
        try { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -ErrorAction Stop } catch { return $true }
        if (($state.PSObject.Properties.Name -contains 'Active' -and [bool] $state.Active) -or
            ($state.PSObject.Properties.Name -contains 'Status' -and [string] $state.Status -eq 'Active')) { return $true }
    }
    $false
}

$cutoff = [DateTime]::UtcNow.AddDays(-$RetentionDays)
$candidates = [Collections.Generic.List[object]]::new()
$activeSkipped = 0
$recentSkipped = 0
if (Test-Path -LiteralPath $traceRoot -PathType Container) {
    foreach ($item in @(Get-ChildItem -LiteralPath $traceRoot -Force)) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $activeSkipped++; continue }
        if ($item.PSIsContainer -and (Test-ActiveTraceDirectory -LiteralPath $item.FullName)) { $activeSkipped++; continue }
        $latestWrite = if ($item.PSIsContainer) {
            $latest = Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -ErrorAction Ignore | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            if ($latest) { $latest.LastWriteTimeUtc } else { $item.LastWriteTimeUtc }
        } else { $item.LastWriteTimeUtc }
        if ($latestWrite -gt $cutoff) { $recentSkipped++; continue }
        $bytes = if ($item.PSIsContainer) {
            [int64] ((Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force -ErrorAction Ignore | Measure-Object Length -Sum).Sum)
        } else { [int64] $item.Length }
        $candidates.Add([pscustomobject]@{ Name = $item.Name; Path = $item.FullName; Kind = if ($item.PSIsContainer) { 'Directory' } else { 'File' }; LastWriteTimeUtc = $latestWrite.ToString('o'); Bytes = $bytes })
    }
}

$result = [pscustomobject][ordered]@{
    SchemaVersion = 1
    Action = if ($Run) { 'Run' } else { 'Plan' }
    TraceRoot = $traceRoot
    RetentionDays = $RetentionDays
    CutoffUtc = $cutoff.ToString('o')
    Candidates = @($candidates)
    CandidateCount = $candidates.Count
    CandidateBytes = [int64] (($candidates | Measure-Object Bytes -Sum).Sum)
    ActiveSkipped = $activeSkipped
    RecentSkipped = $recentSkipped
    DeletedCount = 0
    DeletedBytes = 0L
    Succeeded = $true
    Detail = if ($Run) { 'Trace cleanup completed.' } else { 'No trace files were changed.' }
}

function Write-TraceCleanupResult {
    param([object] $Value)
    if ($PassThru) { $Value; return }
    if ($Json) { $Value | ConvertTo-Json -Depth 7; return }
    Write-Host "Trace cleanup $($Value.Action.ToLowerInvariant()): $($Value.TraceRoot)"
    $Value.Candidates | Select-Object Name, Kind, LastWriteTimeUtc, Bytes | Format-Table -AutoSize
    Write-Host "$($Value.CandidateCount) candidate(s), $($Value.CandidateBytes) byte(s); $($Value.ActiveSkipped) active and $($Value.RecentSkipped) recent item(s) preserved."
    Write-Host $Value.Detail
    if (-not $Run -and $Value.CandidateCount -gt 0) { Write-Host 'Run the reviewed cleanup with: cleanup-traces -Run -ConfirmCleanup' }
}

if (-not $Run) { Write-TraceCleanupResult $result; return }
if (-not $ConfirmCleanup) { throw 'Trace deletion requires -ConfirmCleanup. Run without -Run to review candidates.' }
foreach ($candidate in @($candidates)) {
    $resolved = [IO.Path]::GetFullPath([string] $candidate.Path)
    if (-not $resolved.StartsWith($traceRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to delete a trace candidate outside the configured root: $resolved"
    }
    if (Test-Path -LiteralPath $resolved) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
        $result.DeletedCount++
        $result.DeletedBytes += [int64] $candidate.Bytes
    }
}
$result.Detail = "Deleted $($result.DeletedCount) expired trace item(s); active, recent, and event-log archives were preserved."
Write-TraceCleanupResult $result
