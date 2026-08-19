# Desired state

`Apply-Workstation.ps1` composes WinGet Configuration with focused idempotent PowerShell resources, including separately dependency-ordered Scoop and Contour Terminal paths.

## Choose scope and mode

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

## Update installed systems

`update` is a separate plan-first servicing workflow. It does not replace the desired-state module
catalog: external updaters run in their own declared order, then the last stage returns to
`Apply-Workstation.ps1 -Mode Ensure` and `-Mode Test` so the current checkout remains authoritative.

```powershell
update
update -Check
update -Target Homebrew,Containers
update -Run
```

`update` prints a static plan. `update -Check` queries supported pinned upstream releases without
changing declarations or software. Only `-Run` mutates state. The complete execution covers accepted Windows software updates,
known-version unpinned WinGet applications, Scoop and its installed apps, the WSL runtime, packages
in the two `config.json` Debian distributions, declared Homebrew instances, developer Docker, rootless Podman,
and current-release reconciliation. See [Managed workstation update](workstation-update.md) for
privilege, restart, package-pin, and trust-boundary details.

The catalog also declares a runtime boundary for every module. `Inbox` is limited to Windows PowerShell 5.1 and native Windows commands, so a fresh host can reach the `PowerShell7` prerequisite without first resolving it. `Core` and `Extended` both have an explicit `PowerShell7` stage gate. The orchestrator resolves `pwsh.exe` lazily only when a modern-runtime module is dispatched, checks the standard installation path in case the current process has a stale `PATH`, and blocks every later selected stage if an earlier stage fails.

## Native development state

`NativeDevelopment` is an Extended-stage aggregate over `MsvcBuildTools`, `CMake`,
`RustToolchain`, `JavaToolchain`, and `PowerShellProfile`. The focused modules remain runnable one
at a time. Test is observational; Ensure is explicit, and only standalone Build Tools crosses the
privileged, multi-gigabyte installation boundary. No installer restarts Windows automatically.

The managed profile exposes `msvc-activate` in both PowerShell runtimes and leaves the MSVC
environment inactive at shell startup. Invoking the command imports the current x64 MSVC environment
into that process, selects `CC=CXX=cl.exe`, and puts Microsoft `link.exe` ahead of conflicting tools.
The compiler selectors are not persisted. Independent CMake, Rust, and Java state retains its stable
user variables and paths. Versioned MSVC, SDK, and JDK paths are resolved dynamically. MinGW,
MSYS/MSYS2, Cygwin, and Git Bash are excluded.

## Automatically maintained

The declared package set, official Scoop buckets, Windows Terminal, Contour Terminal and its BlueTerm theme, Windows optional features, developer hardening profile, current-user hover-focus behavior, profiles, inline Windows sudo, firewall rules, Defender exclusions, SmartScreen baseline, WSL/pagefile limits, event-log retention, developer CLIs, PoolMon tags, and profiling tools are automatically maintained unless their skip switch is supplied.

The base WinGet package DSL also installs IrfanView with its matching plug-in collection and qView.
Completed SVG flame graphs open in the smaller native qView application after headless profiling
work ends; IrfanView remains available for ordinary image viewing.

The focused `Caffeine` module installs the real Zhorn Software tray utility and maintains an enabled per-user startup entry. It starts active at sign-in with no `-startoff` flag, so idle sleep is inhibited; use its tray icon to toggle or exit it. The local Contour configuration keeps touch scrollbars visible and uses accessible coral error colors; runtime terminal windows must be reopened to load those changes.

`.config/git.winget` provides the focused Git prerequisite for `Git → Scoop`; `.config/powershell7.winget` provides the focused PowerShell 7 prerequisite for packages, profiles, and Contour. `config/scoop.psd1` declares the official per-user Scoop source and Main/Extras bucket repositories. Contour is independent of that package path. `config/terminal-fonts.psd1` pins the official Fira Code 6.2 archive and every installed TTF hash. `config/contour-terminal.psd1` pins the official release MSI, SHA-256, ProductCode, install path, managed user-config paths, local font preference, and a bounded graphics-compatibility gate; `config/contour.yml` is the translated BlueTerm template. Ignored `config.json` supplies the local font family, WSL selectors, storage paths, Defender exclusions, and trace retention. A focused Contour run includes `Sudo`, `PowerShell7`, and `TerminalFonts` before `ContourTerminal`, installs Fira Code per-user without UAC, removes a legacy Scoop Contour package first, installs the machine-wide MSI without restarting Windows, renders the local font into the config, and verifies that its OpenGL-backed window can render and exit cleanly. Inspect or repair it directly with `Set-ContourTerminalState.ps1`, or use `.\Apply-Workstation.ps1 -Mode Ensure -Module ContourTerminal`. See [Contour Terminal and BlueTerm](contour-terminal.md).

