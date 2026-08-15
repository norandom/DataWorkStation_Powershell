# Workstation CLI Contract

## Plan before state

Human-readable plan:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Firewall -Plan
```

Contract:

- `-Plan` emits ordered module rows with stage, runtime, dependency, privilege, destructive, and
  description data.
- `-Plan` does not invoke resource scripts or package configuration.
- Focused selection includes transitive dependencies and excludes unrelated modules.
- A missing dependency or dependency cycle is an error.
- A module dependency on a later stage is an error.
- Planning and the Inbox stage do not resolve PowerShell 7.
- Later stages are blocked when an earlier selected stage fails.

## Test and mutation

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module <name>
.\Apply-Workstation.ps1 -Mode Ensure -Module <name>
.\Apply-Workstation.ps1 -Mode Reinitialize -Module <name>
```

Contract:

- `Test` is observational.
- `Ensure` repairs only the resolved module closure.
- `Reinitialize` is available only for modules declaring that mode.
- Privileged resources cross elevation through their explicit command boundary.
- Destructive resources require their dedicated confirmation contract and are absent from the
  default run.
- No orchestration mode restarts Windows automatically.

## Dual-shell resource

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
```

Both supported invocations return the same resource states and differ only in normal host-shell
formatting.

## Bootstrap stages

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan
```

The Inbox stage relies only on Windows PowerShell 5.1 and built-in Windows commands. After the
PowerShell 7 module succeeds, Core and Extended modules may resolve `pwsh.exe`. A plan remains
available even when PowerShell 7 is absent.

## Result conventions

- Human-readable tables or messages are the default.
- A failing resource produces an actionable error and a nonzero process exit where the command is a
  gate.
- State-changing modes are never inferred from a diagnostic or plan command.
