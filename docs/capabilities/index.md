# Choose a capability

Start with the failing behavior and inspect evidence that already exists. People and automation use
the same routing catalog:

```powershell
tricky capabilities
tricky capabilities -Json
```

Capability discovery is observational. It lists commands but never starts capture, launches a
debugger, changes policy, or repairs desired state.

## Diagnose a failure

| Route | Use when | Inspect first | Explicit next action |
|---|---|---|---|
| `memory-pressure` | RAM, commit, WSL memory, or a kernel pool is growing | `mem`, `memapps`, `memproc` | `profile-native-record CASE -Seconds 30` |
| `network-path` | DNS, IPv6, firewall, port, or reachability fails | `ports`, `connections`, existing PCAPNG | `pcap-debug-start CASE` |
| `crash-analysis` | A process exits, faults, freezes, or hangs | `crashes`, `problems`, existing dumps | `dump-on-crash -Name CASE -Executable PATH` |
| `native-performance` | Native or system-wide CPU and latency matter | `profile-status`, existing ETL | `profile-native-record CASE -Seconds 30` |
| `python-performance` | A Python process consumes CPU | `profile-view PROFILE.svg` | `profile-python -ProcessId PID -Seconds 30 -Output PROFILE.svg` |
| `dotnet-performance` | A .NET process needs EventPipe evidence | `profile-dotnet-ps`, existing Speedscope output | `profile-dotnet -ProcessId PID -Seconds 30 -OutputBase CASE` |
| `event-history` | Service, login, audit, or general Windows history may explain a failure | `problems`, `service-errors`, `loginfail` | `eventlog-start CASE -Executable PATH` |
| `security-state` | Defender, firewall, SmartScreen, or SaveZone may be involved | `firewall-status`, `defender-status`, `smartscreen-status`, `savezone-status` | Export and add the state to a Tricky case |
| `malware-triage` | A file is suspicious, general Sandbox behavior must be compared, or two binaries need structural comparison | `is-this-malware PATH`, `sandbox-behavior-control PATH`, or `binary-diff OLD NEW` | Use a separately confirmed Sandbox launch or rootless graph-parser run only after reviewing its plan |
| `autopsy-forensic-analysis` | Existing evidence needs interactive Autopsy or matching native Sleuth Kit inspection | `.\Apply-Workstation.ps1 -Mode Test -Module Autopsy -Plan` | Explicitly apply the opt-in Autopsy module only after reviewing its Defender and tool-write boundaries |
| `forensic-evidence-verification` | An existing segmented EWF image needs an attributable stored-digest and segment-integrity check | `ewf-verify PATH.E01 -ReportDirectory REPORTS -Plan` | Run `ewf-verify` without `-Plan` only after reviewing the native tool state and separate report destination |

Commands in the next-action column start a capture or cross an execution boundary. Review the target
and scope before running one. The focused workflow pages under **Diagnose** and **Secure** explain
each boundary.

Follow the concrete operator evidence and safety boundaries in [sample outputs](../sample-outputs.md),
[hardening residual attack surface](../hardening.md#residual-attack-surface),
[debloat rollback limits](../debloat.md#rollback-limits), and
[malware-analysis isolation](../malware-analysis.md#isolation-and-residual-attack-surface), and
[graph-first analysis differencing](../analysis-differencing.md#graph-first-binary-comparison), and
[read-only EWF verification](../ewf-verification.md).

## Inspect or configure the workstation

| Route | Use when | Safe first command |
|---|---|---|
| `powershell-environment` | Bootstrap PowerShell 7, profiles, or Windows Terminal | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan` |
| `powershell-testing` | Discover Pester tests, parallel execution, or 5.1 compatibility | `test-powershell` |
| `repository-quality` | Check PowerShell, Python, Dockerfiles, Actions, YAML, JSON, TOML, and staged-file safety | `lint-repository` or `precommit-run` |
| `workstation-help` | Find managed commands, aliases, and skills | `workstation-help` |
| `idle-sleep-inhibition` | Inspect Caffeine and its startup state | `pwsh -NoProfile -File .\scripts\Set-CaffeineState.ps1 -Mode Test` |
| `workstation-modules` | Select desired state or review the complete update workflow | `.\Apply-Workstation.ps1 -Mode Test -Module NAME -Plan` or `update` |
| `linux-developer-packages` | Inspect Homebrew, pyinfra, Dagger, or container engines in WSL | `pwsh -NoProfile -File .\scripts\Set-LinuxHomebrewState.ps1 -Mode Test` |
| `go-development` | Inspect Go, its workspace, and toolchain selection | `go version` |
| `native-development` | Inspect MSVC, CMake, Rust, Java, and their environment | `.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan` |
| `spec-driven-development` | Check EARS requirements, tasks, tests, and final traceability | `ears-sdd status --phase final` |
| `terminal-fonts` | Inspect the selected terminal font and pinned Fira Code fallback | `pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Test` |
| `native-text-tools` | Inspect native `awk` and `sed` for PowerShell | `pwsh -NoProfile -File .\scripts\Set-NativeTextToolsState.ps1 -Mode Test` |
| `contour-terminal` | Inspect the official MSI, BlueTerm configuration, and graphics gate | `pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test` |
| `windows-hardening` | Compare the developer hardening baseline and residual exposure | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan` |
| `windows-exploit-protection` | Compare DEP, ASLR, CFG, SEHOP, heap, and related process mitigations | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Plan` |
| `windows-debloat` | Review opt-in application and legacy-component removal | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Plan` |
| `windows-virtualization` | Inspect Hyper-V and Windows Sandbox dependency order | `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan` |
| `desktop-focus` | Inspect focus-follows-mouse without raising windows | `pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test` |
| `quant-research-environment` | Inspect the OpenBB base, licensed PyXLL Excel integration, independently locked uv overlays, notebook entry point, or deferred Source relocation plan | `quant-status` or `source-relocation-plan -Target D:\Source` |
| `ai-tools-isolation` | Inspect opt-in native AI tools, the developer editor, AI NixOS, and all WSL trust roles | `pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test` or `pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1` |

## Routing contract

`config/capabilities.psd1` is the authority for route names, triggers, evidence kinds, and commands.
Human output is the default. Use `tricky capabilities -Json` for machine consumption. When a command
changes, update the catalog and this decision page together.
