# Workstation modules and dependency order

`Apply-Workstation.ps1` can run the complete default desired state or selected modules. Each module
maps to one focused resource or package stage.

## Plan before running

Show the default execution order without testing or changing state:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Plan
```

Show the dependencies pulled in for one module:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Hardening -Plan
.\Apply-Workstation.ps1 -Mode Test -Module ExploitProtection -Plan
.\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Go -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareHashes -Plan
.\Apply-Workstation.ps1 -Mode Test -Module SpecDrivenDevelopment -Plan
.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module WindowsTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareAnalysisTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module RootlessPodman -Plan
.\Apply-Workstation.ps1 -Mode Test -Module NixOsWsl,SharedSshConfig -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Autopsy -Plan
```

Add `-Json` to `-Plan` for machine-readable output. Every row includes `Stage` and `Runtime`. Plan
mode validates module and stage names, dependency direction, missing dependencies, cycles,
exclusions, and mode compatibility. It does not invoke a resource or resolve PowerShell 7.

## Dependency stages

| Stage | Available runtime | Gate | Modules |
|---|---|---|---|
| `Inbox` | Windows PowerShell 5.1 or native Windows executable | none | `Sudo`, `PowerShell7` |
| `Core` | PowerShell 7, inbox shell when explicitly declared, or native executable | `PowerShell7` | Git/packages, test framework, Go, native text tools, Caffeine, Scoop, fonts, both terminals, and the shared PowerShell profile |
| `Extended` | declared runtime after Core is compliant | `PowerShell7` | Windows features and policy, WSL environments, developer tools, diagnostics, malware-analysis tooling, and optional debloat |

Selecting a Core or Extended module automatically includes its stage gate. The `PowerShell7` module itself is a native WinGet operation in the Inbox stage. Therefore this fresh-host command is valid even when `pwsh.exe` is absent:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan
```

After a successful PowerShell 7 install, the orchestrator resolves the executable lazily and also checks `C:\Program Files\PowerShell\7\pwsh.exe` so it does not depend on a `PATH` refresh in the current process. A failed selected stage blocks later stages.

## Run one module

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Firewall
.\Apply-Workstation.ps1 -Mode Ensure -Module Hardening
.\Apply-Workstation.ps1 -Mode Test -Module FocusFollowsMouse
```

