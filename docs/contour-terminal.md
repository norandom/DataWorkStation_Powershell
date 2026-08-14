# Contour Terminal and BlueTerm

Contour 0.6.3.8249 is installed machine-wide from the [official GitHub release MSI](https://github.com/contour-terminal/contour/releases/tag/v0.6.3.8249). It is independent of the separately maintained Scoop installation.

## Human-readable commands

Inspect the prerequisite and Contour states before changing them:

```powershell
pwsh -NoProfile -File .\scripts\Set-SudoState.ps1 -Mode Test
winget configure test --file .\.config\powershell7.winget --accept-configuration-agreements --disable-interactivity
pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test
```

Repair only this direct state:

```powershell
pwsh -NoProfile -File .\scripts\Set-SudoState.ps1 -Mode Ensure
winget configure --file .\.config\powershell7.winget --accept-configuration-agreements --disable-interactivity
pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Ensure
pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Ensure
```

The equivalent focused orchestration resolves `Sudo`, `PowerShell7`, and `PowerShell7 → TerminalFonts` before `ContourTerminal`:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module ContourTerminal
```

`Ensure` performs an ordered migration. If `extras/contour` is installed, it uninstalls that Scoop package and verifies its removal before starting the MSI. It backs up and removes the obsolete per-user `Contour.lnk`, verifies the downloaded MSI's pinned SHA-256, then installs it through Windows sudo. The resource never restarts Windows.

The declared graphics-compatibility gate then opens one minimized Contour window with a bounded, self-exiting `ping.exe` session. A healthy renderer remains active for at least two seconds and exits with code 0. The resource captures only that process's standard output and error in temporary files, removes those files after the check, and force-closes the process only if it exceeds the 15-second timeout. `Test` reports the gate separately as `ContourGraphicsGate`; `Ensure` does not claim success unless it passes.

This is a functional gate for the installed graphics stack, not a vendor-specific version rule. If Contour reports an OpenGL, GLSL, or shader-initialization failure, the result includes the active display-driver version and INF and directs the operator to compare them with the installed vendor graphics components. Desired state does not download, roll back, repair, or restart a display driver automatically.

`Reinitialize` uninstalls and reinstalls the declared MSI while preserving the managed user configuration. MSI operations run synchronously, retain verbose logs under the ignored `state/contour-backups` directory, and accept exit code 3010 without initiating the requested restart.

## BlueTerm translation

The managed target is `%LocalAppData%\contour\contour.yml`, Contour's native Windows configuration path. The source palette is `%USERPROFILE%\Source\BlueTerm\Blue.json`; its existing Windows Terminal translation was used to cross-check RGB values.

The repository template contains a font-family placeholder. Copy `.terminal-fonts-sample` to the ignored `.terminal-fonts` file and put exactly one installed family name on that line. The tracked sample selects the automatically installed `Fira Code`; this workstation selects its separately licensed and installed `Berkeley Mono`. `Test` refuses a missing, empty, or multi-line preference, and `Ensure` renders it into `profiles.main.font.regular.family` without publishing the local choice.

The translation preserves:

- the deep-blue palette as the default and the near-black palette as the `blue-dark` profile;
- 17-pixel text, equivalent to the source's 17-pixel iTerm sizing and close to the 12-point Windows Terminal translation;
- a blinking bar cursor, unlimited history, and visual alert without bell sound;
- the locally declared terminal font and an initial working directory of `~` (`$HOME`);
- the `xterm-256color` environment intent and PowerShell 7 as the shell.

Contour requires the first color scheme to be named `default`, so the deep-blue BlueTerm palette has that internal name. The second scheme is `Blue Dark` and can be launched with `contour profile blue-dark`. Contour uses `magenta` where Windows Terminal calls the same ANSI slot `purple`.

Although the 0.6.3.8249 generated comments mention automatic light/dark mappings, its config inspector treats that map as missing. The managed config therefore uses explicit profiles so it remains compatible with this release parser.

## PowerShell integration and tabs

The managed PowerShell prompt emits Contour's `CSI > M` vertical-line mark before every prompt and wraps filesystem locations in an OSC 8 hyperlink. This behavior is enabled only when Contour identifies the session through `CONTOUR_PROFILE` or `TERMINAL_NAME`; redirected output and other terminals receive plain text. Use `terminal-link URI [TEXT]` to emit another explicit hyperlink.

Contour 0.6.3's built-in bindings are:

- `Ctrl+Alt+K` / `Ctrl+Alt+J`: jump to the previous or next marked prompt;
- `Ctrl+click`: follow the OSC 8 link under the pointer;
- `Ctrl+Shift+U`: enter hint mode for detected URLs and file paths;
- `Ctrl+Shift+T`: create a tab;
- `Shift+Left` / `Shift+Right`: switch to the tab on the left or right;
- `Alt+1` through `Alt+9`, and `Alt+0` for tab 10: switch directly to a tab.

The managed Contour YAML intentionally omits `input_mapping`, preserving the complete bindings supplied by this installed release instead of replacing them with a partial list.

The MSI installs the binary at `C:\Program Files\Contour Terminal Emulator 0.6\bin\contour.exe` and supplies the all-users Desktop shortcut `C:\Users\Public\Desktop\Contour Terminal Emulator.lnk`. Desired state validates both. If a different user configuration exists, Ensure copies it to `state/contour-backups` before deploying the managed artifact.

## Package and supply-chain behavior

The declaration pins:

- version `0.6.3.8249`;
- product code `{0E736497-2B72-4117-95E9-54EC6D000603}`;
- release asset `contour-0.6.3.8249-win64.msi`;
- SHA-256 `5c8b55c5580a3e263c971c6a9a3ced35014d94b210305a8cb5099177fb89e6a0`.

The upstream MSI is not Authenticode-signed. Desired state therefore relies on the exact HTTPS GitHub release URL plus the pinned SHA-256 and refuses installation on any mismatch. The MSI declares `ALLUSERS=1`, writes under Program Files and the common Desktop, and consequently requires administrator rights. Downloads and installation require network access; test and plan modes do not.
