using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Management;
using System.Runtime.InteropServices;
using System.ServiceProcess;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace DataWorkStation
{
    public sealed class Policy
    {
        public int LimitGiB { get; set; }
        public int PollMilliseconds { get; set; }
        public string[] Executables { get; set; }
        public string[] RuntimeExecutables { get; set; }
        public string[] ProcessOnlyExecutables { get; set; }
        public EarlyOomPolicy EarlyOom { get; set; }
        public string[] RuntimeMarkers { get; set; }
    }
    public sealed class MemoryLimits : ServiceBase
    {
        const string NameOfService = "DataWorkStationMemoryLimits";
        static readonly string BasePath = AppDomain.CurrentDomain.BaseDirectory;
        static readonly string StatePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), NameOfService);
        static readonly JavaScriptSerializer Json = new JavaScriptSerializer();
        readonly Dictionary<string, IntPtr> jobs = new Dictionary<string, IntPtr>();
        readonly Dictionary<int, long> inspected = new Dictionary<int, long>();
        readonly Dictionary<int, string> errors = new Dictionary<int, string>();
        readonly ManualResetEvent stopping = new ManualResetEvent(false);
        Thread worker;
        Policy policy;
        ulong limit;
        EarlyOomGuard guard;
        int ownPid = Process.GetCurrentProcess().Id;

        public MemoryLimits() { ServiceName = NameOfService; }
        protected override void OnStart(string[] args)
        {
            policy = Json.Deserialize<Policy>(File.ReadAllText(Path.Combine(BasePath, "policy.json")));
            if (policy.LimitGiB < 1 || policy.LimitGiB > 64 || policy.PollMilliseconds < 100 || policy.PollMilliseconds > 5000)
                throw new InvalidDataException("Invalid memory policy.");
            limit = (ulong)policy.LimitGiB * 1024 * 1024 * 1024;
            Directory.CreateDirectory(StatePath);
            if (policy.EarlyOom != null) guard = new EarlyOomGuard(policy.EarlyOom, StatePath);
            RecoverJobs();
            worker = new Thread(Loop) { IsBackground = true, Name = "Workload memory limits" };
            worker.Start();
        }
        protected override void OnStop()
        {
            stopping.Set();
            if (worker != null && !worker.Join(15000)) throw new System.TimeoutException("Monitor did not stop.");
            foreach (IntPtr job in jobs.Values) Native.CloseHandle(job);
            // No KILL_ON_JOB_CLOSE: stopping/crashing the service never terminates workloads.
        }
        void Log(string action, string name, int pid, string detail)
        {
            string file = Path.Combine(StatePath, "events.jsonl");
            try
            {
                if (File.Exists(file) && new FileInfo(file).Length > 4 * 1024 * 1024)
                {
                    string old = file + ".previous";
                    if (File.Exists(old)) File.Delete(old);
                    File.Move(file, old);
                }
                File.AppendAllText(file, Json.Serialize(new { utc = DateTime.UtcNow, action, name, pid, detail }) + Environment.NewLine);
            }
            catch (IOException) { }
        }
        void RecoverJobs()
        {
            string path = Path.Combine(StatePath, "jobs.txt");
            if (!File.Exists(path)) return;
            foreach (string name in File.ReadAllLines(path))
            {
                if (!name.StartsWith("Global\\DWS.Memory.", StringComparison.Ordinal)) continue;
                IntPtr job = Native.OpenJobObject(0x1F003F, false, name);
                if (job != IntPtr.Zero)
                {
                    bool processOnly = Native.ProcessOnly(job);
                    try { processOnly = Contains(policy.ProcessOnlyExecutables, Process.GetProcessById(int.Parse(name.Split('.')[2])).ProcessName + ".exe"); }
                    catch (ArgumentException) { }
                    Native.SetLimit(job, limit, processOnly); jobs[name] = job;
                }
            }
        }
        void Loop()
        {
            int ticks = 0;
            while (!stopping.WaitOne(0))
            {
                try
                {
                    if (guard != null) {
                        try { guard.Tick(); }
                        catch (Exception e) { guard.RecordFailure(e.Message); Log("earlyoom-error", "", 0, e.GetType().Name + ": " + e.Message); }
                    }
                    Scan();
                    if (ticks++ % 10 == 0) SaveStatus();
                }
                catch (Exception e) { Log("monitor-error", "", 0, e.GetType().Name + ": " + e.Message); }
                stopping.WaitOne(policy.PollMilliseconds);
            }
            SaveStatus();
        }
        static bool Contains(string[] entries, string name)
        { return entries != null && entries.Any(x => string.Equals(x, name, StringComparison.OrdinalIgnoreCase)); }
        bool Target(Native.Entry entry)
        {
            if (Contains(policy.Executables, entry.Exe)) return true;
            if (!Contains(policy.RuntimeExecutables, entry.Exe)) return false;
            try
            {
                using (var search = new ManagementObjectSearcher("SELECT ExecutablePath,CommandLine FROM Win32_Process WHERE ProcessId=" + entry.Pid))
                using (var result = search.Get())
                    foreach (ManagementObject process in result)
                    {
                        string value = Convert.ToString(process["ExecutablePath"]) + " " + Convert.ToString(process["CommandLine"]);
                        return policy.RuntimeMarkers.Any(x => value.IndexOf(x, StringComparison.OrdinalIgnoreCase) >= 0);
                    }
            }
            catch (ManagementException) { }
            return false;
        }
        bool InManagedJob(IntPtr process)
        {
            foreach (IntPtr job in jobs.Values)
            {
                bool member;
                if (Native.IsProcessInJob(process, job, out member) && member) return true;
            }
            return false;
        }
        void Scan()
        {
            List<Native.Entry> all = Native.Snapshot();
            var byPid = all.ToDictionary(x => x.Pid);
            foreach (var pair in jobs.ToArray())
            {
                if (Native.JobPids(pair.Value).Count == 0) { Native.CloseHandle(pair.Value); jobs.Remove(pair.Key); }
            }
            var live = new HashSet<int>(all.Select(x => x.Pid));
            foreach (int pid in inspected.Keys.Where(x => !live.Contains(x)).ToArray()) { inspected.Remove(pid); errors.Remove(pid); }
            foreach (int pid in errors.Keys.Where(x => !live.Contains(x)).ToArray()) errors.Remove(pid);
            // Existing children may already have unrelated job hierarchies. Retry and report
            // these gaps, including after a service restart; never silently lose coverage errors.
            foreach (var pair in jobs)
            {
                if (Native.ProcessOnly(pair.Value)) continue;
                var members = new HashSet<int>(Native.JobPids(pair.Value));
                foreach (Native.Entry child in all.Where(x => x.Pid != ownPid && !members.Contains(x.Pid) && members.Any(p => Descendant(x, p, byPid))))
                {
                    IntPtr handle = Native.OpenProcess(0x1101, false, child.Pid);
                    if (handle == IntPtr.Zero) { errors[child.Pid] = "Could not attach existing descendant"; continue; }
                    try
                    {
                        bool critical;
                        if (!Native.IsProcessCritical(handle, out critical) || critical) { errors[child.Pid] = "Critical or unqueryable descendant excluded"; continue; }
                        bool member;
                        if (Native.IsProcessInJob(handle, pair.Value, out member) && (member || Native.AssignProcessToJobObject(pair.Value, handle))) errors.Remove(child.Pid);
                        else errors[child.Pid] = "Existing descendant assignment failed: " + Marshal.GetLastWin32Error();
                    }
                    finally { Native.CloseHandle(handle); }
                }
            }
            // Parents first: child Python/AI processes inherit the existing budget.
            foreach (Native.Entry entry in all.OrderBy(x => Depth(x, byPid)))
            {
                if (entry.Pid == ownPid || entry.Pid < 5) continue;
                if (!Contains(policy.Executables, entry.Exe) && !Contains(policy.RuntimeExecutables, entry.Exe)) continue;
                IntPtr process = Native.OpenProcess(0x1101, false, entry.Pid);
                if (process == IntPtr.Zero) { errors[entry.Pid] = "Cannot open target; error " + Marshal.GetLastWin32Error(); continue; }
                try
                {
                    long born = Native.Creation(process);
                    long previous;
                    if (inspected.TryGetValue(entry.Pid, out previous) && previous == born) continue;
                    if (InManagedJob(process)) { inspected[entry.Pid] = born; errors.Remove(entry.Pid); continue; }
                    if (!Target(entry)) { inspected[entry.Pid] = born; continue; }
                    bool critical;
                    if (!Native.IsProcessCritical(process, out critical) || critical)
                    { errors[entry.Pid] = "Critical or unqueryable process excluded"; continue; }
                    string name = "Global\\DWS.Memory." + entry.Pid + "." + born;
                    IntPtr job = Native.CreateJobObject(IntPtr.Zero, name);
                    if (job == IntPtr.Zero) throw new Win32Exception();
                    try
                    {
                        bool processOnly = Contains(policy.ProcessOnlyExecutables, entry.Exe);
                        Native.SetLimit(job, limit, processOnly);
                        if (!Native.AssignProcessToJobObject(job, process))
                            throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot assign " + entry.Exe + " to memory job");
                        jobs[name] = job;
                        job = IntPtr.Zero;
                        inspected[entry.Pid] = born;
                        errors.Remove(entry.Pid);
                        // Attach children already present before the root was detected.
                        foreach (Native.Entry child in all.Where(x => !processOnly && Descendant(x, entry.Pid, byPid)))
                        {
                            IntPtr handle = Native.OpenProcess(0x1101, false, child.Pid);
                            if (handle == IntPtr.Zero) { errors[child.Pid] = "Could not attach existing descendant"; continue; }
                            try
                            {
                                if (Native.Creation(handle) < born) continue; // reused parent PID
                                bool member;
                                if (Native.IsProcessInJob(handle, jobs[name], out member) && !member && !Native.AssignProcessToJobObject(jobs[name], handle))
                                    errors[child.Pid] = "Existing descendant assignment failed: " + Marshal.GetLastWin32Error();
                            }
                            finally { Native.CloseHandle(handle); }
                        }
                        Log("limited", entry.Exe, entry.Pid, (processOnly ? "Process" : "Tree") + " commit limit " + policy.LimitGiB + " GiB");
                    }
                    finally { if (job != IntPtr.Zero) Native.CloseHandle(job); }
                }
                catch (Exception e)
                {
                    if (!errors.ContainsKey(entry.Pid) || errors[entry.Pid] != e.Message) Log("assignment-error", entry.Exe, entry.Pid, e.Message);
                    errors[entry.Pid] = e.Message;
                }
                finally { Native.CloseHandle(process); }
            }
        }
        static int Depth(Native.Entry item, Dictionary<int, Native.Entry> all)
        {
            int depth = 0;
            var seen = new HashSet<int>();
            while (seen.Add(item.Pid) && all.TryGetValue(item.Parent, out item) && depth < 100) depth++;
            return depth;
        }
        static bool Descendant(Native.Entry item, int root, Dictionary<int, Native.Entry> all)
        {
            if (item.Pid == root) return false;
            var seen = new HashSet<int>();
            while (seen.Add(item.Pid))
            {
                if (item.Parent == root) return true;
                if (!all.TryGetValue(item.Parent, out item)) break;
            }
            return false;
        }
        void SaveStatus()
        {
            var rows = jobs.Select(x => new { name = x.Key, scope = Native.ProcessOnly(x.Value) ? "process" : "tree", limitBytes = Native.GetLimit(x.Value), pids = Native.JobPids(x.Value) }).ToArray();
            File.WriteAllLines(Path.Combine(StatePath, "jobs.txt"), jobs.Keys.ToArray());
            string destination = Path.Combine(StatePath, "status.json");
            string temp = destination + ".new";
            File.WriteAllText(temp, Json.Serialize(new { utc = DateTime.UtcNow.ToString("o"), limitGiB = policy.LimitGiB, pollMilliseconds = policy.PollMilliseconds, earlyOom = guard == null ? null : guard.Status, jobs = rows, errors = errors.Select(x => new { pid = x.Key, error = x.Value }).ToArray() }));
            if (File.Exists(destination)) File.Replace(temp, destination, null); else File.Move(temp, destination);
        }
        static int Main(string[] args)
        {
            if (args.Length == 2 && args[0] == "--guard-candidates") {
                var serializer = new JavaScriptSerializer();
                var settings = serializer.Deserialize<Policy>(File.ReadAllText(args[1]));
                Console.WriteLine(serializer.Serialize(EarlyOomGuard.InspectCandidates(settings.EarlyOom)));
                return 0;
            }
            if (args.Length > 0 && args[0] == "--self-test") return SelfTest();
            if (args.Length > 0 && args[0] == "--probe")
            {
                Thread.Sleep(1000);
                IntPtr block = Native.VirtualAlloc(IntPtr.Zero, new UIntPtr(128u * 1024 * 1024), 0x3000, 4);
                if (block == IntPtr.Zero) return 23;
                Native.VirtualFree(block, UIntPtr.Zero, 0x8000);
                return 0;
            }
            if (args.Length > 0 && args[0] == "--tree-probe")
            {
                Thread.Sleep(1000);
                string executable = Process.GetCurrentProcess().MainModule.FileName;
                using (Process child = Process.Start(new ProcessStartInfo(executable, "--probe") { UseShellExecute = false, CreateNoWindow = true }))
                {
                    if (!child.WaitForExit(10000)) return 2;
                    return child.ExitCode;
                }
            }
            if (args.Length > 0 && args[0] == "--hold") { Thread.Sleep(10000); return 0; }
            if (args.Length > 0 && args[0] == "--release")
            {
                string file = Path.Combine(StatePath, "jobs.txt");
                if (File.Exists(file)) foreach (string name in File.ReadAllLines(file))
                {
                    if (!name.StartsWith("Global\\DWS.Memory.", StringComparison.Ordinal)) continue;
                    IntPtr job = Native.OpenJobObject(0x1F003F, false, name);
                    if (job != IntPtr.Zero) { Native.SetLimit(job, 0); Native.CloseHandle(job); }
                }
                return 0;
            }
            ServiceBase.Run(new MemoryLimits());
            return 0;
        }
        static int SelfTest()
        {
            IntPtr job = Native.CreateJobObject(IntPtr.Zero, null);
            if (job == IntPtr.Zero) throw new Win32Exception();
            try
            {
                Native.SetLimit(job, 64UL * 1024 * 1024);
                string exe = Process.GetCurrentProcess().MainModule.FileName;
                foreach (string mode in new[] { "--probe", "--tree-probe" })
                using (Process child = Process.Start(new ProcessStartInfo(exe, mode) { UseShellExecute = false, CreateNoWindow = true }))
                {
                    if (!Native.AssignProcessToJobObject(job, child.Handle)) throw new Win32Exception();
                    if (!child.WaitForExit(10000)) throw new System.TimeoutException();
                    if (child.ExitCode != 23) throw new Exception("128 MiB allocation was not denied by 64 MiB job limit.");
                    if (Native.GetLimit(job) != 64UL * 1024 * 1024) throw new Exception("Limit readback mismatch.");
                }
                using (Process child = Process.Start(new ProcessStartInfo(exe, "--probe") { UseShellExecute = false, CreateNoWindow = true }))
                {
                    if (!child.WaitForExit(10000) || child.ExitCode != 0) throw new Exception("Unrestricted control failed.");
                }
                Native.SetLimit(job, 64UL * 1024 * 1024, true);
                using (Process child = Process.Start(new ProcessStartInfo(exe, "--probe") { UseShellExecute = false, CreateNoWindow = true }))
                {
                    if (!Native.AssignProcessToJobObject(job, child.Handle)) throw new Win32Exception();
                    if (!child.WaitForExit(10000) || child.ExitCode != 23) throw new Exception("AI host process limit failed.");
                }
                using (Process child = Process.Start(new ProcessStartInfo(exe, "--tree-probe") { UseShellExecute = false, CreateNoWindow = true }))
                {
                    if (!Native.AssignProcessToJobObject(job, child.Handle)) throw new Win32Exception();
                    if (!child.WaitForExit(10000) || child.ExitCode != 0) throw new Exception("Sandbox child independence failed.");
                }
                Console.WriteLine("PASS: kernel denied allocation in root and inherited child; unrestricted control succeeded. No process was killed.");
                Console.WriteLine("PASS: AI host allocation is bounded while child job creation remains independent.");
                return 0;
            }
            finally { Native.CloseHandle(job); }
        }
    }
    internal static class Native
    {
        [StructLayout(LayoutKind.Sequential)] internal struct BasicLimits
        { public long ProcessTime, JobTime; public uint Flags; public UIntPtr Minimum, Maximum; public uint ActiveLimit; public UIntPtr Affinity; public uint Priority, Scheduling; }
        [StructLayout(LayoutKind.Sequential)] internal struct Counters { public ulong A, B, C, D, E, F; }
        [StructLayout(LayoutKind.Sequential)] internal struct Limits
        { public BasicLimits Basic; public Counters Io; public UIntPtr ProcessMemory, JobMemory, PeakProcess, PeakJob; }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] internal struct ProcessEntry
        {
            public uint Size, Usage, Pid; public UIntPtr Heap; public uint Module, Threads, Parent; public int Priority; public uint Flags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string Exe;
        }
        internal sealed class Entry { public int Pid, Parent; public string Exe; }
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern IntPtr OpenJobObject(uint access, bool inherit, string name);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool IsProcessInJob(IntPtr process, IntPtr job, out bool member);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern bool IsProcessCritical(IntPtr process, out bool critical);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool SetInformationJobObject(IntPtr job, int kind, ref Limits data, int length);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool QueryInformationJobObject(IntPtr job, int kind, IntPtr data, int length, IntPtr returned);
        [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetProcessTimes(IntPtr process, out long created, out long exited, out long kernel, out long user);
        [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool Process32FirstW(IntPtr snapshot, ref ProcessEntry entry);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool Process32NextW(IntPtr snapshot, ref ProcessEntry entry);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern IntPtr VirtualAlloc(IntPtr address, UIntPtr size, uint type, uint protect);
        [DllImport("kernel32.dll")] internal static extern bool VirtualFree(IntPtr address, UIntPtr size, uint type);
        internal static long Creation(IntPtr process)
        { long c, e, k, u; if (!GetProcessTimes(process, out c, out e, out k, out u)) throw new Win32Exception(); return c; }
        internal static void SetLimit(IntPtr job, ulong limit, bool processOnly = false)
        {
            var data = new Limits();
            data.Basic.Flags = limit == 0 ? 0x1000u : processOnly ? 0x1100u : 0x200u;
            if (processOnly) data.ProcessMemory = new UIntPtr(limit); else data.JobMemory = new UIntPtr(limit);
            if (!SetInformationJobObject(job, 9, ref data, Marshal.SizeOf(typeof(Limits)))) throw new Win32Exception();
        }
        internal static Limits GetLimits(IntPtr job)
        {
            int size = Marshal.SizeOf(typeof(Limits)); IntPtr data = Marshal.AllocHGlobal(size);
            try { if (!QueryInformationJobObject(job, 9, data, size, IntPtr.Zero)) throw new Win32Exception(); return (Limits)Marshal.PtrToStructure(data, typeof(Limits)); }
            finally { Marshal.FreeHGlobal(data); }
        }
        internal static bool ProcessOnly(IntPtr job) { return (GetLimits(job).Basic.Flags & 0x100) != 0; }
        internal static ulong GetLimit(IntPtr job) { var data = GetLimits(job); return (data.Basic.Flags & 0x100) != 0 ? data.ProcessMemory.ToUInt64() : data.JobMemory.ToUInt64(); }
        internal static List<int> JobPids(IntPtr job)
        {
            int size = 8 + 4096 * IntPtr.Size; IntPtr data = Marshal.AllocHGlobal(size);
            try
            {
                if (!QueryInformationJobObject(job, 3, data, size, IntPtr.Zero)) throw new Win32Exception();
                int count = Marshal.ReadInt32(data, 4); var pids = new List<int>();
                for (int i = 0; i < count; i++) pids.Add((int)Marshal.ReadIntPtr(data, 8 + i * IntPtr.Size).ToInt64());
                return pids;
            }
            finally { Marshal.FreeHGlobal(data); }
        }
        internal static List<Entry> Snapshot()
        {
            var result = new List<Entry>(); IntPtr snapshot = CreateToolhelp32Snapshot(2, 0);
            if (snapshot == new IntPtr(-1)) throw new Win32Exception();
            try
            {
                var entry = new ProcessEntry { Size = (uint)Marshal.SizeOf(typeof(ProcessEntry)) };
                if (Process32FirstW(snapshot, ref entry)) do { result.Add(new Entry { Pid = (int)entry.Pid, Parent = (int)entry.Parent, Exe = entry.Exe }); } while (Process32NextW(snapshot, ref entry));
                return result;
            }
            finally { CloseHandle(snapshot); }
        }
    }
}
