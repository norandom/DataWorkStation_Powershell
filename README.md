# Windows workstation desired state

This repository maintains a Linux-friendly PowerShell environment without using the legacy DSC MOF/LCM model. WinGet Configuration uses the current DSC v3 processor for packages; small idempotent PowerShell resources maintain the user profiles, Windows sudo, btop preferences, and firewall policy.

## Layout

| Path | Responsibility |
|---|---|
| `.config/configuration.winget` | Declarative WinGet package state, including `uv`. |
| `config/developer-tools.psd1` | Pinned CodeQL and TTD versions plus Trail of Bits CodeQL packs. |
| `config/profiling-tools.psd1` | Pinned profiler versions and the feature-scoped WPT bootstrap. |
| `profile/Shell.ps1` | Minimal managed profile-component loader. |
| `profile/Config.ps1` | PSReadLine, prompt, and native-command precedence. |
| `profile/Tools.ps1` | Reusable diagnostics and command implementations. |
| `profile/Aliases.ps1` | Short user-facing wrappers and Linux-style mappings. |
| `scripts/Set-PowerShellProfile.ps1` | Deploys and verifies the loader and components for both PowerShell runtimes. |
| `scripts/Set-DeveloperToolsState.ps1` | Maintains CodeQL, Trail of Bits packs, Semgrep CE, TTD, Debian rsync, and PoolMon tags. |
| `scripts/Set-ProfilingToolsState.ps1` | Maintains WPT/WPA, py-spy, dotnet-trace, and the local Speedscope viewer. |
| `scripts/Invoke-NativeCpuProfile.ps1` | Records native/system CPU traces with WPR for WPA. |
| `scripts/Invoke-PythonProfile.ps1` | Records Python sampled stacks as standalone SVG flame graphs. |
| `scripts/Invoke-DotNetProfile.ps1` | Records .NET EventPipe traces and Speedscope data. |
| `scripts/Get-ProfilerStatus.ps1` | Reports profiler availability as PowerShell objects or JSON. |
| `scripts/Set-PoolMonState.ps1` | Copies the official WinDbg/WDK pool-tag database beside PoolMon. |
| `scripts/Set-SudoState.ps1` | Maintains Windows sudo in inline (`normal`) mode. |
| `scripts/Set-DefenderExclusionState.ps1` | Maintains the declared Microsoft Defender path exclusions. |
| `scripts/Set-DefenderState.ps1` | Explicitly enables, disables, or reports Defender runtime protection. |
| `scripts/Set-SmartScreenState.ps1` | Controls SmartScreen Off, Medium/Warn, and Full/Block modes. |
| `scripts/Set-SaveZoneState.ps1` | Controls whether future downloads retain Mark-of-the-Web. |
| `scripts/Set-WslState.ps1` | Maintains the WSL memory and swap limits. |
| `scripts/Set-PagefileState.ps1` | Maintains a 16-32 GiB Windows pagefile policy. |
| `scripts/Set-EventLogState.ps1` | Maintains the balanced audit channels and scheduled EVTX archive task. |
| `scripts/Get-EventTriage.ps1` | Normalizes operational, crash, logon, remote, and security event views. |
| `scripts/Invoke-DevEventLogSession.ps1` | Captures scoped EVTX, ETW/WPR ETL, and WER full dumps for a development repro. |
| `scripts/Invoke-PacketCapture.ps1` | Captures NIC traffic with in-box PktMon and converts ETL to PCAPNG. |
| `scripts/Get-PcapTriage.ps1` | Provides compact packet, failure, protocol, port, and endpoint views from PktMon ETL. |
| `scripts/ssh-copy-id.ps1` | Installs an OpenSSH public key on a POSIX SSH target. |
| `scripts/Set-FirewallState.ps1` | Tests, ensures, reinitializes, removes, or restores the firewall state. |
| `config/defender-exclusions.psd1` | Declares paths excluded from Microsoft Defender scanning. |
| `config/wslconfig.ini` | Declares the global WSL 2 memory policy. |
| `config/eventlogs.psd1` | Declares channels, sizes, audit coverage, and archive rotation. |
| `config/taildrive-policy.hujson` | Tailnet policy fragment required for Taildrive. |
| `docs/Aliases.md` | Command reference and firewall behavior. |
| `state/firewall-backups` | Generated full Windows Firewall backups. |