`.config/windows-terminal.winget` declares the stable Windows Terminal package. `config/windows-terminal.psd1` declares only the managed settings subset: PowerShell Core as the default profile, both PowerShell profiles visible, generated `NixOS` and `NixOS-AI` profiles labelled `NixOS DevOps` and `NixOS AI`, shared Blue appearance, and a visible scrollbar. `Set-WindowsTerminalState.ps1 -Mode Test` is observational and never invokes WinGet; `Ensure` backs up an existing settings file before a semantic merge and preserves unrelated profiles, actions, themes, schemes, and root properties. Reopen Terminal after changing its settings. The PowerShell profile resource continues to deploy the same component set to both `Documents\WindowsPowerShell` and `Documents\PowerShell`. Profile `Ensure` also resolves the declared native executables once and writes a generated availability cache beside each component set. Normal shell startup validates cached executable paths and performs live command discovery only for a missing or stale entry, so native commands retain precedence without rescanning the complete catalog in every session.

`.config/go.winget` declares the official MSI-backed `GoLang.Go` package. The focused `Go` resource
keeps `%USERPROFILE%\go` as `GOPATH`, adds its `bin` directory to the user path, accepts an empty
`GOBIN`, and requires effective `GOTOOLCHAIN=auto`. It leaves user `GOROOT` unset so the MSI owns the
installation root. Go 1.21 and newer can select or download a compatible released toolchain from the
`go` and `toolchain` lines in `go.mod` or `go.work`; no third-party version manager is installed.
Inspect with `pwsh -NoProfile -File .\scripts\Set-GoState.ps1 -Mode Test`.

`config/malware-hashes.psd1` pins the v2.5.0 Windows amd64 asset from the project's GitHub release and its GitHub-published SHA-256. `MalwareHashes` installs it per-user into a versioned narrow directory, exposes a verified copy through the managed command bin, and smoke-tests the embedded release version. Target Sandbox plans run the bounded host invocation and map only the versioned directory read-only for the independent guest invocation. The module never launches Sandbox; launch confirmation remains part of the analysis command.

`.config/native-text-tools.winget` provides the focused native Win32 package used for PowerShell `awk` and `sed`. The resource exposes only `awk.exe` and `sed.exe` in the already managed user tool directory and verifies both with functional pipeline tests. It does not install or use Git Bash, MinGit, Cygwin, MSYS, or MSYS2. BusyBox is not Bash; its native binary contains an optional `ash`-style shell applet, but desired state does not expose or configure that shell. See [Native awk and sed for PowerShell](native-text-tools.md).

`config/windows-features.psd1` declares Hyper-V and Windows Sandbox, with Sandbox explicitly depending on Hyper-V. The resource validates missing dependencies and cycles, then applies features in topological order. Inspect that order without elevation by running `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan`. `Apply-Workstation.ps1` bootstraps the inbox Windows sudo configuration before any resource invokes `sudo`. The feature resource uses inbox Windows PowerShell because the DISM module is not reliably hosted by PowerShell 7. Inspect only the elevated feature state with `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test`, or repair it with the same command and `-Mode Ensure`. An explicit `Reinitialize` first records the observed feature state under `state/windows-feature-snapshots/`. Enabling a feature never restarts Windows automatically; restart explicitly if the command reports that one is required. Use `-SkipWindowsFeatures` on `Apply-Workstation.ps1` to omit this resource.

