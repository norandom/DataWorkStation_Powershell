// GUI-subsystem entry point: sign-in must not allocate a Terminal console.
using System;
using System.Diagnostics;
using System.IO;

namespace WorkstationRgb
{
    public static class Startup
    {
        public static int Main(string[] args)
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            try
            {
                if (args.Length != 1 || !Path.IsPathRooted(args[0]) || !File.Exists(args[0]))
                    throw new ArgumentException("Expected the absolute path to PowerShell 7.");
                string script = Path.Combine(root, "Start-RazerRgb.ps1");
                if (!File.Exists(script)) throw new FileNotFoundException("Missing lighting launcher", script);
                File.WriteAllText(Path.Combine(root, "startup.log"), "Starting lighting launcher" + Environment.NewLine);
                using (Process child = new Process())
                {
                    child.StartInfo = new ProcessStartInfo(args[0], "-NoLogo -NoProfile -NonInteractive -File \"" + script + "\"")
                    {
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WorkingDirectory = root
                    };
                    child.Start();
                    child.WaitForExit();
                    File.AppendAllText(Path.Combine(root, "startup.log"), "Launcher exit code: " + child.ExitCode + Environment.NewLine);
                    return child.ExitCode;
                }
            }
            catch (Exception e)
            {
                try { File.AppendAllText(Path.Combine(root, "startup.log"), e.ToString() + Environment.NewLine); }
                catch (IOException) { }
                catch (UnauthorizedAccessException) { }
                return 1;
            }
        }
    }
}