## Usage

Run from PowerShell 7:

```powershell
.\Apply-Workstation.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Ensure
.\Apply-Workstation.ps1 -Mode Reinitialize
```

`Ensure` is the normal operation. It leaves compliant profile, sudo, Defender exclusions, and firewall state untouched. `Reinitialize` is useful after troubleshooting: it reapplies local state and always rebuilds the managed firewall group after exporting a full `.wfw` backup.

The Defender exclusions are `D:\` and `%USERPROFILE%\Source`. The entire D: volume is intentionally excluded from real-time and scheduled Defender scanning. Unrelated exclusions are preserved.

Defender remains active outside those paths by default, but scheduled activity is idle-only, low-priority, throttled toward 15% average CPU, and does not run missed-scan catch-up jobs. Use `disable-defender` and `enable-defender` for an explicit elevated runtime toggle; neither command starts a scan. SmartScreen supports `Off`, `Medium` (`Warn` with override), and `Full` (`Block` without bypass). SaveZone/Mark-of-the-Web is controlled independently. Smart App Control is deliberately not changed.

WSL is capped at 10 GiB RAM with 4 GiB swap and gradual memory reclamation. Windows uses a 16 GiB initial and 32 GiB maximum pagefile; changing that policy requires a Windows restart.

The balanced event-log template keeps relevant live logs circular and generously sized, then exports a rolling 48-hour EVTX window every day. Generated ZIP archives are stored in `E:\Logs`, retained for at most 14 days, capped at 768 MiB total, and rotated early if E: has less than 128 MiB free. Staging occurs under ProgramData on C:. The scheduled exporter is copied into an administrator-controlled directory and runs as SYSTEM.

The package declaration includes PowerShell 7, Microsoft Coreutils, ripgrep, rclone, WinFsp, aria2, WinDbg, Sysinternals Suite, btop4win, uv, the .NET 10 SDK, Node.js LTS, GitHub CLI (`gh`), Tailscale, WSL, and Debian. The developer-tool state installs CodeQL with pinned verification, public Trail of Bits query packs, Semgrep CE through an isolated uv environment, standalone TTD, Debian rsync, and the official PoolMon tag database. The profiling state installs only the Windows Performance Toolkit feature from the ADK, py-spy through an isolated uv environment, dotnet-trace as a global .NET tool, and Speedscope as a local CLI/browser viewer. None of these use or modify the AMD/PyTorch Python environment.

## Automatic versus explicit actions

`Apply-Workstation.ps1 -Mode Ensure` automatically installs or repairs the declared WinGet packages, developer CLIs, and required profiling tools. WPT uses a separate idempotent resource so only `OptionId.WindowsPerformanceToolkit` is installed rather than the complete ADK. AMD uProf remains explicit because AMD requires interactive EULA acceptance; `uprof-install` opens the official download page and desired state reports whether it was installed.

Desired state never configures rclone credentials, creates a persistent cloud mount, signs into Semgrep, starts a Semgrep/CodeQL scan, records a performance or TTD trace, attaches a debugger, captures a crash dump, or registers a machine-wide postmortem debugger. Those actions remain explicit shell commands.

The full WDK is not installed automatically because WinDbg supplies the required `pooltag.txt`. If that source disappears, `Set-PoolMonState.ps1` reports the explicit fallback command instead of silently installing the large WDK.

Docker Engine and Compose inside Debian WSL remain separate because Linux repository configuration and daemon state belong inside the distribution rather than the Windows package configuration.

See [docs/Aliases.md](docs/Aliases.md) for daily commands and the exact network exposure model.
