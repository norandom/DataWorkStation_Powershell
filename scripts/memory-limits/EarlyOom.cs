using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;

namespace DataWorkStation
{
    public sealed class EarlyOomPolicy
    {
        public string Mode { get; set; }
        public double AvailablePhysicalPercent { get; set; }
        public double CommitHeadroomPercent { get; set; }
        public double EmergencyCommitHeadroomPercent { get; set; }
        public int SustainSeconds { get; set; }
        public int CooldownSeconds { get; set; }
        public int MinimumCandidateMiB { get; set; }
        public string[] TerminationExecutables { get; set; }
        public void Validate()
        {
            if (Mode != "Observe" && Mode != "Enforce" && Mode != "Disabled") throw new InvalidDataException("Invalid early-OOM mode.");
            if (AvailablePhysicalPercent <= 0 || AvailablePhysicalPercent > 25 || CommitHeadroomPercent <= 0 || CommitHeadroomPercent > 25 || EmergencyCommitHeadroomPercent <= 0 || EmergencyCommitHeadroomPercent >= CommitHeadroomPercent)
                throw new InvalidDataException("Invalid early-OOM thresholds.");
            if (SustainSeconds < 1 || SustainSeconds > 60 || CooldownSeconds < 5 || CooldownSeconds > 300 || MinimumCandidateMiB < 64 || TerminationExecutables == null)
                throw new InvalidDataException("Invalid early-OOM timing or candidates.");
            // Destructive scope stays narrower than the broader AI-host allocation policy.
            string[] allowed = { "python.exe", "pythonw.exe", "python3.exe", "python3.12.exe", "python3.13.exe", "python3.14.exe", "dotnet.exe" };
            if (TerminationExecutables.Any(x => !allowed.Contains(x, StringComparer.OrdinalIgnoreCase))) throw new InvalidDataException("Termination is restricted to managed Python/.NET workers.");
        }
    }
    public sealed class MemoryPressureSnapshot
    {
        public string Utc { get; set; }
        public ulong PhysicalTotalBytes { get; set; }
        public ulong PhysicalAvailableBytes { get; set; }
        public ulong CommitLimitBytes { get; set; }
        public ulong CommitUsedBytes { get; set; }
        public ulong? PagefileAllocatedBytes { get; set; }
        public ulong? PagefileUsedBytes { get; set; }
        public ulong CommitHeadroomBytes { get { return CommitUsedBytes >= CommitLimitBytes ? 0 : CommitLimitBytes - CommitUsedBytes; } }
        public double PhysicalAvailablePercent { get { return PhysicalTotalBytes == 0 ? 0 : 100.0 * PhysicalAvailableBytes / PhysicalTotalBytes; } }
        public double CommitHeadroomPercent { get { return CommitLimitBytes == 0 ? 0 : 100.0 * CommitHeadroomBytes / CommitLimitBytes; } }
        public void Validate()
        {
            if (PhysicalTotalBytes == 0 || CommitLimitBytes == 0 || PhysicalAvailableBytes > PhysicalTotalBytes) throw new InvalidDataException("Invalid memory telemetry; no action allowed.");
        }
    }
    // Pure decision state machine: tests supply synthetic pressure and monotonic time.
    public sealed class PressureDecision
    {
        readonly EarlyOomPolicy policy;
        double pressureSince = -1, lastAction = double.NegativeInfinity;
        public PressureDecision(EarlyOomPolicy settings) { settings.Validate(); policy = settings; }
        public bool UnderPressure(MemoryPressureSnapshot sample)
        {
            sample.Validate();
            return sample.CommitHeadroomPercent <= policy.EmergencyCommitHeadroomPercent ||
                (sample.PhysicalAvailablePercent <= policy.AvailablePhysicalPercent && sample.CommitHeadroomPercent <= policy.CommitHeadroomPercent);
        }
        public string Evaluate(MemoryPressureSnapshot sample, double seconds)
        {
            if (policy.Mode == "Disabled") return "Disabled";
            if (!UnderPressure(sample)) { pressureSince = -1; return "Normal"; }
            if (pressureSince < 0) pressureSince = seconds;
            if (seconds - lastAction < policy.CooldownSeconds) return "Cooldown";
            return seconds - pressureSince >= policy.SustainSeconds ? "Ready" : "Pressure";
        }
        public void ActionTaken(double seconds) { lastAction = seconds; pressureSince = -1; }
        public void ResetPressure() { pressureSince = -1; }
    }
    public sealed class EarlyOomGuard
    {
        readonly EarlyOomPolicy policy;
        readonly PressureDecision decision;
        readonly string logPath;
        readonly Stopwatch clock = Stopwatch.StartNew();
        readonly JavaScriptSerializer json = new JavaScriptSerializer();
        string previousState;
        double nextHeartbeat;
        public object Status { get; private set; }
        public EarlyOomGuard(EarlyOomPolicy settings, string statePath)
        { policy = settings; decision = new PressureDecision(settings); logPath = Path.Combine(statePath, "earlyoom.jsonl"); }
        public void RecordFailure(string message) { decision.ResetPressure(); Status = new { mode = policy.Mode, state = "Faulted", error = message }; }
        bool Write(string action, MemoryPressureSnapshot sample, object candidate, string detail)
        {
            try {
                if (File.Exists(logPath) && new FileInfo(logPath).Length > 4 * 1024 * 1024) {
                    string previous = logPath + ".previous";
                    if (File.Exists(previous)) File.Delete(previous);
                    File.Move(logPath, previous);
                }
                var row = new { schemaVersion = 1, utc = DateTime.UtcNow.ToString("o"), action, mode = policy.Mode, memory = sample, thresholds = policy, candidate, detail };
                File.AppendAllText(logPath, json.Serialize(row) + Environment.NewLine);
                return true;
            } catch (IOException) { return false; } catch (UnauthorizedAccessException) { return false; }
        }
        public void Tick(Dictionary<string, IntPtr> jobs)
        {
            if (policy.Mode == "Disabled") { Status = new { mode = policy.Mode }; return; }
            MemoryPressureSnapshot sample = ReadMemory();
            string state = decision.Evaluate(sample, clock.Elapsed.TotalSeconds);
            Status = new { mode = policy.Mode, state, memory = sample, thresholds = policy, log = logPath };
            if (state != previousState || clock.Elapsed.TotalSeconds >= nextHeartbeat) {
                if (!Write(state == "Normal" && previousState != null && previousState != "Normal" ? "recovered" : "sample", sample, null, state))
                    throw new IOException("Early-OOM audit log unavailable; termination disabled for this sample.");
                previousState = state; nextHeartbeat = clock.Elapsed.TotalSeconds + 60;
            }
            if (state != "Ready") return;
            // Rate-limit observe mode, failed attempts and no-candidate decisions too.
            decision.ActionTaken(clock.Elapsed.TotalSeconds);
            using (Candidate victim = FindCandidate(jobs)) {
                if (victim == null) { Write("no-candidate", sample, null, "No eligible managed Python/.NET worker above minimum size."); return; }
                var identity = new { pid = victim.Pid, creationFileTimeUtc = victim.Created, name = victim.Name, privateBytes = victim.PrivateBytes, job = victim.Job };
                if (policy.Mode == "Observe") { Write("would-terminate", sample, identity, "Observation only; no process was stopped."); return; }
                // Recheck global pressure and the held process identity immediately before action.
                sample = ReadMemory();
                bool critical;
                if (!decision.UnderPressure(sample) || !Native.IsProcessCritical(victim.Handle, out critical) || critical || Native.Creation(victim.Handle) != victim.Created) {
                    Write("cancelled", sample, identity, "Pressure recovered or candidate no longer eligible."); return;
                }
                if (!Write("terminate-requested", sample, identity, "Force-terminate one managed worker; unsaved worker state can be lost."))
                    throw new IOException("Early-OOM action cancelled because its audit record could not be written.");
                bool stopped = TerminateProcess(victim.Handle, 0xE0000001);
                int error = stopped ? 0 : Marshal.GetLastWin32Error();
                bool exited = stopped && WaitForSingleObject(victim.Handle, 2000) == 0;
                Write(!stopped ? "termination-failed" : exited ? "terminated" : "termination-pending", ReadMemory(), identity, "Win32Error=" + error);
            }
        }
        sealed class Candidate : IDisposable
        {
            public IntPtr Handle; public int Pid; public long Created; public string Name, Job; public ulong PrivateBytes;
            public void Dispose() { if (Handle != IntPtr.Zero) { Native.CloseHandle(Handle); Handle = IntPtr.Zero; } }
        }
        Candidate FindCandidate(Dictionary<string, IntPtr> jobs)
        {
            Candidate best = null;
            try {
                foreach (var job in jobs) foreach (int pid in Native.JobPids(job.Value)) {
                    if (pid < 5 || pid == Process.GetCurrentProcess().Id) continue;
                    IntPtr handle = Native.OpenProcess(0x101411, false, pid);
                    if (handle == IntPtr.Zero) continue;
                    try {
                        uint session; bool critical, member;
                        if (!ProcessIdToSessionId((uint)pid, out session) || session == 0 || !Native.IsProcessCritical(handle, out critical) || critical || !Native.IsProcessInJob(handle, job.Value, out member) || !member) continue;
                        var path = new System.Text.StringBuilder(32768); uint length = (uint)path.Capacity;
                        if (!QueryFullProcessImageName(handle, 0, path, ref length)) continue;
                        string name = Path.GetFileName(path.ToString());
                        if (!policy.TerminationExecutables.Contains(name, StringComparer.OrdinalIgnoreCase)) continue;
                        var counters = new ProcessCounters(); counters.Size = (uint)Marshal.SizeOf(typeof(ProcessCounters));
                        if (!GetProcessMemoryInfo(handle, ref counters, counters.Size)) continue;
                        ulong bytes = counters.PrivateUsage.ToUInt64();
                        if (bytes < (ulong)policy.MinimumCandidateMiB * 1024 * 1024 || (best != null && bytes <= best.PrivateBytes)) continue;
                        long created = Native.Creation(handle);
                        if (best != null) best.Dispose();
                        best = new Candidate { Handle = handle, Pid = pid, Created = created, Name = name, Job = job.Key, PrivateBytes = bytes }; handle = IntPtr.Zero;
                    } finally { if (handle != IntPtr.Zero) Native.CloseHandle(handle); }
                }
                return best;
            } catch { if (best != null) best.Dispose(); throw; }
        }
        public static MemoryPressureSnapshot ReadMemory()
        {
            var info = new PerformanceInfo(); info.Size = (uint)Marshal.SizeOf(typeof(PerformanceInfo));
            if (!GetPerformanceInfo(ref info, info.Size)) throw new Win32Exception();
            ulong page = info.PageSize.ToUInt64();
            var result = new MemoryPressureSnapshot { Utc = DateTime.UtcNow.ToString("o"), PhysicalTotalBytes = info.PhysicalTotal.ToUInt64() * page,
                PhysicalAvailableBytes = info.PhysicalAvailable.ToUInt64() * page, CommitLimitBytes = info.CommitLimit.ToUInt64() * page, CommitUsedBytes = info.CommitTotal.ToUInt64() * page };
            ulong allocated = 0, used = 0;
            PagefileCallback callback = delegate(IntPtr context, ref PagefileInfo file, string name) { allocated += file.TotalSize.ToUInt64() * page; used += file.TotalInUse.ToUInt64() * page; return true; };
            if (EnumPageFiles(callback, IntPtr.Zero)) { result.PagefileAllocatedBytes = allocated; result.PagefileUsedBytes = used; }
            result.Validate(); return result;
        }
        [StructLayout(LayoutKind.Sequential)] struct PerformanceInfo
        {
            public uint Size;
            public UIntPtr CommitTotal, CommitLimit, CommitPeak, PhysicalTotal, PhysicalAvailable, SystemCache, KernelTotal, KernelPaged, KernelNonpaged, PageSize;
            public uint HandleCount, ProcessCount, ThreadCount;
        }
        [StructLayout(LayoutKind.Sequential)] struct ProcessCounters
        {
            public uint Size, PageFaultCount;
            public UIntPtr PeakWorkingSetSize, WorkingSetSize, QuotaPeakPagedPoolUsage, QuotaPagedPoolUsage, QuotaPeakNonPagedPoolUsage, QuotaNonPagedPoolUsage, PagefileUsage, PeakPagefileUsage, PrivateUsage;
        }
        [StructLayout(LayoutKind.Sequential)] struct PagefileInfo
        { public uint Size, Reserved; public UIntPtr TotalSize, TotalInUse, PeakUsage; }
        [UnmanagedFunctionPointer(CallingConvention.Winapi, CharSet = CharSet.Unicode)] delegate bool PagefileCallback(IntPtr context, ref PagefileInfo information, [MarshalAs(UnmanagedType.LPWStr)] string filename);
        [DllImport("psapi.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool EnumPageFiles(PagefileCallback callback, IntPtr context);
        [DllImport("psapi.dll", SetLastError = true)] static extern bool GetPerformanceInfo(ref PerformanceInfo data, uint size);
        [DllImport("psapi.dll", SetLastError = true)] static extern bool GetProcessMemoryInfo(IntPtr process, ref ProcessCounters data, uint size);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool ProcessIdToSessionId(uint pid, out uint session);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool QueryFullProcessImageName(IntPtr process, uint flags, System.Text.StringBuilder path, ref uint size);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    }
}
