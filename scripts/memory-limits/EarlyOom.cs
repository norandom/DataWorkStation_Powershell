using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Globalization;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Principal;
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
        public bool MemoryOptimizeEnabled { get; set; }
        public int MemoryOptimizeCooldownMinutes { get; set; }
        public int MemoryOptimizeTimeoutSeconds { get; set; }
        public int MinimumCandidateMiB { get; set; }
        public string[] ExcludedExecutables { get; set; }
        public void Validate()
        {
            if (Mode != "Observe" && Mode != "Enforce" && Mode != "Disabled") throw new InvalidDataException("Invalid early-OOM mode.");
            if (AvailablePhysicalPercent <= 0 || AvailablePhysicalPercent > 25 || CommitHeadroomPercent <= 0 || CommitHeadroomPercent > 25 || EmergencyCommitHeadroomPercent <= 0 || EmergencyCommitHeadroomPercent >= CommitHeadroomPercent)
                throw new InvalidDataException("Invalid early-OOM thresholds.");
            if (SustainSeconds < 1 || SustainSeconds > 60 || CooldownSeconds < 5 || CooldownSeconds > 300 || MinimumCandidateMiB < 64 || ExcludedExecutables == null)
                throw new InvalidDataException("Invalid early-OOM timing or candidates.");
            if (ExcludedExecutables.Any(x => String.IsNullOrWhiteSpace(x) || x.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 || !x.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)))
                throw new InvalidDataException("Exclusions must be exact executable filenames.");
            if (MemoryOptimizeEnabled && (MemoryOptimizeCooldownMinutes < 1 || MemoryOptimizeCooldownMinutes > 1440 || MemoryOptimizeTimeoutSeconds < 1 || MemoryOptimizeTimeoutSeconds > 10))
                throw new InvalidDataException("Invalid memory optimization cooldown or timeout.");
        }
    }
    public sealed class CandidateFacts
    {
        public int Pid { get; set; }
        public long Created { get; set; }
        public string ImagePath { get; set; }
        public string OwnerSid { get; set; }
        public uint Session { get; set; }
        public bool Critical { get; set; }
        public ulong PrivateBytes { get; set; }
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
    // The service and the interactive MemoryOptimize --now command use these same areas.
    // Call the protected executable directly: LocalSystem must never load a user's profile.
    public sealed class MemoryReclaimer
    {
        public const string Arguments = "/ModifiedFileCache /StandbyList /WorkingSet";
        readonly EarlyOomPolicy policy;
        readonly string stampPath;
        DateTime lastAttempt = DateTime.MinValue;
        bool invalidStamp;
        public MemoryReclaimer(EarlyOomPolicy settings, string statePath)
        {
            settings.Validate(); policy = settings;
            stampPath = Path.Combine(statePath, "memory-optimize-last-attempt.txt");
            try {
                if (File.Exists(stampPath)) {
                    DateTime parsed;
                    if (!DateTime.TryParseExact(File.ReadAllText(stampPath).Trim(), "o", CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out parsed) || parsed.Kind != DateTimeKind.Utc)
                        invalidStamp = true;
                    else lastAttempt = parsed;
                }
            } catch (IOException) { invalidStamp = true; } catch (UnauthorizedAccessException) { invalidStamp = true; }
        }
        // Delegates let tests prove recovery/failure/cooldown behavior without cleaning or killing.
        public MemoryPressureSnapshot BeforeTermination(MemoryPressureSnapshot before, DateTime utcNow,
            Func<int> optimize, Func<MemoryPressureSnapshot> measure, Action<string, MemoryPressureSnapshot, string> audit)
        {
            before.Validate();
            if (policy.Mode != "Enforce" || !policy.MemoryOptimizeEnabled) return before;
            if (invalidStamp || utcNow - lastAttempt < TimeSpan.FromMinutes(policy.MemoryOptimizeCooldownMinutes)) {
                audit("reclaim-skipped", before, invalidStamp ? "Cooldown record unreadable; automatic cleanup suppressed." : "Automatic cleanup cooldown active.");
                return before;
            }
            audit("reclaim-requested", before, "MemoryOptimize --now equivalent; headless; timeout seconds=" + policy.MemoryOptimizeTimeoutSeconds);
            // Persist before launch. Failed launches count too; restarting the service cannot retry early.
            try {
                string temporary = stampPath + ".tmp";
                File.WriteAllText(temporary, utcNow.ToString("o", CultureInfo.InvariantCulture));
                if (File.Exists(stampPath)) File.Replace(temporary, stampPath, null);
                else File.Move(temporary, stampPath);
                lastAttempt = utcNow;
            } catch (IOException e) { invalidStamp = true; audit("reclaim-skipped", before, e.Message); return before; }
              catch (UnauthorizedAccessException e) { invalidStamp = true; audit("reclaim-skipped", before, e.Message); return before; }
            string outcome, detail;
            try { int code = optimize(); outcome = code == 0 ? "reclaim-completed" : "reclaim-failed"; detail = "ExitCode=" + code; }
            catch (TimeoutException e) { outcome = "reclaim-timeout"; detail = e.Message; }
            catch (Exception e) { outcome = "reclaim-failed"; detail = e.GetType().Name + ": " + e.Message; }
            // Exit success is not a pressure decision: upstream logs some failures internally.
            MemoryPressureSnapshot after = measure(); after.Validate();
            audit(outcome, after, detail + "; before available bytes=" + before.PhysicalAvailableBytes +
                "; after=" + after.PhysicalAvailableBytes + "; before commit headroom bytes=" + before.CommitHeadroomBytes + "; after=" + after.CommitHeadroomBytes);
            return after;
        }
        public static int RunTool(string executable, int timeoutSeconds)
        {
            if (timeoutSeconds < 1 || timeoutSeconds > 10) throw new ArgumentOutOfRangeException("timeoutSeconds");
            if (!File.Exists(executable)) throw new FileNotFoundException("Protected WinMemoryCleaner copy is missing.", executable);
            var start = new ProcessStartInfo(executable, Arguments) {
                UseShellExecute = false, CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden,
                WorkingDirectory = Path.GetDirectoryName(executable)
            };
            using (Process child = Process.Start(start)) {
                if (!child.WaitForExit(timeoutSeconds * 1000)) {
                    // Only the helper we launched is stopped; never kill an existing tray instance.
                    try { child.Kill(); child.WaitForExit(1000); } catch (InvalidOperationException) { }
                    throw new TimeoutException("Memory cleanup exceeded its deadline.");
                }
                return child.ExitCode;
            }
        }
    }
    public sealed class EarlyOomGuard
    {
        readonly EarlyOomPolicy policy;
        readonly PressureDecision decision;
        readonly MemoryReclaimer reclaimer;
        readonly string logPath;
        readonly Stopwatch clock = Stopwatch.StartNew();
        readonly JavaScriptSerializer json = new JavaScriptSerializer();
        string previousState;
        double nextHeartbeat;
        public object Status { get; private set; }
        public EarlyOomGuard(EarlyOomPolicy settings, string statePath)
        { policy = settings; decision = new PressureDecision(settings); reclaimer = new MemoryReclaimer(settings, statePath); logPath = Path.Combine(statePath, "earlyoom.jsonl"); }
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
        public void Tick()
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
            if (policy.Mode == "Enforce") {
                // Avoid cleaning if the pressure already disappeared since the decision sample.
                sample = ReadMemory();
                if (!decision.UnderPressure(sample)) { Write("recovered", sample, null, "Pressure cleared before cleanup."); return; }
                sample = reclaimer.BeforeTermination(sample, DateTime.UtcNow,
                    delegate { return MemoryReclaimer.RunTool(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "WinMemoryCleaner.exe"), policy.MemoryOptimizeTimeoutSeconds); },
                    ReadMemory,
                    delegate(string action, MemoryPressureSnapshot memory, string detail) {
                        if (!Write(action, memory, null, detail)) throw new IOException("Reclaim audit unavailable; action cancelled.");
                    });
                if (!decision.UnderPressure(sample)) {
                    decision.ResetPressure();
                    Status = new { mode = policy.Mode, state = "Recovered", memory = sample, thresholds = policy, log = logPath };
                    Write("recovered", sample, null, "Pressure cleared after reclaim; no application terminated."); return;
                }
            }
            using (Candidate victim = FindCandidate()) {
                if (victim == null) { Write("no-candidate", sample, null, "No eligible user application above minimum size; selection is independent of managed jobs."); return; }
                var identity = Identity(victim.Facts);
                if (policy.Mode == "Observe") { Write("would-terminate", sample, identity, "Observation only; no process was stopped."); return; }
                // Recheck global pressure and the held process identity immediately before action.
                sample = ReadMemory();
                CandidateFacts current = ReadCandidate(victim.Handle, victim.Facts.Pid);
                if (!decision.UnderPressure(sample) || ExclusionReason(policy, current, Process.GetCurrentProcess().Id, WindowsDirectory) != null || current.Created != victim.Facts.Created) {
                    Write("cancelled", sample, identity, "Pressure recovered or candidate no longer eligible."); return;
                }
                if (!Write("terminate-requested", sample, identity, "Force-terminate one user application; unsaved work can be lost."))
                    throw new IOException("Early-OOM action cancelled because its audit record could not be written.");
                bool stopped = TerminateProcess(victim.Handle, 0xE0000001);
                int error = stopped ? 0 : Marshal.GetLastWin32Error();
                bool exited = stopped && WaitForSingleObject(victim.Handle, 2000) == 0;
                Write(!stopped ? "termination-failed" : exited ? "terminated" : "termination-pending", ReadMemory(), identity, "Win32Error=" + error);
            }
        }
        sealed class Candidate : IDisposable
        {
            public IntPtr Handle; public CandidateFacts Facts;
            public void Dispose() { if (Handle != IntPtr.Zero) { Native.CloseHandle(Handle); Handle = IntPtr.Zero; } }
        }
        static readonly string WindowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        // Pure exclusion rule shared by selection, final revalidation and read-only inspection.
        // No executable inclusion list, parent classification or job membership is consulted.
        public static string ExclusionReason(EarlyOomPolicy settings, CandidateFacts facts, int ownPid, string windowsDirectory)
        {
            if (facts == null) return "unqueryable";
            if (facts.Pid < 5 || facts.Pid == ownPid) return "system-or-self";
            if (facts.Session == 0) return "service-session";
            if (facts.Critical) return "critical";
            if (String.IsNullOrWhiteSpace(facts.OwnerSid) || facts.Created <= 0 || String.IsNullOrWhiteSpace(facts.ImagePath) || String.IsNullOrWhiteSpace(windowsDirectory)) return "unqueryable";
            // LocalSystem, LocalService, NetworkService and virtual Windows service/window accounts.
            string sid = facts.OwnerSid;
            if (sid == "S-1-5-18" || sid == "S-1-5-19" || sid == "S-1-5-20" || sid.StartsWith("S-1-5-80-", StringComparison.Ordinal) || sid.StartsWith("S-1-5-90-", StringComparison.Ordinal) || sid.StartsWith("S-1-5-96-", StringComparison.Ordinal)) return "service-account";
            string image = Path.GetFullPath(facts.ImagePath);
            string windows = Path.GetFullPath(windowsDirectory).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            if (image.StartsWith(windows, StringComparison.OrdinalIgnoreCase)) return "windows-image";
            if (settings.ExcludedExecutables.Contains(Path.GetFileName(image), StringComparer.OrdinalIgnoreCase)) return "excluded-executable";
            if (facts.PrivateBytes < (ulong)settings.MinimumCandidateMiB * 1024 * 1024) return "below-minimum";
            return null;
        }
        static object Identity(CandidateFacts facts)
        { return new { pid = facts.Pid, creationFileTimeUtc = facts.Created, name = Path.GetFileName(facts.ImagePath), privateBytes = facts.PrivateBytes, session = facts.Session, selectionScope = "user-applications" }; }
        static CandidateFacts ReadCandidate(IntPtr handle, int pid)
        {
            // A process can exit or change accessibility during enumeration.
            // Skip that candidate rather than resetting pressure for the entire machine.
            try { return ReadCandidateUnchecked(handle, pid); }
            catch (Win32Exception) { return null; }
            catch (ArgumentException) { return null; }
            catch (System.Security.SecurityException) { return null; }
        }
        static CandidateFacts ReadCandidateUnchecked(IntPtr handle, int pid)
        {
            uint session; bool critical;
            if (!ProcessIdToSessionId((uint)pid, out session) || !Native.IsProcessCritical(handle, out critical)) return null;
            if (session == 0 || critical) return new CandidateFacts { Pid = pid, Session = session, Critical = critical };
            var path = new System.Text.StringBuilder(32768); uint length = (uint)path.Capacity;
            if (!QueryFullProcessImageName(handle, 0, path, ref length)) return null;
            IntPtr token;
            if (!OpenProcessToken(handle, 8, out token)) return null;
            string sid;
            try { using (var identity = new WindowsIdentity(token)) { sid = identity.User == null ? null : identity.User.Value; } }
            catch (System.Security.SecurityException) { return null; }
            finally { Native.CloseHandle(token); }
            var counters = new ProcessCounters(); counters.Size = (uint)Marshal.SizeOf(typeof(ProcessCounters));
            if (!GetProcessMemoryInfo(handle, ref counters, counters.Size)) return null;
            return new CandidateFacts { Pid = pid, Created = Native.Creation(handle), ImagePath = path.ToString(), OwnerSid = sid, Session = session, Critical = critical, PrivateBytes = counters.PrivateUsage.ToUInt64() };
        }
        public static object InspectCandidates(EarlyOomPolicy settings)
        {
            settings.Validate();
            var eligible = new List<CandidateFacts>(); var excluded = new Dictionary<string, int>();
            foreach (var entry in Native.Snapshot()) {
                IntPtr handle = Native.OpenProcess(0x101410, false, entry.Pid);
                try {
                    CandidateFacts facts = handle == IntPtr.Zero ? null : ReadCandidate(handle, entry.Pid);
                    string reason = ExclusionReason(settings, facts, Process.GetCurrentProcess().Id, WindowsDirectory);
                    if (reason == null) eligible.Add(facts);
                    else { if (!excluded.ContainsKey(reason)) excluded[reason] = 0; excluded[reason]++; }
                } finally { if (handle != IntPtr.Zero) Native.CloseHandle(handle); }
            }
            return new { utc = DateTime.UtcNow.ToString("o"), selectionScope = "user-applications", observationOnly = true, candidates = eligible.OrderByDescending(x => x.PrivateBytes).Select(Identity).ToArray(), excludedCounts = excluded };
        }
        Candidate FindCandidate()
        {
            Candidate best = null;
            try {
                foreach (var entry in Native.Snapshot()) {
                    int pid = entry.Pid;
                    if (pid < 5 || pid == Process.GetCurrentProcess().Id) continue;
                    IntPtr handle = Native.OpenProcess(policy.Mode == "Enforce" ? 0x101411u : 0x101410u, false, pid);
                    if (handle == IntPtr.Zero) continue;
                    try {
                        CandidateFacts facts = ReadCandidate(handle, pid);
                        if (ExclusionReason(policy, facts, Process.GetCurrentProcess().Id, WindowsDirectory) != null) continue;
                        if (best != null && facts.PrivateBytes <= best.Facts.PrivateBytes) continue;
                        if (best != null) best.Dispose();
                        best = new Candidate { Handle = handle, Facts = facts }; handle = IntPtr.Zero;
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
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool QueryFullProcessImageName(IntPtr process, uint flags, System.Text.StringBuilder path, ref uint size);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool TerminateProcess(IntPtr process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    }
}
