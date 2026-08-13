# Desired state

`Apply-Workstation.ps1` composes WinGet Configuration with focused idempotent PowerShell resources.

```powershell
./Apply-Workstation.ps1 -Mode Test
./Apply-Workstation.ps1 -Mode Ensure
./Apply-Workstation.ps1 -Mode Reinitialize
```

- `Test` reports drift.
- `Ensure` installs or repairs declared state.
- `Reinitialize` rebuilds state such as managed firewall rules after preserving a backup.

## Automatically maintained

The declared package set, profiles, inline Windows sudo, firewall rules, Defender exclusions, SmartScreen baseline, WSL/pagefile limits, event-log retention, developer CLIs, PoolMon tags, and profiling tools are automatically maintained unless their skip switch is supplied.

## Explicit by design

Credentials, rclone mounts, code scans, packet/ETW/TTD recordings, debugger attachment, crash reproduction, process termination, AMD uProf EULA acceptance, and security protection toggles remain explicit actions.

MkDocs is also not a global workstation dependency. Its exact version is locked in `uv.lock` and materialized only for this repository.
