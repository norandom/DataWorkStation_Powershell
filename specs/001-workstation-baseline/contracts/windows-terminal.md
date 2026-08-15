# Windows Terminal State Contract

## Human commands

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Set-WindowsTerminalState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Test -Module WindowsTerminal -Plan
```

## Managed subset

- The stable Windows Terminal package is a focused Core-stage dependency.
- `defaultProfile` identifies the installed PowerShell Core dynamic profile.
- Inbox Windows PowerShell remains present and visible.
- `profiles.defaults` supplies the shared Blue color scheme and visible scrollbar behavior.
- The declared Blue scheme is inserted or replaced by name.
- Profiles, actions, key bindings, themes, schemes with other names, and unrelated root settings are
  preserved.

## Modes

- `Test` parses state and reports drift without installing or writing.
- `Ensure` backs up a changed settings file and merges only the managed subset.
- `Reinitialize` uses the same merge boundary and does not replace unrelated settings.
- Human output is the default; `-Json` emits one structured result.