`config/hardening-profiles.psd1` declares the `DeveloperBaseline` security controls. Inspect its plan without elevation with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan`. Compare or repair the machine with the same script through `sudo` and `-Mode Test` or `-Mode Ensure`. An explicit `Reinitialize` first records the observed control state under `state/hardening-snapshots/`. The resource applies registry, SMB runtime, optional-feature, and per-adapter NetBIOS state, leaves UAC policy outside its scope, and never restarts Windows. Use `-SkipHardening` to omit it. The exact controls, rejected legacy settings, compatibility costs, and residual exposure are documented in [Windows hardening profile and attack surface](hardening.md).

Exploit Protection remains a separate hardening DSL and module. `config/exploit-protection.psd1`
pins the complete captured pre-change policy and declares `CapturedDefault` and `Recommended`
profiles. Inspect it with `powershell -NoProfile -ExecutionPolicy Bypass -File
.\scripts\Set-ExploitProtectionState.ps1 -Mode Plan`; use the focused `ExploitProtection` module to
test or apply the recommendation. The direct `-Profile CapturedDefault` command restores the system
controls changed by the recommendation. See [Windows Exploit Protection profiles](exploit-protection.md).

`config/focus-follows-mouse.psd1` enables current-user active-window tracking with a 500 ms delay while explicitly disabling raise-on-focus. The delay matches the default in [X-Mouse Controls](https://github.com/joelpurra/xmouse-controls/blob/develop/X-Mouse%20Controls/WindowTrackingValues.cs) and avoids the unsafe instant activation that dismisses modal dialogs and taskbar flyouts while the pointer crosses another surface. X-Mouse Controls is not installed: its [source applies the same three `SystemParametersInfo` settings](https://github.com/joelpurra/xmouse-controls/blob/develop/X-Mouse%20Controls/SystemParametersInfo/Helpers.cs), so the focused PowerShell resource provides the direct equivalent without another binary or background process. Windows directs keyboard focus to a window only after the pointer remains over it for the declared delay, without bringing it to the top or changing its Z-order. Inspect it with `pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test`, repair it with `-Mode Ensure`, or use `focus-mouse-on` and `focus-mouse-off` for explicit persistent toggles. A normal default Ensure restores the declared enabled state. This resource does not require elevation. Use `-SkipFocusFollowsMouse` on `Apply-Workstation.ps1` to omit it.

Defender exclusion paths are local state under `defender.exclusions` in ignored `config.json`;
`config.sample.json` documents the portable format. Desired state refuses to guess paths when the
local file is absent.

The optional `Autopsy` forensic module is separate from the default workstation run. It depends on
the matching `SleuthKitCli` module and keeps a dedicated case/output directory plus Autopsy process
in Defender's exclusion catalog. It does not stop or remove Defender. Global protection changes use
the explicit `autopsy-defender-off` and `autopsy-defender-on` commands. See [Autopsy Windows
forensic workstation](autopsy.md).

SkillOpt 0.2.0 is installed automatically through an isolated `uv tool` environment. Desired state also enforces validation gating, mock backend defaults, no auto-adoption, no `CLAUDE.md` evolution, and no evidence log. Use `-SkipSkillOpt` to omit this resource.

The default `NixOsWsl` module installs the pinned NixOS-WSL image and activates the repository's locked system generation for Helm, kubectl, the Pulumi CLI, Git, jq, and native OpenSSH. Its read-only self-check compares the active system with the evaluated flake, verifies the deployed source manifest, checks command provenance and the restricted host-integration boundary, and content-verifies the complete local Nix store. DevOps credentials stay in its private VHD. `SharedSshConfig` links the canonical Windows `%USERPROFILE%\.ssh\config` only into ordinary trusted Debian; DevOps NixOS, AI NixOS, and Debian-MW are excluded. See [Reproducible NixOS WSL tools](nixos-wsl.md), [NixOS integrity and alteration detection](nixos-integrity.md), and [AI tools, editor, and WSL isolation](ai-tools-isolation.md).

`DeveloperEditor` maintains stable VS Code, the pinned `jx22/berg` source theme, Cline, Jupyter, Python, and GitHub Copilot extensions, and the existing local-or-Fira font selection. `AiTools` and `AiNixOsWsl` are separate opt-in modules for the requested native agents and the restricted OpenCode CLI environment. Test and Plan are observational; Ensure executes reviewed network installers and may create or restart only the selected AI distribution. See [AI tools, editor, and WSL isolation](ai-tools-isolation.md).

The selectable `DeveloperTools` bundle pulls in `Go`, `LinuxHomebrew`, `LinuxAutomation`, and `DeveloperDocker` after the Debian and package prerequisites. `LinuxAutomation` installs Homebrew `uv` and the pinned pyinfra version. `DeveloperDocker` adopts the existing official Docker CE packages, root-owned service/socket, and selected user's group membership through `linux/developer_docker.py`; this rootful daemon is retained because Dagger requires privileged engine capabilities. The developer bundle then runs the repository's Debian-native deploy:

```bash
cd /mnt/c/path/to/DataWorkStation_PowerShell
PATH="/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin:$PATH" \
  pyinfra @local ./linux/developer_tools.py -y
