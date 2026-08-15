# Choose a capability

Start with the failing behavior and inspect evidence that already exists. The routing catalog exposes
the same choices to a person and to automation:

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
| `malware-triage` | A file, script, document, or PDF is suspicious | `is-this-malware PATH` | Use the approved Sandbox detonation command only after static triage |

The next-action column crosses an evidence or execution boundary. Review the target and scope before
running it. The focused workflow pages under **Diagnose** and **Secure** explain those boundaries.

## Inspect or configure the workstation

| Route | Use when | Safe first command |
|---|---|---|
| `powershell-environment` | Bootstrap PowerShell 7, profiles, or Windows Terminal | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan` |
| `powershell-testing` | Discover Pester tests, parallel execution, or 5.1 compatibility | `test-powershell` |
| `workstation-help` | Find managed commands, aliases, and skills | `workstation-help` |
| `idle-sleep-inhibition` | Inspect Caffeine and its startup state | `pwsh -NoProfile -File .\scripts\Set-CaffeineState.ps1 -Mode Test` |
| `workstation-modules` | Select one desired-state resource and its dependencies | `.\Apply-Workstation.ps1 -Mode Test -Module NAME -Plan` |
| `linux-developer-packages` | Inspect Homebrew, pyinfra, Dagger, or container engines in WSL | `pwsh -NoProfile -File .\scripts\Set-LinuxHomebrewState.ps1 -Mode Test` |
| `go-development` | Inspect Go, its workspace, and toolchain selection | `go version` |
| `native-development` | Inspect MSVC, CMake, Rust, Java, and their environment | `.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan` |
| `spec-driven-development` | Check EARS requirements, tasks, tests, and final traceability | `ears-sdd status --phase final` |
| `terminal-fonts` | Inspect the selected terminal font and pinned Fira Code fallback | `pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Test` |
| `native-text-tools` | Inspect native `awk` and `sed` for PowerShell | `pwsh -NoProfile -File .\scripts\Set-NativeTextToolsState.ps1 -Mode Test` |
| `contour-terminal` | Inspect the official MSI, BlueTerm configuration, and graphics gate | `pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test` |
| `windows-hardening` | Compare the developer hardening baseline and residual exposure | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan` |
| `windows-debloat` | Review opt-in application and legacy-component removal | `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Plan` |
| `windows-virtualization` | Inspect Hyper-V and Windows Sandbox dependency order | `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan` |
| `desktop-focus` | Inspect focus-follows-mouse without raising windows | `pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test` |

## Routing contract

`config/capabilities.psd1` is the authority for route names, triggers, evidence kinds, and commands.
Human output is the default. Use `tricky capabilities -Json` for machine consumption. When a command
changes, update the catalog and this decision page together.
