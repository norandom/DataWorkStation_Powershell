# Windows workstation desired state

This repository maintains a Linux-friendly PowerShell environment without using the legacy DSC MOF/LCM model. WinGet Configuration uses the current DSC v3 processor for packages; small idempotent PowerShell resources maintain the user profiles, Windows sudo, btop preferences, and firewall policy.

## Layout

| Path | Responsibility |
|---|---|
| `.config/configuration.winget` | Declarative WinGet package state, including `uv`. |
| `profile/Shell.ps1` | Managed PowerShell profile block. |
| `scripts/Set-PowerShellProfile.ps1` | Tests, ensures, or reapplies both user profile files. |
| `scripts/Set-SudoState.ps1` | Maintains Windows sudo in inline (`normal`) mode. |
| `scripts/Set-DefenderExclusionState.ps1` | Maintains the declared Microsoft Defender path exclusions. |
| `scripts/Set-SmartScreenState.ps1` | Keeps SmartScreen enabled in warning/override mode. |
| `scripts/Set-WslState.ps1` | Maintains the WSL memory and swap limits. |
| `scripts/Set-PagefileState.ps1` | Maintains a 16-32 GiB Windows pagefile policy. |
| `scripts/Set-EventLogState.ps1` | Maintains the balanced audit channels and scheduled EVTX archive task. |
| `scripts/Get-EventTriage.ps1` | Normalizes operational, crash, logon, remote, and security event views. |
| `scripts/ssh-copy-id.ps1` | Installs an OpenSSH public key on a POSIX SSH target. |
| `scripts/Set-FirewallState.ps1` | Tests, ensures, reinitializes, removes, or restores the firewall state. |
| `config/defender-exclusions.psd1` | Declares paths excluded from Microsoft Defender scanning. |
| `config/wslconfig.ini` | Declares the global WSL 2 memory policy. |
| `config/eventlogs.psd1` | Declares channels, sizes, audit coverage, and archive rotation. |
| `config/taildrive-policy.hujson` | Tailnet policy fragment required for Taildrive. |
| `docs/Aliases.md` | Command reference and firewall behavior. |
| `state/firewall-backups` | Generated full Windows Firewall backups. |

## Usage

Run from PowerShell 7:

```powershell
.\Apply-Workstation.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Ensure
.\Apply-Workstation.ps1 -Mode Reinitialize
```

`Ensure` is the normal operation. It leaves compliant profile, sudo, Defender exclusions, and firewall state untouched. `Reinitialize` is useful after troubleshooting: it reapplies local state and always rebuilds the managed firewall group after exporting a full `.wfw` backup.

The Defender exclusions are `D:\` and `%USERPROFILE%\Source`. The entire D: volume is intentionally excluded from real-time and scheduled Defender scanning. Unrelated exclusions are preserved.

Defender remains active outside those paths, but scheduled activity is idle-only, low-priority, throttled toward 15% average CPU, and does not run missed-scan catch-up jobs. SmartScreen remains enabled at `Warn`, allowing an explicit override for known tools. Smart App Control is deliberately not changed.

WSL is capped at 10 GiB RAM with 4 GiB swap and gradual memory reclamation. Windows uses a 16 GiB initial and 32 GiB maximum pagefile; changing that policy requires a Windows restart.

The balanced event-log template keeps relevant live logs circular and generously sized, then exports a rolling 48-hour EVTX window every day. Generated ZIP archives are stored in `E:\Logs`, retained for at most 14 days, capped at 768 MiB total, and rotated early if E: has less than 128 MiB free. Staging occurs under ProgramData on C:. The scheduled exporter is copied into an administrator-controlled directory and runs as SYSTEM.

The package declaration includes PowerShell 7, Microsoft Coreutils, ripgrep, Sysinternals Suite, btop4win, uv, GitHub CLI (`gh`), Tailscale, WSL, and Debian. Docker Engine and Compose inside Debian WSL remain separate because Linux repository configuration and daemon state belong inside the distribution rather than the Windows package configuration.

See [docs/Aliases.md](docs/Aliases.md) for daily commands and the exact network exposure model.
