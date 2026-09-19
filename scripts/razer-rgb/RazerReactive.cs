// Local OpenRGB SDK client. Raw Input is used only for lighting; no input is logged.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace WorkstationRgb
{
    public sealed class Sdk : IDisposable
    {
        readonly TcpClient client;
        readonly BinaryReader reader;
        readonly BinaryWriter writer;
        public Sdk(int port, uint version)
        {
            client = new TcpClient();
            if (!client.ConnectAsync("127.0.0.1", port).Wait(3000)) { client.Close(); throw new IOException("OpenRGB connection timed out"); }
            client.ReceiveTimeout = 3000; client.SendTimeout = 3000; client.NoDelay = true;
            reader = new BinaryReader(client.GetStream()); writer = new BinaryWriter(client.GetStream());
            Request(0, 40, BitConverter.GetBytes(version));
            Send(0, 50, Encoding.UTF8.GetBytes("DataWorkStation Razer Reactive\0"));
        }
        public void Send(uint device, uint packet, byte[] data)
        {
            writer.Write(Encoding.ASCII.GetBytes("ORGB")); writer.Write(device); writer.Write(packet);
            writer.Write((uint)data.Length); writer.Write(data); writer.Flush();
        }
        public byte[] Request(uint device, uint packet, byte[] data)
        {
            Send(device, packet, data);
            for (int i = 0; i < 100; i++)
            {
                if (Encoding.ASCII.GetString(reader.ReadBytes(4)) != "ORGB") throw new IOException("Invalid SDK header");
                uint dev = reader.ReadUInt32(), id = reader.ReadUInt32(), size = reader.ReadUInt32();
                if (size > 16777216) throw new IOException("SDK packet too large");
                byte[] body = reader.ReadBytes((int)size);
                if (body.Length != size) throw new EndOfStreamException();
                if (id == 100) throw new IOException("Device list changed; reconnect required");
                if (id == packet && dev == device) return body;
            }
            throw new IOException("Missing SDK reply");
        }
        static string ReadText(BinaryReader r) { return Encoding.UTF8.GetString(r.ReadBytes(r.ReadUInt16())).TrimEnd('\0'); }
        public List<Device> Devices()
        {
            var result = new List<Device>();
            uint count = BitConverter.ToUInt32(Request(0, 0, new byte[0]), 0);
            if (count > 256) throw new IOException("Too many controllers");
            for (uint index = 0; index < count; index++)
            {
                using (var r = new BinaryReader(new MemoryStream(Request(index, 1, BitConverter.GetBytes((uint)1)))))
                {
                    r.ReadUInt32(); var d = new Device(); d.Id = index; d.Type = r.ReadUInt32(); d.Name = ReadText(r);
                    ReadText(r); ReadText(r); ReadText(r); ReadText(r); ReadText(r);
                    int modes = r.ReadUInt16(); r.ReadUInt32();
                    for (int m = 0; m < modes; m++) { string mode = ReadText(r); if (mode == "Direct") d.Direct = true; r.ReadBytes(36); r.ReadBytes(4 * r.ReadUInt16()); }
                    int zones = r.ReadUInt16();
                    for (int z = 0; z < zones; z++) { ReadText(r); r.ReadBytes(16); r.ReadBytes(r.ReadUInt16()); }
                    int leds = r.ReadUInt16(); d.Leds = new string[leds];
                    for (int l = 0; l < leds; l++) { d.Leds[l] = ReadText(r); r.ReadUInt32(); }
                    int colors = r.ReadUInt16();
                    if (colors != leds) throw new IOException("LED/color count mismatch");
                    d.Deadlines = new double[leds]; d.Last = new uint[leds];
                    if (d.Name == "Razer Huntsman Mini" && d.Direct && leds > 0) result.Add(d);
                }
            }
            return result;
        }
        public void Colors(Device d, uint[] colors)
        {
            using (var stream = new MemoryStream()) using (var w = new BinaryWriter(stream))
            { w.Write((uint)(6 + colors.Length * 4)); w.Write((ushort)colors.Length); foreach (uint c in colors) w.Write(c); Send(d.Id, 1050, stream.ToArray()); }
        }
        public void Dispose() { client.Close(); }
        public void CheckChanges() { if (client.Available > 0) throw new IOException("Device update received; reconnect required"); }
    }
    public sealed class Device
    {
        public uint Id, Type;
        public string Name;
        public bool Direct;
        public string[] Leds;
        public double[] Deadlines;
        public uint[] Last;
    }
    public static class Effect
    {
        public static uint Color(double deadline, double now, uint blue, uint white) { return deadline > now ? white : blue; }
        public static bool Matches(string led, string key) { return led == "Key: " + key || (key == "\\" && (led == "Key: \\ (ANSI)" || led == "Key: #")); }
        // PC set-1 scan codes address physical positions independent of the active language layout.
        public static string KeyName(int scan, bool extended)
        {
            if (extended) {
                switch (scan) { case 0x1d: return "Right Control"; case 0x38: return "Right Alt"; case 0x5b: return "Left Windows"; case 0x5c: return "Right Windows"; case 0x5d: return "Menu"; default: return null; }
            }
            string[] rows = { "1234567890", "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" };
            int[] starts = { 2, 16, 30, 44 };
            for (int i = 0; i < starts.Length; i++) if (scan >= starts[i] && scan < starts[i] + rows[i].Length) return rows[i][scan - starts[i]].ToString();
            switch (scan) {
                case 1: return "Escape"; case 12: return "-"; case 13: return "="; case 14: return "Backspace"; case 15: return "Tab";
                case 26: return "["; case 27: return "]"; case 28: return "Enter"; case 29: return "Left Control";
                case 39: return ";"; case 40: return "'"; case 41: return "`"; case 42: return "Left Shift";
                case 43: return "\\"; case 51: return ","; case 52: return "."; case 53: return "/";
                case 54: return "Right Shift"; case 56: return "Left Alt"; case 57: return "Space"; case 58: return "Caps Lock"; case 86: return "\\ (ISO)";
                default: return null;
            }
        }
    }
    public sealed class ReactiveWindow : Form
    {
        [StructLayout(LayoutKind.Sequential)] struct RawDevice { public ushort Page, Usage; public uint Flags; public IntPtr Target; }
        [DllImport("user32.dll", SetLastError=true)] static extern bool RegisterRawInputDevices(RawDevice[] devices, uint count, uint size);
        [DllImport("user32.dll")] static extern uint GetRawInputData(IntPtr raw, uint command, IntPtr data, ref uint size, uint header);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern uint GetRawInputDeviceInfo(IntPtr device, uint command, StringBuilder data, ref uint size);
        readonly Dictionary<IntPtr, bool> allowed = new Dictionary<IntPtr, bool>();
        readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        readonly Stopwatch clock = Stopwatch.StartNew();
        readonly int port, duration;
        readonly uint blue, white;
        Sdk sdk;
        List<Device> devices = new List<Device>();
        double retryAt, nextCheck;
        readonly string root;
        public ReactiveWindow(int sdkPort, int milliseconds, uint baseColor, uint pressColor, string directory)
        {
            port = sdkPort; duration = milliseconds; blue = baseColor; white = pressColor; root = directory;
            var raw = new[] { new RawDevice { Page=1, Usage=6, Flags=0x100, Target=Handle } };
            if (!RegisterRawInputDevices(raw, (uint)raw.Length, (uint)Marshal.SizeOf(typeof(RawDevice)))) throw new System.ComponentModel.Win32Exception();
            timer.Interval = 20; timer.Tick += Tick; timer.Start();
        }
        protected override void SetVisibleCore(bool value) { base.SetVisibleCore(false); }
        void Tick(object sender, EventArgs args)
        {
            double now = clock.Elapsed.TotalMilliseconds;
            try {
                if (sdk == null) {
                    if (now < retryAt) return;
                    sdk = new Sdk(port, 1); devices = sdk.Devices();
                    foreach (Device d in devices) { sdk.Send(d.Id, 1100, new byte[0]); for (int i=0;i<d.Last.Length;i++) d.Last[i] = uint.MaxValue; }
                    File.WriteAllText(Path.Combine(root, "runtime-status.txt"), devices.Count == 0
                        ? "OpenRGB connected; no supported keyboard lighting device detected. Bluetooth mouse lighting is unmanaged."
                        : "Connected: " + String.Join(", ", devices.ConvertAll(d => d.Name).ToArray()));
                    nextCheck = now + 5000;
                }
                if (now >= nextCheck) { sdk.Request(0, 0, new byte[0]); nextCheck = now + 5000; }
                sdk.CheckChanges();
                foreach (Device d in devices) {
                    bool changed = false; uint[] colors = new uint[d.Leds.Length];
                    for (int i=0;i<colors.Length;i++) { colors[i] = Effect.Color(d.Deadlines[i], now, blue, white); if (colors[i] != d.Last[i]) changed = true; }
                    if (changed) { sdk.Colors(d, colors); d.Last = colors; }
                }
            } catch (Exception e) {
                if (sdk != null) sdk.Dispose(); sdk = null; devices.Clear(); retryAt = now + 5000;
                File.WriteAllText(Path.Combine(root, "runtime-status.txt"), "Waiting for OpenRGB: " + e.Message);
            }
        }
        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x00ff && sdk != null) {
                uint size = 0, header = (uint)(8 + IntPtr.Size * 2);
                GetRawInputData(m.LParam, 0x10000003, IntPtr.Zero, ref size, header);
                if (size >= header + 16 && size <= 4096) {
                    IntPtr buffer = Marshal.AllocHGlobal((int)size);
                    try {
                        if (GetRawInputData(m.LParam, 0x10000003, buffer, ref size, header) == size) {
                            IntPtr device = Marshal.ReadIntPtr(buffer, 8); bool accept;
                            if (!allowed.TryGetValue(device, out accept)) {
                                uint length = 512; var name = new StringBuilder(512);
                                GetRawInputDeviceInfo(device, 0x20000007, name, ref length);
                                string path = name.ToString().ToUpperInvariant();
                                accept = path.Contains("VID_1532"); allowed[device] = accept;
                            }
                            if (accept) {
                                int type = Marshal.ReadInt32(buffer), offset = (int)header;
                                if (type == 1) {
                                    int flags = (ushort)Marshal.ReadInt16(buffer, offset + 2);
                                    if ((flags & 1) == 0) {
                                        string key = Effect.KeyName((ushort)Marshal.ReadInt16(buffer, offset), (flags & 2) != 0);
                                        if (key != null) foreach (Device d in devices) if (d.Name == "Razer Huntsman Mini")
                                            for (int i=0;i<d.Leds.Length;i++) if (Effect.Matches(d.Leds[i], key)) d.Deadlines[i] = clock.Elapsed.TotalMilliseconds + duration;
                                    }
                                }
                            }
                        }
                    } finally { Marshal.FreeHGlobal(buffer); }
                }
            }
            base.WndProc(ref m);
        }
        protected override void Dispose(bool disposing) { if (disposing) { timer.Dispose(); if (sdk != null) sdk.Dispose(); } base.Dispose(disposing); }
    }
    public static class Program
    {
        static uint ParseColor(string hex) { uint c = Convert.ToUInt32(hex, 16); return ((c & 255) << 16) | (c & 65280) | ((c >> 16) & 255); }
        [STAThread] public static void Main(string[] args)
        {
            bool created;
            using (var mutex = new Mutex(true, "Local\\DataWorkStation.RazerReactive", out created)) {
                if (!created) return;
                try { Application.Run(new ReactiveWindow(Int32.Parse(args[0]), Int32.Parse(args[1]), ParseColor(args[2]), ParseColor(args[3]), AppDomain.CurrentDomain.BaseDirectory)); }
                catch (Exception e) { File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "runtime-status.txt"), "Error: " + e.Message); }
            }
        }
    }
}
