# Workstation modules and dependency order

`Apply-Workstation.ps1` can run the complete default desired state or an inclusion-based subset. Each module maps to one focused resource or package stage.

## Plan before running

Show the default execution order without testing or changing state:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Plan
```

Show the dependencies pulled in for one module:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Hardening -Plan
.\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Go -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareHashes -Plan
.\Apply-Workstation.ps1 -Mode Test -Module SpecDrivenDevelopment -Plan
.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module MalwareAnalysisTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module RootlessDocker -Plan
```

Add `-Json` to `-Plan` for machine-readable output. Plan mode validates module names, missing dependencies, cycles, exclusions, and mode compatibility without invoking a resource.

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

Dependencies are included automatically and run first. For example, `Hardening` resolves to `Sudo → Hardening`, `DeveloperTools` includes `Go` plus `PowerShell7 → Packages → LinuxHomebrew → LinuxAutomation → DeveloperDocker` before `DeveloperTools`, `SpecDrivenDevelopment` resolves to `PowerShell7 → Packages → SpecDrivenDevelopment`, and `MalwareAnalysisTools` includes `MalwareHashes`, `Sudo → WindowsFeatures`, `PowerShell7 → Packages`, and `ProfilingTools`. `MalwareContainerImage` resolves to `RootlessDocker → MalwareContainerImage`. `Scoop` resolves to `Git → Scoop`, and `ContourTerminal` includes `Sudo`, `PowerShell7`, and `PowerShell7 → TerminalFonts` before Contour. A dependent module is skipped if its selected dependency fails. See [Sample outputs](sample-outputs.md) for the rendered plan.

## Module catalog

The routing DSL is `config/workstation-modules.psd1`.

| Module | Default | Dependency | Purpose |
|---|---:|---|---|
| `Sudo` | yes | — | bootstrap Windows sudo inline mode |
| `Git` | yes | — | focused WinGet Configuration state for Scoop's Git dependency |
| `PowerShell7` | yes | — | focused WinGet Configuration state for PowerShell 7 |
| `Go` | yes | — | official MSI-backed Go package, user workspace, command path, and built-in toolchain selection |
| `Packages` | yes | `PowerShell7` | WinGet Configuration packages |
| `NativeTextTools` | yes | — | focused native Win32 `awk.exe` and `sed.exe` package, shims, and smoke tests |
| `Caffeine` | yes | — | Zhorn Software Caffeine package with enabled, active-at-launch per-user startup |
| `Scoop` | yes | `Git` | per-user Scoop with official Main and Extras buckets |
| `TerminalFonts` | yes | `PowerShell7` | hash-pinned per-user Fira Code installation |
| `ContourTerminal` | yes | `Sudo`, `PowerShell7`, `TerminalFonts` | official machine-wide Contour MSI, translated BlueTerm theme, local font selection, and bounded graphics-compatibility gate |
| `WindowsFeatures` | yes | `Sudo` | Hyper-V and Windows Sandbox |
| `Hardening` | yes | `Sudo` | `DeveloperBaseline` security controls |
| `LinuxHomebrew` | no | `Packages` | Homebrew inside Debian WSL; pulled in by the developer bundle |
| `LinuxAutomation` | no | `LinuxHomebrew` | Homebrew `uv` and pinned pyinfra inside Debian WSL |
| `DeveloperDocker` | no | `LinuxAutomation` | pyinfra-adopted rootful Docker daemon in Debian for Dagger |
| `RootlessDocker` | yes | — | clean Debian-MW distro with local pyinfra and rootless Docker |
| `DeveloperTools` | yes | `DeveloperDocker`, `Go` | Go, CodeQL, Semgrep, pyinfra-managed Dagger, TTD, rsync, and PoolMon support |
| `SpecDrivenDevelopment` | yes | `Packages` | release-pinned Spec Kit EARS/TDD tool and validator |
| `MalwareHashes` | yes | — | hash-pinned v2.4.0 Windows executable from the project's GitHub release |
| `MalwareAnalysisTools` | **no** | `Packages`, `WindowsFeatures`, `ProfilingTools`, `MalwareHashes` | opt-in isolated parsers and telemetry tools |
| `MalwareContainerImage` | **no** | `RootlessDocker` | opt-in local build of the pinned rootless static-parser image |
| `ProfilingTools` | yes | `Packages` | WPT, py-spy, dotnet-trace, and Speedscope |
| `SkillOpt` | yes | `Packages` | pinned SkillOpt and conservative defaults |
| `PowerShellProfile` | yes | `PowerShell7` | managed profile components |
| `FocusFollowsMouse` | yes | — | hover focus without raising |
| `DefenderExclusions` | yes | `Sudo` | local exclusions and performance policy |
| `SmartScreen` | yes | `Sudo` | warning/override policy |
| `WslMemory` | yes | — | WSL memory and swap limits |
| `Pagefile` | yes | `Sudo` | Windows pagefile policy |
| `EventLogs` | yes | `Sudo` | audit channels and EVTX export |
| `Firewall` | yes | `Sudo` | managed firewall profiles and allowlist |
| `Debloat` | **no** | `Sudo` | opt-in software removal profile |

`-Module All` selects only modules marked default. It never includes `Debloat`.

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
