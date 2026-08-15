# DataWorkStation PowerShell

[![Documentation Pages](https://github.com/norandom/DataWorkStation_Powershell/actions/workflows/docs-pages.yml/badge.svg)](https://github.com/norandom/DataWorkStation_Powershell/actions/workflows/docs-pages.yml)
[![Release](https://github.com/norandom/DataWorkStation_Powershell/actions/workflows/release.yml/badge.svg)](https://github.com/norandom/DataWorkStation_Powershell/actions/workflows/release.yml)

A human- and AI-operable Windows engineering workstation for quant finance, data science, development, administration, and occasional forensics.

## Developer documentation

**[Open the published MkDocs developer documentation →](https://norandom.github.io/DataWorkStation_Powershell/)**

Windows 11 Pro is required. The managed state uses Client Hyper-V, Windows Sandbox, native Windows sudo, and other Windows 11 workstation capabilities.
Managed developer commands remain callable from both PowerShell 7 and inbox Windows PowerShell where documented; the Spec Kit EARS/TDD state resource is explicitly tested in both.

<table>
  <tr>
    <td><img src="docs/assets/workstation/powershell-workstation.png" alt="PowerShell workstation showing memory and managed firewall commands"></td>
    <td><img src="docs/assets/workstation/contour-neovim.png" alt="Contour Terminal running Neovim with the configured terminal appearance"></td>
  </tr>
  <tr>
    <td>Operational PowerShell commands for memory, containers, and managed firewall state.</td>
    <td>Contour Terminal running Neovim with the configured terminal and editor appearance.</td>
  </tr>
</table>

### Native development

The `NativeDevelopment` module supplies standalone MSVC/MSBuild, CMake/Ninja, stable Rust MSVC,
and Microsoft OpenJDK 21 without the Visual Studio IDE or a Unix-emulation shell. `JavaToolchain`
is independently selectable and exposes `java` and `javac`; optional Ghidra tooling reuses the same
JDK package.

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeDevelopment
```

## Capabilities

| Need | Commands and artifacts |
|---|---|
| Find memory owners | `mem`, `memapps`, `memproc`, `memtop`, RAMMap, PoolMon |
| Explain a crash or silent exit | event triage, scoped EVTX/ETL, WER dumps, WinDbg, optional TTD |
| Trace DNS, IPv6, firewall, and ports | socket/process maps plus PktMon ETL and PCAPNG queries |
| Render flame graphs | WPR/WPA for native/system, py-spy SVG for Python, EventPipe/Speedscope for .NET |
| Reproduce workstation state | WinGet Configuration plus focused idempotent PowerShell resources |
| Keep an investigation coherent | `tricky` cases with structured JSON and standalone HTML reports |
| Improve AI workflows safely | SkillOpt reviewed tasks, held-out gates, staged proposals, explicit adoption |
| Drive requirements into tests | release-pinned Spec Kit plus reusable EARS/TDD validation and traceability |
| Triage a suspicious file | bounded host inspection, isolated document/reverse-engineering jobs, and explicitly confirmed Windows Sandbox detonation |

Start with [Getting started](docs/getting-started.md) and the [capability overview](docs/capabilities/index.md).

This repository maintains a Linux-friendly PowerShell environment without using the legacy DSC MOF/LCM model. WinGet Configuration uses the current DSC v3 processor for packages; small idempotent PowerShell resources maintain Windows features, a reviewed developer hardening profile, user profiles, Windows sudo, btop preferences, and firewall policy.

## Layout

| Path | Responsibility |
|---|---|
| `.config/configuration.winget` | Declarative WinGet package state, including `uv`. |
| `.config/git.winget` | Focused Git package state used by Scoop dependencies. |
| `.config/powershell7.winget` | Focused PowerShell 7 package state used by Contour, package, and profile dependencies. |
| `.config/go.winget` | Focused official Go MSI-backed package state for Windows development. |
| `.config/native-text-tools.winget` | Focused native Win32 package state for PowerShell `awk` and `sed`. |
| `.config/caffeine.winget` | Focused Zhorn Software Caffeine package state. |
| `.config/malware-analysis-tools.winget` | Opt-in isolated-analysis packages; excluded from the default workstation set. |
| `.terminal-fonts-sample` | Portable one-line terminal font-family example; copy it to ignored `.terminal-fonts` for local use. |
| `.wsl-env.sample` | Portable Debian WSL distribution/user selector; copy it to ignored `.wsl-env`. |
| `config/scoop.psd1` | Official per-user Scoop source and Main/Extras bucket state. |
| `config/contour-terminal.psd1` | Contour package, config, Desktop shortcut, backup, and BlueTerm source paths. |
| `config/terminal-fonts.psd1` | Pinned official Fira Code archive, per-font hashes, and per-user installation paths. |
| `config/contour.yml` | Managed Contour configuration translated from BlueTerm. |
| `config/windows-features.psd1` | Declarative Hyper-V and Windows Sandbox optional-feature state. |
| `config/workstation-modules.psd1` | Module catalog, default selection, dependencies, and execution order. |
| `config/workstation-update.psd1` | Plan-first host, package-manager, WSL, Homebrew, container, and release-reconciliation update stages. |
| `config/hardening-profiles.psd1` | Declarative Windows 11 developer hardening profile. |
| `config/debloat-profiles.psd1` | Opt-in allowlist for consumer-app and legacy-component removal. |
| `config/focus-follows-mouse.psd1` | Declarative current-user hover-focus behavior without window raising. |
| `config/developer-tools.psd1` | Pinned CodeQL and TTD versions plus Trail of Bits CodeQL packs. |
| `config/go.psd1` | Go minimum version, workspace, command path, and built-in toolchain-selection policy. |
| `config/malware-hashes.psd1` | Pinned `malware_hashes` GitHub release asset, SHA-256, and narrow install paths. |
| `config/spec-driven-development.psd1` | Pinned Spec Kit EARS/TDD release wheel, hash, and upstream CLI version. |
| `config/pester.psd1` | Pinned Pester release, shared module path, test discovery, output bounds, and parallel throttle. |
| `config/native-text-tools.psd1` | Declares the native BusyBox applet host and the two exposed PowerShell commands. |
| `config/caffeine.psd1` | Declares the real Caffeine package and installed executable names. |
| `config/malware-analysis.psd1` | Bounded host-inspection rules, indicators, supported files, and case defaults. |
| `config/malware-analysis-tools.psd1` | Pinned capa/Ghidra archives and optional WinGet analysis tools. |
| `config/linux-homebrew.psd1` | Homebrew location and prerequisites inside the managed Debian WSL distribution. |
| `config/linux-automation.psd1` | Homebrew `uv` and pinned pyinfra state for Debian-local deploys. |
| `config/developer-docker.psd1` | Adopted rootful Docker state for Dagger in developer Debian. |
| `config/rootless-podman.psd1` | Dedicated clean Debian-MW and daemonless rootless Podman state for untrusted parsers. |
| `config/malware-container.psd1` | Pinned static-container image inventory, runtime boundary, and resource limits. |
| `config/profiling-tools.psd1` | Pinned profiler versions and the feature-scoped WPT bootstrap. |
| `config/capabilities.psd1` | Machine-readable investigation and routing catalog. |
| `config/skillopt.psd1` | Pinned SkillOpt package and conservative optimization defaults. |
| `profile/Shell.ps1` | Minimal managed profile-component loader. |
| `profile/Config.ps1` | PSReadLine, prompt, and native-command precedence. |
| `profile/Tools.ps1` | Reusable diagnostics and command implementations. |
| `profile/Aliases.ps1` | Short user-facing wrappers and Linux-style mappings. |
| `scripts/Set-PowerShellProfile.ps1` | Deploys and verifies the loader and components for both PowerShell runtimes. |
| `scripts/Invoke-WorkstationUpdate.ps1` | Plans or explicitly runs the complete dependency-ordered workstation update. |
| `scripts/Invoke-WindowsUpdate.ps1` | Scans or installs accepted Windows software updates without drivers or automatic restart. |
| `scripts/Set-LinuxHomebrewState.ps1` | Maintains Homebrew inside Debian WSL as a focused developer-package prerequisite. |
| `scripts/Set-LinuxAutomationState.ps1` | Maintains the Debian-local pyinfra executor without installing it into Windows Python. |
| `scripts/Set-DeveloperDockerState.ps1` | Maintains the existing rootful Dagger Docker daemon through local pyinfra. |
| `scripts/Set-RootlessPodmanState.ps1` | Provisions Debian-MW and maintains local rootless Podman through local pyinfra. |
| `scripts/Remove-LegacyDockerMwState.ps1` | Reports retained Debian-MW Docker data and removes it only with explicit destructive confirmation. |
| `scripts/Set-DeveloperToolsState.ps1` | Maintains CodeQL, Trail of Bits packs, Semgrep CE, pyinfra-managed Dagger through Homebrew, TTD, Debian rsync, and PoolMon tags. |
| `scripts/Set-GoState.ps1` | Maintains the official Go package, `GOPATH`, command path, and `GOTOOLCHAIN=auto` behavior without overriding MSI-owned `GOROOT`. |
| `scripts/Set-MalwareHashesState.ps1` | Installs and verifies the pinned `malware_hashes` Windows release for host and Sandbox use. |
| `scripts/Set-SpecDrivenDevelopmentState.ps1` | Maintains the release-pinned EARS/TDD Spec Kit tool in an isolated `uv tool` environment. |
| `scripts/Set-PesterState.ps1` | Observes or explicitly installs the exact per-user Pester release for both PowerShell runtimes. |
| `scripts/Invoke-PowerShellTests.ps1` | Runs standard test files through one human/JSON Pester command with bounded parallel and compatibility lanes. |
| `linux/developer_tools.py` | Human-runnable pyinfra desired state for Debian developer packages. |
| `scripts/Set-ProfilingToolsState.ps1` | Maintains WPT/WPA, py-spy, dotnet-trace, and the local Speedscope viewer. |
| `scripts/Invoke-NativeCpuProfile.ps1` | Records native/system CPU traces with WPR for WPA. |
| `scripts/Invoke-PythonProfile.ps1` | Records Python sampled stacks as standalone SVG flame graphs. |
| `scripts/Invoke-DotNetProfile.ps1` | Records .NET EventPipe traces and Speedscope data. |
| `scripts/Invoke-HeadlessDumpAnalysis.ps1` | Analyzes existing dumps headlessly with cdbX64 and CLI symbol downloads. |
| `scripts/Get-ProfilerStatus.ps1` | Reports profiler availability as PowerShell objects or JSON. |
| `scripts/Invoke-Tricky.ps1` | Maintains evidence-first cases and renders Markdown, JSON, and HTML reports. |
| `scripts/Invoke-SkillOpt.ps1` | Wraps review, mock validation, provider calls, staging, and explicit adoption. |
| `scripts/Set-SkillOptState.ps1` | Installs pinned SkillOpt and maintains its safe user configuration. |
| `scripts/Set-ScoopState.ps1` | Maintains per-user Scoop and official Main/Extras buckets. |
| `scripts/Set-NativeTextToolsState.ps1` | Maintains native Win32 `awk.exe` and `sed.exe` commands without Git Bash, MSYS, or Cygwin. |
| `scripts/Set-CaffeineState.ps1` | Maintains the Caffeine package and enabled active-at-launch per-user startup. |
| `scripts/Invoke-MalwareAnalysis.ps1` | Inspects bytes on the host, plans/launches explicit Sandbox jobs, and reports existing evidence. |
| `scripts/Invoke-MalwareSandboxRunner.ps1` | Guest-only document, reverse-engineering, and bounded detonation runner. |
| `scripts/Compare-MalwareEvidence.ps1` | Validates clean-control/target case compatibility and produces retained common-tool unified diffs. |
| `scripts/Set-MalwareAnalysisToolsState.ps1` | Tests or explicitly installs the opt-in analysis toolset. |
| `scripts/Set-MalwareContainerImageState.ps1` | Tests or explicitly builds the opt-in rootless static-parser image. |
| `scripts/Invoke-MalwareContainerAnalysis.ps1` | Plans or explicitly runs non-executing Office/PDF/binary parsing. |
| `scripts/Read-MalwareEvidence.ps1` | Delegates hostile result validation and canonicalization to a bounded Python boundary. |
| `scripts/Set-ContourTerminalState.ps1` | Installs the hash-pinned official Contour MSI, deploys the BlueTerm theme, and gates success on a bounded graphics smoke test. |
| `scripts/Set-TerminalFontState.ps1` | Installs and verifies Fira Code per-user from the hash-pinned official release. |
| `scripts/Test-RepositorySkills.ps1` | Validates all repo-local skill packages locally and in CI. |
| `scripts/Invoke-PowerShellLint.ps1` | Runs the pinned PSScriptAnalyzer policy on staged paths or the full tracked tree. |
| `scripts/Install-PreCommitHook.ps1` | Installs the isolated pre-commit CLI, pinned analyzer module, and local Git hook. |
| `scripts/Set-PoolMonState.ps1` | Copies the official WinDbg/WDK pool-tag database beside PoolMon. |
| `scripts/Set-SudoState.ps1` | Maintains Windows sudo in inline (`normal`) mode. |
| `scripts/Set-WindowsFeatureState.ps1` | Tests and enables declared Windows optional features without restarting Windows. |
| `scripts/Set-HardeningState.ps1` | Plans, tests, and ensures the reviewed hardening profile without restarting Windows. |
| `scripts/Set-DebloatState.ps1` | Plans and tests opt-in removals; Ensure requires explicit confirmation and records a snapshot. |
| `scripts/Set-FocusFollowsMouseState.ps1` | Gives hovered windows focus without changing their Z-order. |
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
| `.excluded.sample` | Public, machine-agnostic template for the ignored local Defender exclusion list. |
| `config/defender-exclusions.psd1` | Declares Defender performance policy and the local exclusion-list filename. |
| `config/wslconfig.ini` | Declares the global WSL 2 memory policy. |
| `config/eventlogs.psd1` | Declares channels, sizes, audit coverage, and archive rotation. |
| `config/taildrive-policy.hujson` | Tailnet policy fragment required for Taildrive. |
| `docs/Aliases.md` | Command reference and firewall behavior. |
| `.agents/skills` | Separate repo-local Codex workflows using the same commands as humans. |
| `mkdocs.yml` | Capability-focused documentation site. |
| `.github/workflows` | Strict Pages builds and version-tagged documentation releases. |
| `state/firewall-backups` | Generated full Windows Firewall backups. |

## Usage

Run from PowerShell 7:

```powershell
Copy-Item .excluded.sample .excluded
Copy-Item .wsl-env.sample .wsl-env
# Edit .excluded for this workstation.
# Set WSL_USER in .wsl-env; this workstation uses WSL_DISTRIBUTION=Debian.
.\Apply-Workstation.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Ensure
.\Apply-Workstation.ps1 -Mode Reinitialize
```

Update every managed surface with the same plan-first boundary:

```powershell
update
update -Json
update -Run
```

The first two commands are read-only plans. `update -Run` explicitly services Windows software
updates, ordinary WinGet and Scoop applications, WSL, both declared Debian distributions, the
declared developer Homebrew instance, developer Docker, and Debian-MW rootless Podman. It then
ensures and tests the current checkout's default non-destructive desired state. Drivers, automatic
reboots, WSL shutdown, container pruning, Scoop cleanup, pinned/unknown package overrides, and
undeclared distributions remain outside the command. See [Managed workstation update](docs/workstation-update.md).

`Ensure` is the normal operation. It leaves compliant Windows features, hardening controls, hover-focus behavior, profile, sudo, Defender exclusions, and firewall state untouched. `Reinitialize` is useful after troubleshooting: it reapplies local state and always rebuilds the managed firewall group after exporting a full `.wfw` backup.

Run one part at a time with inclusion-based module selection:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Firewall
.\Apply-Workstation.ps1 -Mode Ensure -Module Hardening
.\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Go -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareHashes -Plan
.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module WindowsTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareAnalysisTools -Plan
```

The module DSL has three dependency stages. `Inbox` uses only Windows PowerShell 5.1 and native Windows commands already present on a fresh Windows 11 Pro host; it configures Sudo and installs/tests PowerShell 7 without resolving `pwsh.exe`. `Core` begins only after the PowerShell 7 gate succeeds and provides foundational packages, profiles, testing, fonts, and terminals. `Extended` contains the remaining workstation capabilities. A failure in an earlier selected stage blocks later stages, and a dependency from an earlier stage to a later one is rejected. Planning is available before PowerShell 7 is installed.

Within those stages, Hardening pulls in Sudo; PowerShellTesting pulls in PowerShell 7; DeveloperTools pulls in Go, DeveloperDocker, LinuxAutomation, LinuxHomebrew, Packages, and PowerShell 7; Scoop pulls in Git; ContourTerminal pulls in Sudo, PowerShell 7, and TerminalFonts; WindowsTerminal pulls in PowerShell 7; MalwareAnalysisTools pulls in the verified `malware_hashes` release, Windows Sandbox, WPT, and package prerequisites; and MalwareContainerImage pulls in RootlessPodman. `-Module All` retains the default full run and includes neither Debloat, MalwareAnalysisTools, MalwareContainerImage, nor destructive LegacyDockerCleanup. [Sample outputs](docs/sample-outputs.md) show the human and JSON forms.

Defender exclusion paths are read from the ignored local `.excluded` file. Copy `.excluded.sample` after cloning and customize it; native Windows `%ENVIRONMENT_VARIABLE%` references are supported. The repository publishes no workstation-specific exclusion paths, and unrelated existing Defender exclusions are preserved.

Defender remains active outside those paths by default, but scheduled activity is idle-only, low-priority, throttled toward 15% average CPU, and does not run missed-scan catch-up jobs. Use `disable-defender` and `enable-defender` for an explicit elevated runtime toggle; neither command starts a scan. SmartScreen supports `Off`, `Medium` (`Warn` with override), and `Full` (`Block` without bypass). SaveZone/Mark-of-the-Web is controlled independently. Smart App Control is deliberately not changed.

WSL is capped at 10 GiB RAM with 4 GiB swap and gradual memory reclamation. Windows uses a 16 GiB initial and 32 GiB maximum pagefile; changing that policy requires a Windows restart.

The balanced event-log template keeps relevant live logs circular and generously sized, then exports a rolling 48-hour EVTX window every day. Generated ZIP archives are stored in `E:\Logs`, retained for at most 14 days, capped at 768 MiB total, and rotated early if E: has less than 128 MiB free. Staging occurs under ProgramData on C:. The scheduled exporter is copied into an administrator-controlled directory and runs as SYSTEM.

The package declarations include PowerShell 7, Windows Terminal, Go, Microsoft Coreutils, ripgrep, rclone, WinFsp, aria2, WinDbg, Sysinternals Suite, btop4win, uv, the .NET 10 SDK, Node.js LTS with its bundled npm and npx commands, Git, GitHub CLI (`gh`), Tailscale, WSL, and Debian. Both Windows PowerShell 5.1 and the newest installed PowerShell Core load the same managed prompt, aliases, tools, and readline-compatible behavior. Windows Terminal starts PowerShell Core by default, keeps Windows PowerShell selectable, and applies the shared Blue appearance through `profiles.defaults` while preserving unrelated profiles, keybindings, themes, and settings. Go uses its official MSI-backed WinGet package; projects select compatible released toolchains through Go's built-in `go.mod`/`go.work` and `GOTOOLCHAIN=auto` behavior. `GOROOT` remains owned by the MSI. Git has a focused declaration so Scoop can depend on it without testing every unrelated package. Scoop is maintained per-user with official Main and Extras buckets. Contour Terminal is installed separately from the exact official release MSI after SHA-256 verification; any legacy Scoop Contour package is removed first. The translated BlueTerm default and `blue-dark` profiles remain managed, and a bounded minimized-window gate verifies that Contour can initialize its graphics stack before the module reports compliance. The Windows-feature declaration enables Hyper-V and Windows Sandbox, includes required parent features, declares Sandbox's dependency on Hyper-V, and never restarts Windows automatically. The feature resource validates its dependency graph and applies it in topological order. The developer-tool state installs CodeQL with pinned verification, public Trail of Bits query packs, Semgrep CE through an isolated uv environment, Dagger through Homebrew inside Debian WSL, standalone TTD, Debian rsync, and the official PoolMon tag database. The profiling state installs only the Windows Performance Toolkit feature from the ADK, py-spy through an isolated uv environment, dotnet-trace as a global .NET tool, and Speedscope as a local CLI/browser viewer. SkillOpt 0.2.0 is another isolated `uv tool`. None of these use or modify the AMD/PyTorch Python environment.

Native `awk.exe` and `sed.exe` are maintained through the focused `NativeTextTools` WinGet module for PowerShell. This does not install or use Git Bash, MinGit, Cygwin, MSYS, or MSYS2. The native BusyBox host is not Bash; it contains an unused `ash`-style shell applet, while desired state exposes only `awk` and `sed`. See [Native awk and sed for PowerShell](docs/native-text-tools.md).

Zhorn Software Caffeine is maintained as a focused WinGet module. Desired state installs the real portable utility and registers it to start active at sign-in, with no `-startoff` flag. The `caffeine` wrapper launches its verified 64-bit executable on demand, and the tray icon toggles inhibition.

Suspicious-file commands begin with bounded byte inspection: `is-this-malware <path>`. Target Sandbox plans also run the hash-pinned `malware_hashes` release against the bounded host source and arrange an independent run against the read-only guest copy; clean controls skip both. Raw host and guest reports remain segregated evidence, and only the bounded Python ingestor compares their deterministic hashes or exposes their source paths. `disass`, `decomp`, and `malware-sandbox` create reviewable Windows Sandbox plans by default; `-Run -ConfirmSandbox` is required to launch, detonation also requires `-ConfirmExecution`, and networking remains off unless separately enabled. `malware-container` similarly plans non-executing rootless Office/PDF/binary parsing and requires `-Run -ConfirmContainer`; its large local image is a separate opt-in module. `sandbox-behavior-control`, `sandbox-behavior-target`, and `sandbox-behavior-diff` expose the same differential engine for general programs. `binary-diff OLD NEW` uses Ghidra/BinExport call and control-flow graphs plus BinDiff as its canonical comparison; the separate SQLite code sidecar never replaces graph matching with raw bytes, versions, or decompiler text. `malware-control` and `malware-container-control` create matched clean controls. `malware-diff` retains canonical evidence trees and uses native Git's ordinary no-index unified diff without deserializing raw traces or parser output in PowerShell. Same-hash static and dynamic cases are cross-linked without treating static indicators as proof of execution. Documents are dissected as inert containers and never opened automatically in licensed Office. See [Suspicious-file analysis](docs/malware-analysis.md) and [Analysis and differencing cases](docs/analysis-differencing.md).

## Automatic versus explicit actions

`Apply-Workstation.ps1 -Mode Ensure` automatically installs or repairs the declared WinGet packages, Hyper-V and Windows Sandbox features, `DeveloperBaseline` hardening controls, current-user focus-follows-mouse behavior, developer CLIs, required profiling tools, SkillOpt, and its conservative local configuration. Hover focus does not raise or reorder windows. Windows features and hardening are applied through explicit elevated resources and never restart Windows; rebooting remains a user action. WPT uses a separate idempotent resource so only `OptionId.WindowsPerformanceToolkit` is installed rather than the complete ADK. AMD uProf remains explicit because AMD requires interactive EULA acceptance; `uprof-install` opens the official download page and desired state reports whether it was installed.

Desired state never configures rclone credentials, creates a persistent cloud mount, signs into Semgrep, starts a Semgrep/CodeQL scan, records a performance or TTD trace, attaches a debugger, captures a crash dump, or registers a machine-wide postmortem debugger. Those actions remain explicit shell commands.

The optional malware-analysis toolset is also excluded from the default run. Analysis commands never silently install tools, launch Windows Sandbox, execute a sample, enable Sandbox networking, upload content, or transfer Microsoft 365 identity. Each boundary has an explicit human command and confirmation switch.

Debloating is never automatic. The separate `DeveloperMinimal` profile can inventory installed/provisioned apps and legacy components through its direct resource or `-Module Debloat`, but removal always requires `-ConfirmRemoval`. Package management, runtimes, codecs, OpenSSH, Windows Hello, WSL, Debian, and Codex are protected from that profile.

It also never harvests Codex transcripts, contacts a model provider for SkillOpt, schedules optimization, or adopts generated skill edits. Those steps require reviewed task evidence and explicit commands.

The SkillOpt resource pins the stable PyPI package only. It does not install the mutable source tree, global SkillOpt plugin, WebUI, benchmark extras, or local-model stacks.

Repository hooks are explicit because `.git/hooks` is local state. Run `precommit-install` once per clone; it installs `pre-commit==4.6.2` as an isolated uv tool and PSScriptAnalyzer 1.25.0 for the current user. The hook lints staged PowerShell files, while `precommit-run` checks the complete tracked tree.

PowerShell tests use exact Pester 6.1.0 from the shared per-user WindowsPowerShell module tree so PowerShell 7 and inbox Windows PowerShell resolve the same framework. `test-powershell` discovers standard `*.Tests.ps1` files and uses bounded file-level parallel execution under PowerShell 7.4 or newer. `test-powershell -Compatibility` dispatches the compatible suite sequentially through Windows PowerShell 5.1. Files needing exclusive or live-state access use `#pester:no-parallel`. Test execution never installs Pester; inspect or repair it separately with the `PowerShellTesting` module.

The full WDK is not installed automatically because WinDbg supplies the required `pooltag.txt`. If that source disappears, `Set-PoolMonState.ps1` reports the explicit fallback command instead of silently installing the large WDK.

Docker Engine and Compose remain Linux-native but are now reached through the PowerShell module DSL and applied by local pyinfra inside each distribution. `Debian` keeps a rootful daemon for Dagger; `Debian-MW` keeps a separate rootless daemon for the implemented inert static parser. Python deploy and container code is checked through the pinned `lint-python` Ruff command.

See [Workstation modules and dependency order](docs/workstation-modules.md) for focused execution. See [Suspicious-file analysis](docs/malware-analysis.md) for isolation, telemetry limits, and residual attack surface. See [Analysis and differencing cases](docs/analysis-differencing.md) for general Sandbox behavior and graph-first binary comparison. See [Contour Terminal and BlueTerm](docs/contour-terminal.md) for the official MSI, Scoop migration, and theme translation. See [Windows hardening profile and attack surface](docs/hardening.md) for the legacy-script review, compatibility costs, and residual exposure. See [Opt-in Windows debloat profile](docs/debloat.md) for the exact removal allowlist and rollback limits. See [docs/Aliases.md](docs/Aliases.md) for daily commands.
