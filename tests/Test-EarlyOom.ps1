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
    foreach ($name in @('earlyoom.jsonl', 'earlyoom.jsonl.previous', 'UnmanagedGuardProbe.cs', 'UnmanagedGuardProbe.exe')) { $path = Join-Path $fixture $name; if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path } }
    [IO.Directory]::Delete($fixture)
}
Write-Output 'PASS: dynamic thresholds, commit emergency, cooldown, recovery, fail-closed telemetry, candidate restrictions and rotated event queries. No workloads were terminated.'
}
Test-EarlyOom