Select several modules with a comma-separated PowerShell array:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module WindowsFeatures,Hardening,Firewall
```

Dependencies and stage gates are included automatically and run first. For example, `Hardening` resolves to the PowerShell 7 stage gate plus `Sudo → Hardening`, `PowerShellTesting` resolves to `PowerShell7 → PowerShellTesting`, `DeveloperTools` includes Go plus `PowerShell7 → Packages → LinuxHomebrew → LinuxAutomation → DeveloperDocker` before `DeveloperTools`, `SpecDrivenDevelopment` resolves to `PowerShell7 → Packages → SpecDrivenDevelopment`, and `MalwareAnalysisTools` includes `MalwareHashes`, `Sudo → WindowsFeatures`, `PowerShell7 → Packages`, and `ProfilingTools`. `MalwareContainerImage` resolves to `PowerShell7 → RootlessPodman → MalwareContainerImage`. `Scoop` resolves to `PowerShell7 → Git → Scoop`; `ContourTerminal` includes Sudo, PowerShell 7, and TerminalFonts; and `WindowsTerminal` resolves to `PowerShell7 → WindowsTerminal`. A dependent module is skipped if its dependency fails, and a later stage is skipped if an earlier stage fails. See [Sample outputs](sample-outputs.md) for the rendered plan.

## Native development modules

| Module | Purpose | Dependencies | Default |
|---|---|---|---|
| `MsvcBuildTools` | Standalone x64/x86 compiler, Windows SDK, linker, and MSBuild | `Sudo`, `PowerShell7` | No |
| `CMake` | Native CMake and Ninja | `PowerShell7` | No |
| `RustToolchain` | Stable x64 MSVC Rust through rustup | `MsvcBuildTools`, `PowerShell7` | No |
| `JavaToolchain` | Microsoft OpenJDK 21, `JAVA_HOME`, `java`, and `javac` | `PowerShell7` | No |
| `NativeDevelopment` | Aggregate plus explicit dual-shell `msvc-activate` command | all above, `PowerShellProfile` | Yes |

Use `-Plan` to see the compatible dependency order before running a focused module.

## Module catalog

The routing DSL is `config/workstation-modules.psd1`.

| Module | Default | Dependency | Purpose |
|---|---:|---|---|
| `Sudo` | yes | none | bootstrap Windows sudo inline mode |
| `Git` | yes | none | focused WinGet Configuration state for Scoop's Git dependency |
| `PowerShell7` | yes | none | focused WinGet Configuration state for PowerShell 7 |
| `PowerShellTesting` | yes | `PowerShell7` | exact Pester release shared by bounded parallel and compatibility test lanes |
| `Go` | yes | none | official MSI-backed Go package, user workspace, command path, and built-in toolchain selection |
| `Packages` | yes | `PowerShell7` | WinGet Configuration packages |
| `NativeTextTools` | yes | none | focused native Win32 `awk.exe` and `sed.exe` package, shims, and smoke tests |
| `Caffeine` | yes | none | Zhorn Software Caffeine package with enabled, active-at-launch per-user startup |
| `Scoop` | yes | `Git` | per-user Scoop with official Main and Extras buckets |
| `TerminalFonts` | yes | `PowerShell7` | hash-pinned per-user Fira Code installation |
| `ContourTerminal` | yes | `Sudo`, `PowerShell7`, `TerminalFonts` | official machine-wide Contour MSI, translated BlueTerm theme, local font selection, and bounded graphics-compatibility gate |
| `WindowsTerminal` | yes | `PowerShell7` stage gate | stable package, PowerShell Core default, retained Windows PowerShell profile, and shared Blue appearance |
| `WindowsFeatures` | yes | `Sudo` | Hyper-V and Windows Sandbox |
| `Hardening` | yes | `Sudo` | `DeveloperBaseline` security controls |
| `ExploitProtection` | yes | `Sudo` | Captured and recommended DEP, ASLR, SEHOP, heap, and related process mitigations |
| `LinuxHomebrew` | no | `Packages` | Homebrew inside Debian WSL; pulled in by the developer bundle |
| `LinuxAutomation` | no | `LinuxHomebrew` | Homebrew `uv` and pinned pyinfra inside Debian WSL |
| `NixOsWsl` | yes | `Packages` | locked NixOS-WSL generation with Helm, kubectl, Pulumi CLI, native OpenSSH, and integrity checks |
| `SharedSshConfig` | yes | `NixOsWsl` | canonical Windows SSH config linked only into trusted Debian; restricted WSLs excluded |
| `AiNixOsWsl` | **no** | `Packages` | restricted NixOS-AI generation with OpenCode, maintenance-owned nono, and fail-closed integrity checks |
| `DeveloperDocker` | no | `LinuxAutomation` | pyinfra-adopted rootful Docker daemon in Debian for Dagger |
| `RootlessPodman` | yes | none | clean Debian-MW distro with local pyinfra and daemonless rootless Podman |
| `DeveloperTools` | yes | `DeveloperDocker`, `Go` | Go, CodeQL, Semgrep, pyinfra-managed Dagger, TTD, rsync, and PoolMon support |
| `AiTools` | **no** | `Packages` | OpenCode Desktop, Claude Code, Antigravity, Cline, and Copilot CLI through reviewed channels |
| `DeveloperEditor` | yes | `PowerShell7`, `TerminalFonts` | stable VS Code, pinned Berg source, Cline/Jupyter/Python/Copilot extensions, and selected font |
| `SpecDrivenDevelopment` | yes | `Packages` | release-pinned Spec Kit EARS/TDD tool and validator |
| `MalwareHashes` | yes | none | hash-pinned v2.5.0 Windows executable from the project's GitHub release |
| `QuantResearchEnvironment` | **no** | `Packages`, `PowerShellProfile` | independently locked uv/OpenBB projects, project-local notebooks, and licensed PyXLL Excel integration |
| `SleuthKitCli` | **no** | `PowerShell7` | matching official native Windows TSK command suite on the user PATH |
| `Autopsy` | **no** | `Sudo`, `PowerShell7`, `PowerShellProfile`, `SleuthKitCli` | signed Windows GUI MSI, private CLI bindings, case root, and Defender exclusions |
| `MalwareAnalysisTools` | **no** | `Packages`, `WindowsFeatures`, `ProfilingTools`, `MalwareHashes` | opt-in isolated parsers and telemetry tools |
| `MalwareContainerImage` | **no** | `RootlessPodman` | opt-in local build of the pinned rootless static-parser image |
| `LegacyDockerCleanup` | **no** | `RootlessPodman` | destructive removal of retained Debian-MW Docker data after explicit confirmation |
| `ProfilingTools` | yes | `Packages` | WPT, py-spy, dotnet-trace, and Speedscope |
| `SkillOpt` | yes | `Packages` | pinned SkillOpt and conservative defaults |
| `PowerShellProfile` | yes | `PowerShell7` | managed profile components |
| `FocusFollowsMouse` | yes | none | hover focus without raising |
| `DefenderExclusions` | yes | `Sudo` | local exclusions and performance policy |
| `SmartScreen` | yes | `Sudo` | warning/override policy |
| `WslMemory` | yes | none | WSL memory and swap limits |
| `Pagefile` | yes | `Sudo` | Windows pagefile policy |
| `EventLogs` | yes | `Sudo` | audit channels and EVTX export |
| `Firewall` | yes | `Sudo` | default-block profiles, named service rules, and expert-approved local application rules |
| `Debloat` | **no** | `Sudo` | opt-in software removal profile |

`-Module All` selects only modules marked default. It never includes `Autopsy`, `SleuthKitCli`,
`NativeForensicTools`, `QuantResearchEnvironment`, or `Debloat`.

`QuantResearchEnvironment` is opt-in because dependency synchronization can be large and doctoral
research state is user-owned. `Test` is observational. `Ensure` exact-syncs generated environments
from existing locks, and `Reinitialize` replaces only `.venv` with rollback. The module never owns
notebooks, research source, datasets, exports, credentials, or the deferred Source junction. PyXLL
uses the base environment; its ignored license, payload, Excel registration, and active config stay
local, and first installation requires a dedicated explicit switch.

## Explicit debloat module

Debloat can be inventoried through the same interface:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Debloat
```

Removal still requires the extra destructive acknowledgement:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module Debloat -ConfirmRemoval
```

`Debloat` does not support `Reinitialize`. The orchestrator rejects that combination before invoking Sudo or a removal resource.

## Backward compatibility

The existing `-Skip...` switches remain available for a default `All` run. A skipped dependency is treated as already satisfied outside the current invocation, matching the old behavior. Do not combine explicit module names with skip switches; the orchestrator rejects ambiguous selection.

Direct resource commands remain supported when their more specialized parameters are needed.