```

Use `--dry` instead of `-y` to inspect proposed changes. The external equivalent is `./Apply-Workstation.ps1 -Mode Ensure -Module DeveloperTools`. Both paths use the same deploy file to install Dagger with the official `dagger/tap/dagger` formula. The outer test verifies the CLI version and a minimal Dagger Engine call against the developer Docker daemon inside Debian WSL. Run either prerequisite alone with `-Module LinuxHomebrew`, `-Module LinuxAutomation`, or `-Module DeveloperDocker`, or inspect the complete order with `-Mode Test -Module DeveloperTools -Plan`.

The separate default `RootlessPodman` module creates a clean named `Debian-MW` WSL 2 distribution, bootstraps pinned pyinfra locally, and applies `linux/rootless_podman.py`. It uses Debian's Podman package as a local, rootless, daemonless engine with user-scoped overlay storage and seccomp. The Podman API socket and services remain disabled. `config.json` keeps the developer and malware distro/user selectors separate. Test with `./Apply-Workstation.ps1 -Mode Test -Module RootlessPodman`; repair with `-Mode Ensure`. This module never exports, imports, or clones the developer distro.

Migration provisions and validates Podman before stopping and removing the old Debian-MW Docker service, packages, and repository. Existing `~/.local/share/docker` and `~/.docker` data is retained and reported. Inspect it with `./scripts/Remove-LegacyDockerMwState.ps1 -Mode Test`; deletion is a separate non-default `LegacyDockerCleanup` module and requires both Ensure and `-ConfirmDestructive`.

`MalwareContainerImage` is a separate opt-in dependent module. `Test` only inspects the local image
and its embedded inventory fingerprint. `Ensure` performs the explicit networked build from the
hash-pinned container file in `Debian-MW`; no analysis command builds, downloads, or repairs the image.

`SpecDrivenDevelopment` is a separate default developer module with only the Windows `Packages`/`uv` dependency. It downloads the `spec-kit-ears-tdd` `v0.1.0` wheel release, verifies its pinned SHA-256, and installs it through `uv tool`; the wheel depends on the published `specify-cli==0.16.3` release. Project adoption remains an explicit `ears-sdd init --project . --integration codex` write followed by review. See [Spec-driven development](spec-driven-development.md).

`PowerShellTesting` is a focused default module that depends on PowerShell 7 and maintains exact Pester 6.1.0 under the shared per-user `Documents\WindowsPowerShell\Modules` tree. `Test` only compares the declared manifest and what PowerShell 7 and Windows PowerShell 5.1 can resolve. `Ensure` is an explicit networked, non-elevated PSResourceGet installation. Running `test-powershell` never installs or upgrades the framework. The modern lane enables Pester's bounded file-level parallel mode; the compatibility lane and files marked `#pester:no-parallel` execute sequentially.

The opt-in `QuantResearchEnvironment` module depends on `Packages` for uv and on the managed
profile for human commands. It validates the signed per-user Positron quantitative IDE, one
hash-pinned Quarto/Pandoc installation, private TinyTeX, one installable OpenBB base, plus independently locked
overlay projects. Reconciliation is limited to declared package state and generated `.venv` or
OpenBB reference assets. For the base it also maintains an existing PyXLL Excel payload,
current-user add-in registration, and machine-local config after a local ignored license and all
preconditions pass. First install requires `-ConfirmPyXllInstall`; ordinary runs never accept
vendor terms. Notebooks, source, data, exports, credentials, and undeclared content are
not desired-state resources. Positron's first official-installer download separately requires
`-AcceptLicense`; ordinary testing is read-only and the state accepts newer signed user updates.
Quarto uses its bundled Pandoc, keeps TinyTeX off the global user PATH, and binds
`QUARTO_PYTHON` to the quant-base `.venv` so executable papers use the locked quantitative stack.
Source relocation is exposed only as an observational readiness plan;
the module cannot copy, rename, delete, or create a junction. See [Quantitative research
environment](quant-research-environment.md).

Only the stable base package is installed. SkillOpt's source checkout, global plugin, WebUI, benchmark environments, local-model stacks, and optional provider SDK extras are excluded.

## Explicit by design

Credentials, rclone mounts, code scans, packet/ETW/TTD recordings, debugger attachment, crash reproduction, process termination, AMD uProf EULA acceptance, and security protection toggles remain explicit actions.

Software removal is also explicit. `config/debloat-profiles.psd1` declares the opt-in `DeveloperMinimal` profile, which is excluded from `-Module All` and runs only when `-Module Debloat` is named. Use Test first. Ensure refuses to proceed without `-ConfirmRemoval` and writes a pre-removal inventory. See [Opt-in Windows debloat profile](debloat.md) for protected packages and rollback limits.

SkillOpt transcript harvesting, task approval, provider-backed optimization, and proposal adoption
also remain explicit. The managed wrapper provides no scheduling or automatic adoption.

MkDocs is also not a global workstation dependency. Its exact version is locked in `uv.lock` and materialized only for this repository.
