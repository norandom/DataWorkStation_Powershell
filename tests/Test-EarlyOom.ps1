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
$sample.CommitUsedBytes = 45GB
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
$policy.ExcludedExecutables = @('*.exe')
$rejected = $false
try { $policy.Validate() } catch { $rejected = $true }
if (-not $rejected) { throw 'Exclusions must be exact executable names.' }
$policy.ExcludedExecutables = $declaration.EarlyOom.ExcludedExecutables
$facts = [DataWorkStation.CandidateFacts]::new()
$facts.Pid = 12345; $facts.Created = 123456; $facts.Session = 1
$facts.OwnerSid = 'S-1-5-21-111-222-333-1001'; $facts.PrivateBytes = 1GB
foreach ($name in @('python.exe', 'dotnet.exe', 'java.exe', 'chrome.exe', 'codex.exe', 'unknown-worker.exe')) {
    $facts.ImagePath = 'C:\Apps\' + $name
    if ($null -ne [DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $facts, 999, 'C:\Windows')) { throw "Ordinary applications must qualify without inclusion or job membership: $name" }
}
foreach ($name in $policy.ExcludedExecutables) {
    $facts.ImagePath = 'C:\Apps\' + $name.ToUpperInvariant()
    if ([DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $facts, 999, 'C:\Windows') -ne 'excluded-executable') { throw "Configured protection failed: $name" }
}
$facts.ImagePath = 'C:\WINDOWS\System32\arbitrary.exe'
if ([DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $facts, 999, 'C:\Windows') -ne 'windows-image') { throw 'Windows images must always be protected.' }
$facts.ImagePath = 'C:\WindowsTools\arbitrary.exe'
if ($null -ne [DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $facts, 999, 'C:\Windows')) { throw 'Windows path protection must respect directory boundaries.' }
$cases = @(
    @{ Property='Session'; Value=0; Reason='service-session' }
    @{ Property='Critical'; Value=$true; Reason='critical' }
    @{ Property='OwnerSid'; Value='S-1-5-18'; Reason='service-account' }
    @{ Property='OwnerSid'; Value='S-1-5-19'; Reason='service-account' }
    @{ Property='OwnerSid'; Value='S-1-5-20'; Reason='service-account' }
    @{ Property='OwnerSid'; Value='S-1-5-80-123'; Reason='service-account' }
    @{ Property='OwnerSid'; Value='S-1-5-90-123'; Reason='service-account' }
    @{ Property='OwnerSid'; Value='S-1-5-96-123'; Reason='service-account' }
    @{ Property='OwnerSid'; Value=$null; Reason='unqueryable' }
    @{ Property='Created'; Value=0; Reason='unqueryable' }
    @{ Property='Pid'; Value=999; Reason='system-or-self' }
    @{ Property='Pid'; Value=4; Reason='system-or-self' }
    @{ Property='PrivateBytes'; Value=255MB; Reason='below-minimum' }
)
foreach ($case in $cases) {
    $saved = $facts.($case.Property); $facts.($case.Property) = $case.Value
    if ([DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $facts, 999, 'C:\Windows') -ne $case.Reason) { throw "Mandatory protection failed: $($case.Reason)" }
    $facts.($case.Property) = $saved
}
if ([DataWorkStation.EarlyOomGuard]::ExclusionReason($policy, $null, 999, 'C:\Windows') -ne 'unqueryable') { throw 'Failed process queries must exclude the process.' }
$policy.Mode = 'Observe'
$observed = [DataWorkStation.EarlyOomGuard]::ReadMemory()
if ($observed.PhysicalTotalBytes -eq 0 -or $observed.CommitLimitBytes -eq 0) { throw 'Native memory observation failed.' }

