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

SkillOpt 0.2.0 is installed automatically through an isolated `uv tool` environment. Desired state also enforces validation gating, mock backend defaults, no auto-adoption, no `CLAUDE.md` evolution, and no evidence log. Use `-SkipSkillOpt` to omit this resource.

Only the stable base package is installed. SkillOpt's source checkout, global plugin, WebUI, benchmark environments, local-model stacks, and optional provider SDK extras are excluded.

## Explicit by design

Credentials, rclone mounts, code scans, packet/ETW/TTD recordings, debugger attachment, crash reproduction, process termination, AMD uProf EULA acceptance, and security protection toggles remain explicit actions.

SkillOpt transcript harvesting, task approval, provider-backed optimization, scheduling, and proposal adoption also remain explicit. Scheduling and automatic adoption are intentionally absent from the managed wrapper.

MkDocs is also not a global workstation dependency. Its exact version is locked in `uv.lock` and materialized only for this repository.
