# Contract: PowerShell testing desired state

## Human interface

```powershell
.\scripts\Set-PesterState.ps1 -Mode Test
.\scripts\Set-PesterState.ps1 -Mode Ensure
.\Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan
```

Test reports the declared version, each runtime's resolution, shared user path, compliance, and
pending changes without writing files or contacting the package repository. Ensure is an explicit
per-user networked module installation and requires no elevation.

## Machine interface

```powershell
.\scripts\Set-PesterState.ps1 -Mode Test -Json
```

The bounded JSON schema contains `SchemaVersion`, `Status`, `DeclaredVersion`, `ModuleBase`,
`PowerShell7Version`, `WindowsPowerShellVersion`, and `PendingChanges`.
