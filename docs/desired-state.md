# Desired state

`Apply-Workstation.ps1` composes WinGet Configuration with focused idempotent PowerShell resources, including separately dependency-ordered Scoop and Contour Terminal paths.

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

`config/workstation-modules.psd1` declares the module catalog, default selection, supported modes, and dependencies. Dependencies are included automatically in topological order. `-Module All` preserves the complete default run but excludes the destructive Debloat module. See [Workstation modules and dependency order](workstation-modules.md) and [Sample outputs](sample-outputs.md).

## Automatically maintained

The declared package set, official Scoop buckets, Contour Terminal and its BlueTerm theme, Windows optional features, developer hardening profile, current-user hover-focus behavior, profiles, inline Windows sudo, firewall rules, Defender exclusions, SmartScreen baseline, WSL/pagefile limits, event-log retention, developer CLIs, PoolMon tags, and profiling tools are automatically maintained unless their skip switch is supplied.

The focused `Caffeine` module installs the real Zhorn Software tray utility and maintains an enabled per-user startup entry. It starts active at sign-in with no `-startoff` flag, so idle sleep is inhibited; use its tray icon to toggle or exit it. The local Contour configuration keeps touch scrollbars visible and uses accessible coral error colors; runtime terminal windows must be reopened to load those changes.

`.config/git.winget` provides the focused Git prerequisite for `Git → Scoop`; `.config/powershell7.winget` provides the focused PowerShell 7 prerequisite for packages, profiles, and Contour. `config/scoop.psd1` declares the official per-user Scoop source and Main/Extras bucket repositories. Contour is independent of that package path. `config/terminal-fonts.psd1` pins the official Fira Code 6.2 archive and every installed TTF hash. `config/contour-terminal.psd1` pins the official release MSI, SHA-256, ProductCode, install path, managed user-config paths, local font preference, and a bounded graphics-compatibility gate; `config/contour.yml` is the translated BlueTerm template. The ignored `.terminal-fonts` supplies one local font-family name, with `.terminal-fonts-sample` as the portable Fira Code example. A focused Contour run includes `Sudo`, `PowerShell7`, and `TerminalFonts` before `ContourTerminal`, installs Fira Code per-user without UAC, removes a legacy Scoop Contour package first, installs the machine-wide MSI without restarting Windows, renders the local font into the config, and verifies that its OpenGL-backed window can render and exit cleanly. Inspect or repair it directly with `Set-ContourTerminalState.ps1`, or use `.\Apply-Workstation.ps1 -Mode Ensure -Module ContourTerminal`. See [Contour Terminal and BlueTerm](contour-terminal.md).

`.config/go.winget` declares the official MSI-backed `GoLang.Go` package. The focused `Go` resource keeps `%USERPROFILE%\go` as `GOPATH`, keeps its `bin` directory on the user path, accepts an empty `GOBIN`, and requires effective `GOTOOLCHAIN=auto`. It deliberately leaves user `GOROOT` unset so the MSI owns the installation root. Go 1.21 and newer can select or download a compatible released toolchain from the `go` and `toolchain` lines in `go.mod`/`go.work`; no separate third-party version manager is installed. Inspect with `pwsh -NoProfile -File .\scripts\Set-GoState.ps1 -Mode Test`.

`config/malware-hashes.psd1` pins the v2.4.0 Windows amd64 asset from the project's GitHub release and its GitHub-published SHA-256. `MalwareHashes` installs it per-user into a versioned narrow directory, exposes a verified copy through the managed command bin, and smoke-tests the embedded release version. Target Sandbox plans run the bounded host invocation and map only the versioned directory read-only for the independent guest invocation. The module never launches Sandbox; launch confirmation remains part of the analysis command.

`.config/native-text-tools.winget` provides the focused native Win32 package used for PowerShell `awk` and `sed`. The resource exposes only `awk.exe` and `sed.exe` in the already managed user tool directory and verifies both with functional pipeline tests. It does not install or use Git Bash, MinGit, Cygwin, MSYS, or MSYS2. BusyBox is not Bash; its native binary contains an optional `ash`-style shell applet, but desired state does not expose or configure that shell. See [Native awk and sed for PowerShell](native-text-tools.md).

`config/windows-features.psd1` declares Hyper-V and Windows Sandbox, with Sandbox explicitly depending on Hyper-V. The resource validates missing dependencies and cycles, then applies features in topological order. Inspect that order without elevation by running `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan`. `Apply-Workstation.ps1` bootstraps the inbox Windows sudo configuration before any resource invokes `sudo`. The feature resource uses inbox Windows PowerShell because the DISM module is not reliably hosted by PowerShell 7. Inspect only the elevated feature state with `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test`, or repair it with the same command and `-Mode Ensure`. Enabling a feature never restarts Windows automatically; restart explicitly if the command reports that one is required. Use `-SkipWindowsFeatures` on `Apply-Workstation.ps1` to omit this resource.

