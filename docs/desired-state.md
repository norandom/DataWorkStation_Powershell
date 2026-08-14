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

Run only one declared part with `-Module`, and inspect dependency order first with `-Plan`:

```powershell
./Apply-Workstation.ps1 -Mode Test -Module Firewall
./Apply-Workstation.ps1 -Mode Test -Module Hardening -Plan
./Apply-Workstation.ps1 -Mode Test -Module WindowsFeatures,Hardening
```

`config/workstation-modules.psd1` declares the module catalog, default selection, supported modes, and dependencies. Dependencies are included automatically in topological order. `-Module All` preserves the complete default run but excludes the destructive Debloat module. See [Workstation modules and dependency order](workstation-modules.md).

## Automatically maintained

The declared package set, Windows optional features, developer hardening profile, current-user hover-focus behavior, profiles, inline Windows sudo, firewall rules, Defender exclusions, SmartScreen baseline, WSL/pagefile limits, event-log retention, developer CLIs, PoolMon tags, and profiling tools are automatically maintained unless their skip switch is supplied.

`config/windows-features.psd1` declares Hyper-V and Windows Sandbox, with Sandbox explicitly depending on Hyper-V. The resource validates missing dependencies and cycles, then applies features in topological order. Inspect that order without elevation by running `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan`. `Apply-Workstation.ps1` bootstraps the inbox Windows sudo configuration before any resource invokes `sudo`. The feature resource uses inbox Windows PowerShell because the DISM module is not reliably hosted by PowerShell 7. Inspect only the elevated feature state with `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test`, or repair it with the same command and `-Mode Ensure`. Enabling a feature never restarts Windows automatically; restart explicitly if the command reports that one is required. Use `-SkipWindowsFeatures` on `Apply-Workstation.ps1` to omit this resource.

`config/hardening-profiles.psd1` declares the `DeveloperBaseline` security controls. Inspect its plan without elevation with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan`. Compare or repair the machine with the same script through `sudo` and `-Mode Test` or `-Mode Ensure`. The resource applies registry, SMB runtime, optional-feature, and per-adapter NetBIOS state; it never restarts Windows. Use `-SkipHardening` to omit it. The exact controls, rejected legacy settings, compatibility costs, and residual exposure are documented in [Windows hardening profile and attack surface](hardening.md).

`config/focus-follows-mouse.psd1` enables current-user active-window tracking with a 0 ms delay while explicitly disabling raise-on-focus. Windows therefore directs keyboard focus to the hovered window without bringing it to the top or changing its Z-order. In Windows API terminology that window becomes active/foreground because it owns keyboard input, while the separately managed Z-order remains unchanged. The resource uses Microsoft's documented [active-window tracking parameters](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-systemparametersinfow). Inspect it with `pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test` or repair it by using `-Mode Ensure`. This resource does not require elevation. Use `-SkipFocusFollowsMouse` on `Apply-Workstation.ps1` to omit it.

Defender exclusion paths are local state in ignored `.excluded`; `.excluded.sample` documents the portable format. Desired state refuses to guess paths when the local file is absent.

SkillOpt 0.2.0 is installed automatically through an isolated `uv tool` environment. Desired state also enforces validation gating, mock backend defaults, no auto-adoption, no `CLAUDE.md` evolution, and no evidence log. Use `-SkipSkillOpt` to omit this resource.

Only the stable base package is installed. SkillOpt's source checkout, global plugin, WebUI, benchmark environments, local-model stacks, and optional provider SDK extras are excluded.

## Explicit by design

Credentials, rclone mounts, code scans, packet/ETW/TTD recordings, debugger attachment, crash reproduction, process termination, AMD uProf EULA acceptance, and security protection toggles remain explicit actions.

Software removal is also explicit. `config/debloat-profiles.psd1` declares the opt-in `DeveloperMinimal` profile, which is excluded from `-Module All` and runs only when `-Module Debloat` is named. Use Test first. Ensure refuses to proceed without `-ConfirmRemoval` and writes a pre-removal inventory. See [Opt-in Windows debloat profile](debloat.md) for protected packages and rollback limits.

SkillOpt transcript harvesting, task approval, provider-backed optimization, scheduling, and proposal adoption also remain explicit. Scheduling and automatic adoption are intentionally absent from the managed wrapper.

MkDocs is also not a global workstation dependency. Its exact version is locked in `uv.lock` and materialized only for this repository.
