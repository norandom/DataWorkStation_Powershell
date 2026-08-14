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

Dependencies are included automatically and run first. For example, `Hardening` resolves to `Sudo → Hardening`, while `DeveloperTools` resolves to `Packages → DeveloperTools`. A dependent module is skipped if its selected dependency fails.

## Module catalog

The routing DSL is `config/workstation-modules.psd1`.

| Module | Default | Dependency | Purpose |
|---|---:|---|---|
| `Sudo` | yes | — | bootstrap Windows sudo inline mode |
| `Packages` | yes | — | WinGet Configuration packages |
| `WindowsFeatures` | yes | `Sudo` | Hyper-V and Windows Sandbox |
| `Hardening` | yes | `Sudo` | `DeveloperBaseline` security controls |
| `DeveloperTools` | yes | `Packages` | CodeQL, Semgrep, TTD, rsync, and PoolMon support |
| `ProfilingTools` | yes | `Packages` | WPT, py-spy, dotnet-trace, and Speedscope |
| `SkillOpt` | yes | `Packages` | pinned SkillOpt and conservative defaults |
| `PowerShellProfile` | yes | — | managed profile components |
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
