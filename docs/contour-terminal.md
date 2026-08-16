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

Selecting text with the mouse immediately copies it to the Windows system clipboard through
`on_mouse_select: CopyToClipboard`; no copy chord is required. The setting uses the primary Windows
clipboard instead of Contour's platform-dependent selection clipboard. Selecting sensitive output
therefore replaces the current clipboard contents, which other processes in the interactive Windows
session may be able to read.

The managed map preserves Contour 0.6.3's bindings and adds common scrolling and mouse tab switching:

- `Ctrl+Alt+K` / `Ctrl+Alt+J`: jump to the previous or next marked prompt;
- `Ctrl+click`: follow the OSC 8 link under the pointer;
- `Ctrl+Shift+U`: enter hint mode for detected URLs and file paths;
- `Ctrl+Shift+T`: create a tab;
- `Alt+wheel up` / `Alt+wheel down`: switch to the tab on the left or right;
- `Shift+Left` / `Shift+Right`: switch to the tab on the left or right;
- `Alt+1` through `Alt+9`, and `Alt+0` for tab 10: switch directly to a tab.
- `Ctrl+Shift+Page Up` / `Ctrl+Shift+Page Down`: scroll terminal history by a page, matching Windows Terminal.

The bottom status line shows the active tabs but is not a clickable tab bar in this Contour release. Use `Alt+wheel` for mouse-driven switching. Plain wheel scrolling remains terminal scrollback, `Shift+wheel` moves by a page, and `Ctrl+wheel` changes font size.

The deep-blue palette uses a warm coral ANSI red (`#FF8F80`) and a pale-coral bright red (`#FFD0C8`). Red and blue are perceptual opposites, but the original dark red had only about 2.0:1 contrast against `#00347F`. The replacement retains error semantics while reaching about 5.3:1 for normal red and 8.4:1 for bright red. The same values are carried into the BlueTerm Windows Terminal conversion.

For touch use, the profile enables smooth/momentum scrolling and keeps the right-side scrollbar visible even in alternate-screen tools. Unmodified wheel events are captured for terminal history only on the primary screen, allowing Codex and other mouse-aware TUIs to receive them in the alternate screen. See [Terminal keyboard and scrolling](terminal-keybindings.md).

Contour's indicator status line supports configurable `left`, `middle`, and `right` templates. Built-in variables cover the clock, command output, history-line count, hyperlink under the pointer, input/protected/search modes, search prompt, tabs, title, and VT type. The default indicator already shows mode/tab state on the left, the title in the middle, and history count plus clock on the right.

This can approximate a Byobu layout, but Contour has no Byobu-style catalog of CPU, memory, network,
battery, or host modules. `{Command:Program=...}` can insert output from an external program. This
profile does not run uncached PowerShell commands during status-line redraw because each redraw would
start another process. The separate host-writable VT status line is controlled by the application;
it is not a declarative item system.

Contour replaces its entire built-in map when `input_mapping` is present. The managed YAML therefore declares the complete 0.6.3.8249 map rather than a partial override. See [Terminal keyboard and scrolling](terminal-keybindings.md) for the full Contour, Windows Terminal, compact-keyboard, and PSReadLine reference.

The MSI installs the binary at `C:\Program Files\Contour Terminal Emulator 0.6\bin\contour.exe` and supplies the all-users Desktop shortcut `C:\Users\Public\Desktop\Contour Terminal Emulator.lnk`. Desired state validates both. If a different user configuration exists, Ensure copies it to `state/contour-backups` before deploying the managed artifact.

## Package and supply-chain behavior

The declaration pins:

- version `0.6.3.8249`;
- product code `{0E736497-2B72-4117-95E9-54EC6D000603}`;
- release asset `contour-0.6.3.8249-win64.msi`;
- SHA-256 `5c8b55c5580a3e263c971c6a9a3ced35014d94b210305a8cb5099177fb89e6a0`.

The upstream MSI is not Authenticode-signed. Desired state therefore relies on the exact HTTPS GitHub release URL plus the pinned SHA-256 and refuses installation on any mismatch. The MSI declares `ALLUSERS=1`, writes under Program Files and the common Desktop, and consequently requires administrator rights. Downloads and installation require network access; test and plan modes do not.
