[CmdletBinding()]
param()
if ($PSVersionTable.PSEdition -eq 'Core') {
    & powershell.exe -NoProfile -File $PSCommandPath
    exit $LASTEXITCODE
}
function Test-EarlyOom {
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$assemblyPath = Join-Path ([IO.Path]::GetTempPath()) ('earlyoom-test-' + [guid]::NewGuid().ToString('N') + '.dll')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:library /r:System.ServiceProcess.dll /r:System.Management.dll /r:System.Web.Extensions.dll ('/out:' + $assemblyPath) (Join-Path $root 'scripts\memory-limits\MemoryLimits.cs') (Join-Path $root 'scripts\memory-limits\EarlyOom.cs')
if ($LASTEXITCODE -ne 0) { throw 'Guard compilation failed.' }
[void][Reflection.Assembly]::Load([IO.File]::ReadAllBytes($assemblyPath))
Remove-Item -LiteralPath $assemblyPath
$declaration = Import-PowerShellDataFile (Join-Path $root 'config\workload-memory-limits.psd1')
$policy = [DataWorkStation.EarlyOomPolicy]::new()
foreach ($name in $declaration.EarlyOom.Keys) { $policy.$name = $declaration.EarlyOom[$name] }
$policy.Validate()
$decision = [DataWorkStation.PressureDecision]::new($policy)
$sample = [DataWorkStation.MemoryPressureSnapshot]::new()
$sample.PhysicalTotalBytes = 32GB
$sample.PhysicalAvailableBytes = 2GB
$sample.CommitLimitBytes = 48GB
$sample.CommitUsedBytes = 44GB
if ($decision.Evaluate($sample, 0) -ne 'Pressure' -or $decision.Evaluate($sample, 2) -ne 'Pressure' -or $decision.Evaluate($sample, 3) -ne 'Ready') { throw 'Pressure must persist for three seconds before action.' }
$decision.ActionTaken(3)
if ($decision.Evaluate($sample, 4) -ne 'Cooldown' -or $decision.Evaluate($sample, 17) -ne 'Cooldown' -or $decision.Evaluate($sample, 18) -ne 'Ready') { throw 'Repeated actions must respect the cooldown.' }
$sample.CommitLimitBytes = 64GB
if ($decision.Evaluate($sample, 19) -ne 'Normal') { throw 'Pagefile/commit growth must update the pressure threshold immediately.' }
$sample.CommitLimitBytes = 48GB
if ($decision.Evaluate($sample, 20) -ne 'Pressure') { throw 'Recovered pressure must reset the sustained-pressure timer.' }
$sample.PhysicalAvailableBytes = 20GB
if ($decision.Evaluate($sample, 21) -ne 'Normal') { throw 'Ordinary commit pressure alone must not act.' }
$sample.CommitUsedBytes = 47GB
if ($decision.Evaluate($sample, 22) -ne 'Pressure' -or $decision.Evaluate($sample, 25) -ne 'Ready') { throw 'Critical commit exhaustion must act even when physical pages are still available.' }
$decision.ResetPressure()
if ($decision.Evaluate($sample, 30) -ne 'Pressure') { throw 'Telemetry failures must reset the sustained-pressure timer.' }
$sample.CommitLimitBytes = 0
$rejected = $false
try { [void]$decision.Evaluate($sample, 31) } catch { $rejected = $true }
if (-not $rejected) { throw 'Invalid telemetry must fail closed.' }
$policy.TerminationExecutables = @('explorer.exe')
$rejected = $false
try { $policy.Validate() } catch { $rejected = $true }
if (-not $rejected) { throw 'Desktop/AI host processes must not become termination targets.' }
$policy.TerminationExecutables = $declaration.EarlyOom.TerminationExecutables
$policy.Mode = 'Observe'
$observed = [DataWorkStation.EarlyOomGuard]::ReadMemory()
if ($observed.PhysicalTotalBytes -eq 0 -or $observed.CommitLimitBytes -eq 0) { throw 'Native memory observation failed.' }

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('earlyoom-events-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $guard = [DataWorkStation.EarlyOomGuard]::new($policy, $fixture)
    $guard.Tick([Collections.Generic.Dictionary[string,IntPtr]]::new())
    $log = Join-Path $fixture 'earlyoom.jsonl'
    $record = Get-Content -LiteralPath $log -TotalCount 1 | ConvertFrom-Json
    if ($record.mode -ne 'Observe' -or $record.schemaVersion -ne 1 -or -not $record.memory.CommitLimitBytes -or -not $record.thresholds.CooldownSeconds) { throw 'Audit events need mode, telemetry, thresholds and schema.' }
    # Recorded fixtures exercise rotation, malformed trailing records, UTC filtering and JSON output.
    $old = @{ schemaVersion=1; utc='2026-01-01T00:00:00Z'; action='would-terminate'; mode='Observe'; candidate=@{pid=42;name='python.exe'} }
    $old | ConvertTo-Json -Compress | Set-Content -LiteralPath ($log + '.previous')
    Add-Content -LiteralPath $log -Value '{incomplete'
    $reader = Join-Path $root 'scripts\Get-WorkloadMemoryDiagnostics.ps1'
    $result = (& pwsh -NoProfile -File $reader -Action Events -Directory $fixture -Last 2 -SinceUtc '2026-01-02T00:00:00Z' -Json) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $result.MalformedLines -ne 1 -or $result.Events.Count -ne 1 -or $result.Events[0].action -ne 'sample') { throw ('Event query must report malformed tails and filter across rotation: ' + ($result | ConvertTo-Json -Depth 8 -Compress)) }
} finally {
    foreach ($name in @('earlyoom.jsonl', 'earlyoom.jsonl.previous')) { $path = Join-Path $fixture $name; if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
    [IO.Directory]::Delete($fixture)
}
Write-Output 'PASS: dynamic thresholds, commit emergency, cooldown, recovery, fail-closed telemetry, candidate restrictions and rotated event queries. No workloads were terminated.'
}
Test-EarlyOom
