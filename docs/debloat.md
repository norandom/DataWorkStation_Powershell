# Opt-in Windows debloat profile

The `DeveloperMinimal` profile removes a reviewed subset of consumer, promotional, and retired Windows software. It is separate from security hardening and excluded from the default `Apply-Workstation.ps1 -Module All` selection.

## Commands

Inspect the declaration without elevation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Plan
```

Inventory matching software without removing it:

```powershell
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Test
```

After reviewing both outputs, removal requires an additional explicit switch:

```powershell
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Ensure -ConfirmRemoval
```

The general orchestrator can run the same profile as one module:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Debloat
.\Apply-Workstation.ps1 -Mode Ensure -Module Debloat -ConfirmRemoval
```

Use `-Json` for machine-readable output. `Ensure` does not restart Windows. It records the exact pre-removal inventory under `state/debloat-snapshots/` before changing anything.

## Declared removals

The DSL is `config/debloat-profiles.psd1`.

| Type | Removed by `DeveloperMinimal` |
|---|---|
| Microsoft consumer apps | Weather, Get Help, Tips/Get Started, Messaging, 3D Viewer, Office Hub, Solitaire, Mixed Reality Portal, OneConnect, Print 3D, inbox Skype, Wallet, Feedback Hub, Maps, Phone Link, old Feedback and Contact Support |
| Xbox apps | Xbox TCUI, legacy Xbox app, game/gaming overlays, Xbox identity provider, and speech overlay |
| Promotional packages | old Bing News and Sway packages plus declared Pandora, Duolingo, Actipro, Eclipse Manager, Spotify, and King promotional packages |
| Remote support | Quick Assist |
| Capabilities | Steps Recorder, Internet Explorer compatibility, Math Recognizer, and Windows PowerShell ISE |
| Optional features | TFTP, Telnet client, XPS printing, and Work Folders client are disabled without removing their component-store payload |

For AppX/MSIX software, the resource removes matching registrations for all users and matching provisioning records for future users. Microsoft treats those as separate operations: removing provisioning prevents installation for new profiles, while `Remove-AppxPackage -AllUsers` removes existing registrations. See [Microsoft's AppX troubleshooting guidance](https://learn.microsoft.com/troubleshoot/windows-client/shell-experience/modern-inbox-store-apps-troubleshooting-guidance) and [Remove-AppxProvisionedPackage](https://learn.microsoft.com/powershell/module/dism/remove-appxprovisionedpackage).

## Protected software

The profile refuses a current target if it overlaps its protected AppX patterns or Windows marks it non-removable.

Protected declarations include:

- Desktop App Installer/WinGet, Microsoft Store, Store Purchase, and Windows Security;
- .NET Native, VCLibs, UI Xaml, and Windows App Runtime frameworks;
- image, audio, and video codecs;
- Windows Terminal, WSL, Debian, and Codex.

The reviewed legacy list also does **not** remove Sticky Notes, OneNote, Camera, Sound Recorder, Alarms, Mail/Calendar, Media Player, OpenSSH, Windows Hello Face, handwriting support, SMB Direct, Remote Desktop infrastructure, or WCF TCP Port Sharing. These are useful workstation features, security/authentication components, package dependencies, or plausible developer requirements.

## Services and scheduled tasks

The legacy script's blanket service and scheduled-task disabling is not part of debloat. It would disable or impair Edge updates, Windows Error Reporting, diagnostics, smart cards, synchronization, mobile hotspot/connection sharing, Compatibility Appraiser, and Features-on-Demand cleanup.

Those are operational policies, not software removals. If one needs to be disabled, it should get a separate desired-state resource with a specific compatibility rationale and independent Test/Ensure command.

## Current workstation inventory

The initial 2026-08-14 Test found eight noncompliant targets:

- installed and provisioned `Microsoft.OneConnect`, `Microsoft.YourPhone`, and `MicrosoftCorporationII.QuickAssist` packages;
- installed Steps Recorder, Internet Explorer compatibility, Math Recognizer, and PowerShell ISE capabilities;
- enabled Work Folders client.

TFTP, Telnet, and XPS printing were already disabled. The profile has not been applied to this workstation.

## Rollback limits

The JSON snapshot is evidence, not a package backup. AppX removal can be irreversible when the original package payload is no longer available; Microsoft explicitly warns to verify the user and exact package before removal.

- Store-delivered applications normally need to be reinstalled from Microsoft Store or an authoritative `winget` package.
- Capabilities can usually be restored with `Add-WindowsCapability -Online -Name <exact-name>`, potentially downloading content from Windows Update.
- Features can be restored with `Enable-WindowsOptionalFeature -Online -FeatureName <name> -NoRestart`.

Feature or capability restoration can require a restart. Review the saved snapshot before restoring because Windows versions can rename or retire components.