`config/hardening-profiles.psd1` declares the `DeveloperBaseline` security controls. Inspect its plan without elevation with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan`. Compare or repair the machine with the same script through `sudo` and `-Mode Test` or `-Mode Ensure`. The resource applies registry, SMB runtime, optional-feature, and per-adapter NetBIOS state; it never restarts Windows. Use `-SkipHardening` to omit it. The exact controls, rejected legacy settings, compatibility costs, and residual exposure are documented in [Windows hardening profile and attack surface](hardening.md).

`config/focus-follows-mouse.psd1` enables current-user active-window tracking with a 0 ms delay while explicitly disabling raise-on-focus. Windows therefore directs keyboard focus to the hovered window without bringing it to the top or changing its Z-order. In Windows API terminology that window becomes active/foreground because it owns keyboard input, while the separately managed Z-order remains unchanged. The resource uses Microsoft's documented [active-window tracking parameters](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-systemparametersinfow). Inspect it with `pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test` or repair it by using `-Mode Ensure`. This resource does not require elevation. Use `-SkipFocusFollowsMouse` on `Apply-Workstation.ps1` to omit it.

Defender exclusion paths are local state in ignored `.excluded`; `.excluded.sample` documents the portable format. Desired state refuses to guess paths when the local file is absent.

SkillOpt 0.2.0 is installed automatically through an isolated `uv tool` environment. Desired state also enforces validation gating, mock backend defaults, no auto-adoption, no `CLAUDE.md` evolution, and no evidence log. Use `-SkipSkillOpt` to omit this resource.

The selectable `DeveloperTools` bundle pulls in `Go`, `LinuxHomebrew`, `LinuxAutomation`, and `DeveloperDocker` after the Debian and package prerequisites. `LinuxAutomation` installs Homebrew `uv` and the pinned pyinfra version. `DeveloperDocker` adopts the existing official Docker CE packages, root-owned service/socket, and selected user's group membership through `linux/developer_docker.py`; this rootful daemon is retained because Dagger requires privileged engine capabilities. The developer bundle then runs the repository's Debian-native deploy:

```bash
cd /mnt/c/path/to/DataWorkStation_PowerShell
PATH="/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH" \
  pyinfra @local ./linux/developer_tools.py -y
```

Use `--dry` instead of `-y` to inspect proposed changes. The external equivalent is `./Apply-Workstation.ps1 -Mode Ensure -Module DeveloperTools`. Both paths use the same deploy file to install Dagger with the official `dagger/tap/dagger` formula. The outer test verifies the CLI version and a minimal Dagger Engine call against the developer Docker daemon inside Debian WSL. Run either prerequisite alone with `-Module LinuxHomebrew`, `-Module LinuxAutomation`, or `-Module DeveloperDocker`, or inspect the complete order with `-Mode Test -Module DeveloperTools -Plan`.

The separate default `RootlessDocker` module creates a clean named `Debian-MW` WSL 2 distribution, bootstraps pinned pyinfra locally, and applies `linux/rootless_docker.py`. Package installation is prevented from starting a root-owned daemon; the rootless user service, linger state, Docker context, and official package repository are then maintained. `.wsl-env` keeps the developer and malware distro/user selectors separate. Test with `./Apply-Workstation.ps1 -Mode Test -Module RootlessDocker`; repair with `-Mode Ensure`. This module never exports, imports, or clones the developer distro.

`MalwareContainerImage` is a separate opt-in dependent module. `Test` only inspects the local image
and its embedded inventory fingerprint. `Ensure` performs the explicit networked build from the
hash-pinned Dockerfile in `Debian-MW`; no analysis command builds, downloads, or repairs the image.

`SpecDrivenDevelopment` is a separate default developer module with only the Windows `Packages`/`uv` dependency. It downloads the `spec-kit-ears-tdd` `v0.1.0` wheel release, verifies its pinned SHA-256, and installs it through `uv tool`; the wheel depends on the published `specify-cli==0.16.3` release. Project adoption remains an explicit `ears-sdd init --project . --integration codex` write followed by review. See [Spec-driven development](spec-driven-development.md).

Only the stable base package is installed. SkillOpt's source checkout, global plugin, WebUI, benchmark environments, local-model stacks, and optional provider SDK extras are excluded.

## Explicit by design

Credentials, rclone mounts, code scans, packet/ETW/TTD recordings, debugger attachment, crash reproduction, process termination, AMD uProf EULA acceptance, and security protection toggles remain explicit actions.

Software removal is also explicit. `config/debloat-profiles.psd1` declares the opt-in `DeveloperMinimal` profile, which is excluded from `-Module All` and runs only when `-Module Debloat` is named. Use Test first. Ensure refuses to proceed without `-ConfirmRemoval` and writes a pre-removal inventory. See [Opt-in Windows debloat profile](debloat.md) for protected packages and rollback limits.

SkillOpt transcript harvesting, task approval, provider-backed optimization, scheduling, and proposal adoption also remain explicit. Scheduling and automatic adoption are intentionally absent from the managed wrapper.

MkDocs is also not a global workstation dependency. Its exact version is locked in `uv.lock` and materialized only for this repository.