$fixture = Join-Path ([IO.Path]::GetTempPath()) ('earlyoom-events-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    # Reclaim-first decisions use injected cleanup/telemetry, never live reclamation or termination.
    $reclaimPolicy = [DataWorkStation.EarlyOomPolicy]::new()
    foreach ($name in $declaration.EarlyOom.Keys) { $reclaimPolicy.$name = $declaration.EarlyOom[$name] }
    $pressure = [DataWorkStation.PressureDecision]::new($reclaimPolicy)
    $low = [DataWorkStation.MemoryPressureSnapshot]::new()
    $low.PhysicalTotalBytes = 32GB; $low.PhysicalAvailableBytes = 1GB
    $low.CommitLimitBytes = 48GB; $low.CommitUsedBytes = 45GB
    $recovered = [DataWorkStation.MemoryPressureSnapshot]::new()
    $recovered.PhysicalTotalBytes = 32GB; $recovered.PhysicalAvailableBytes = 8GB
    $recovered.CommitLimitBytes = 48GB; $recovered.CommitUsedBytes = 45GB
    $script:cleanupCalls = 0
    $script:reclaimEvents = [Collections.Generic.List[string]]::new()
    $audit = [Action[string,DataWorkStation.MemoryPressureSnapshot,string]] { param($action, $memory, $detail)
        $script:reclaimEvents.Add($action)
        if (-not $memory -or -not $detail) { throw 'Reclaim events need memory and detail.' }
    }
    $cleanup = [Func[int]] { $script:cleanupCalls++; return 0 }
    $measure = [Func[DataWorkStation.MemoryPressureSnapshot]] { return $recovered }
    $now = [datetime]::SpecifyKind([datetime]'2026-01-01', [DateTimeKind]::Utc)
    $reclaimer = [DataWorkStation.MemoryReclaimer]::new($reclaimPolicy, $fixture)
    $after = $reclaimer.BeforeTermination($low, $now, $cleanup, $measure, $audit)
    if ($pressure.UnderPressure($after) -or $script:cleanupCalls -ne 1) { throw 'Reclaimed RAM must cancel ordinary-pressure termination.' }
    if (($script:reclaimEvents -join ',') -ne 'reclaim-requested,reclaim-completed') { throw 'Cleanup must be audited before and after execution.' }
    $restarted = [DataWorkStation.MemoryReclaimer]::new($reclaimPolicy, $fixture)
    $after = $restarted.BeforeTermination($low, $now.AddSeconds(899), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne 1 -or -not $pressure.UnderPressure($after)) { throw 'Restart must preserve the 15-minute cooldown without delaying kill fallback.' }
    $recovered.CommitUsedBytes = 47GB
    $after = $restarted.BeforeTermination($low, $now.AddMinutes(15), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne 2 -or -not $pressure.UnderPressure($after)) { throw 'Critical commit exhaustion must survive RAM recovery; cleanup must run at cooldown expiry.' }
    $failed = [Func[int]] { $script:cleanupCalls++; return 2 }
    $after = $restarted.BeforeTermination($low, $now.AddMinutes(30), $failed, $measure, $audit)
    if (-not $pressure.UnderPressure($after) -or $script:reclaimEvents[-1] -ne 'reclaim-failed') { throw 'Nonzero exit must retain the pressure-based fallback.' }
    [void]$restarted.BeforeTermination($low, $now.AddMinutes(31), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne 3) { throw 'Failed cleanup attempts must consume cooldown.' }
    $timedOut = [Func[int]] { throw [TimeoutException]::new('synthetic timeout') }
    [void]$restarted.BeforeTermination($low, $now.AddMinutes(45), $timedOut, $measure, $audit)
    # PowerShell wraps delegate exceptions, so any failure still records and falls back.
    if ($script:reclaimEvents[-1] -notin @('reclaim-timeout','reclaim-failed')) { throw 'Cleanup timeout must be reported.' }
    $missing = [Func[int]] { throw [IO.FileNotFoundException]::new('missing cleaner') }
    [void]$restarted.BeforeTermination($low, $now.AddMinutes(60), $missing, $measure, $audit)
    if ($script:reclaimEvents[-1] -ne 'reclaim-failed') { throw 'Missing cleaner must allow pressure-based fallback.' }
    $invalid = [Func[DataWorkStation.MemoryPressureSnapshot]] { return [DataWorkStation.MemoryPressureSnapshot]::new() }
    $rejected = $false
    try { [void]$restarted.BeforeTermination($low, $now.AddMinutes(75), $cleanup, $invalid, $audit) } catch { $rejected = $true }
    if (-not $rejected) { throw 'Invalid post-cleanup telemetry must prevent termination.' }
    $callsBefore = $script:cleanupCalls
    $badAudit = [Action[string,DataWorkStation.MemoryPressureSnapshot,string]] { throw 'audit unavailable' }
    $rejected = $false
    try { [void]$restarted.BeforeTermination($low, $now.AddMinutes(90), $cleanup, $measure, $badAudit) } catch { $rejected = $true }
    if (-not $rejected -or $script:cleanupCalls -ne $callsBefore) { throw 'Audit failure must prevent cleanup and termination.' }
    foreach ($mode in @('Observe','Disabled')) {
        $reclaimPolicy.Mode = $mode
        [void]$restarted.BeforeTermination($low, $now.AddMinutes(90), $cleanup, $measure, $audit)
    }
    $reclaimPolicy.Mode = 'Enforce'; $reclaimPolicy.MemoryOptimizeEnabled = $false
    [void]$restarted.BeforeTermination($low, $now.AddMinutes(90), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne $callsBefore) { throw 'Disabled or observation-only policies must never reclaim.' }
    $reclaimPolicy.MemoryOptimizeEnabled = $true
    'broken' | Set-Content (Join-Path $fixture 'memory-optimize-last-attempt.txt')
    $broken = [DataWorkStation.MemoryReclaimer]::new($reclaimPolicy, $fixture)
    [void]$broken.BeforeTermination($low, $now.AddDays(1), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne $callsBefore) { throw 'Unreadable cooldown record must suppress automatic cleanup.' }
    Remove-Item -LiteralPath (Join-Path $fixture 'memory-optimize-last-attempt.txt')
    $reclaimPolicy.MemoryOptimizeCooldownMinutes = 30
    $custom = [DataWorkStation.MemoryReclaimer]::new($reclaimPolicy, $fixture)
    [void]$custom.BeforeTermination($low, $now, $cleanup, $measure, $audit)
    [void]$custom.BeforeTermination($low, $now.AddMinutes(15), $cleanup, $measure, $audit)
    if ($script:cleanupCalls -ne $callsBefore + 1) { throw 'Custom cooldown must be honored.' }
    foreach ($property in @('MemoryOptimizeCooldownMinutes','MemoryOptimizeTimeoutSeconds')) {
        $saved = $reclaimPolicy.$property; $reclaimPolicy.$property = 0
        $rejected = $false
        try { $reclaimPolicy.Validate() } catch { $rejected = $true }
        if (-not $rejected) { throw "Invalid reclaim setting accepted: $property" }
        $reclaimPolicy.$property = $saved
    }
    # Enforce parity with the user-facing alias without running WinMemoryCleaner.
    $profileText = Get-Content (Join-Path $root 'profile\Tools.ps1') -Raw
    if ($profileText -notmatch "-ArgumentList '/ModifiedFileCache', '/StandbyList', '/WorkingSet'" -or
        [DataWorkStation.MemoryReclaimer]::Arguments -ne '/ModifiedFileCache /StandbyList /WorkingSet') { throw 'Service and MemoryOptimize --now areas diverged.' }
    # Exercise native process startup and timeout using only a small disposable test helper.
    $runnerSource = Join-Path $fixture 'ReclaimProbe.cs'
    $runnerExe = Join-Path $fixture 'ReclaimProbe.exe'
    @'
using System;
using System.Diagnostics;
using System.IO;
class ReclaimProbe {
    static int Main(string[] args) {
        string own = Process.GetCurrentProcess().MainModule.FileName;
        if (File.Exists(own + ".slow")) System.Threading.Thread.Sleep(5000);
        return String.Join(" ", args) == "/ModifiedFileCache /StandbyList /WorkingSet" ? 23 : 24;
    }
}
'@ | Set-Content -LiteralPath $runnerSource
    & $compiler /nologo /target:exe ('/out:' + $runnerExe) $runnerSource
    if ($LASTEXITCODE -ne 0) { throw 'Reclaim probe compilation failed.' }
    if ([DataWorkStation.MemoryReclaimer]::RunTool($runnerExe, 2) -ne 23) { throw 'Native helper must receive exact headless arguments and propagate exit code.' }
    New-Item -ItemType File -Path ($runnerExe + '.slow') | Out-Null
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $rejected = $false
    try { [void][DataWorkStation.MemoryReclaimer]::RunTool($runnerExe, 1) } catch { $rejected = $_.Exception.ToString() -match 'TimeoutException' }
    if (-not $rejected -or $timer.Elapsed.TotalSeconds -gt 4) { throw 'Native helper timeout must bound the wait.' }
    if (Get-Process ReclaimProbe -ErrorAction Ignore) { throw 'Timed-out helper must not remain running.' }
    $guard = [DataWorkStation.EarlyOomGuard]::new($policy, $fixture)
    $guard.Tick()
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
    # An ordinary executable outside the managed target list allocates only 96 MiB,
    # announces readiness and exits itself. Inspection never requests termination access.
    $probeSource = Join-Path $fixture 'UnmanagedGuardProbe.cs'
    $probeExe = Join-Path $fixture 'UnmanagedGuardProbe.exe'
    @'
using System;
using System.Runtime.InteropServices;
class UnmanagedGuardProbe {
    static void Main() {
        IntPtr memory = Marshal.AllocHGlobal(96 * 1024 * 1024);
        try { Console.WriteLine("ready"); System.Threading.Thread.Sleep(5000); }
        finally { Marshal.FreeHGlobal(memory); }
    }
}
'@ | Set-Content -LiteralPath $probeSource
    & $compiler /nologo /target:exe ('/out:' + $probeExe) $probeSource
    if ($LASTEXITCODE -ne 0) { throw 'Candidate probe compilation failed.' }
    $start = [Diagnostics.ProcessStartInfo]::new($probeExe)
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.RedirectStandardOutput = $true
    $probe = [Diagnostics.Process]::Start($start)
    try {
        if ($probe.StandardOutput.ReadLine() -ne 'ready') { throw 'Candidate probe did not become ready.' }
        $policy.MinimumCandidateMiB = 64
        $inspection = [DataWorkStation.EarlyOomGuard]::InspectCandidates($policy)
        for ($index = 1; $index -lt $inspection.candidates.Count; $index++) {
            if ($inspection.candidates[$index].privateBytes -gt $inspection.candidates[$index - 1].privateBytes) { throw 'Candidates must be ranked by descending private bytes.' }
        }
        if ($inspection.excludedCounts.Count -eq 0) { throw 'Inspection must account for excluded processes.' }
        $match = @($inspection.candidates | Where-Object pid -eq $probe.Id)
        # Session-zero CI is intentionally protected, even for this fixture.
        if ($probe.SessionId -ne 0 -and [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') {
            if ($match.Count -ne 1 -or $match[0].name -ne 'UnmanagedGuardProbe.exe') { throw 'Native enumeration must find an unmanaged ordinary application.' }
            $policy.ExcludedExecutables += 'UnmanagedGuardProbe.exe'
            $protected = [DataWorkStation.EarlyOomGuard]::InspectCandidates($policy)
            if (@($protected.candidates | Where-Object pid -eq $probe.Id).Count -ne 0) { throw 'Native inspection must honor configured exclusions.' }
        }
        if (-not $inspection.observationOnly) { throw 'Candidate inspection must be observation only.' }
    } finally { $probe.WaitForExit(); $probe.Dispose() }
} finally {
    foreach ($name in @('earlyoom.jsonl', 'earlyoom.jsonl.previous', 'UnmanagedGuardProbe.cs', 'UnmanagedGuardProbe.exe', 'ReclaimProbe.cs', 'ReclaimProbe.exe', 'ReclaimProbe.exe.slow', 'memory-optimize-last-attempt.txt', 'memory-optimize-last-attempt.txt.tmp')) { $path = Join-Path $fixture $name; if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
    [IO.Directory]::Delete($fixture)
}
Write-Output 'PASS: dynamic thresholds, commit emergency, cooldown, recovery, fail-closed telemetry, candidate restrictions and rotated event queries. No workloads were terminated.'
}
Test-EarlyOom
