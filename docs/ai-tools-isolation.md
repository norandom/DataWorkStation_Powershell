# AI tools, editor, and WSL isolation

The AI tooling is split into four focused modules. `DeveloperEditor` and `OpenCodeExtensions` are
part of the normal developer workstation. `AiTools` and `AiNixOsWsl` are opt-in because they execute
vendor installers or create a separate WSL distribution.

## Inspect before changing anything

```powershell
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test -Product OpenCode
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test -Json
pwsh -NoProfile -File .\scripts\Set-OpenCodeExtensionsState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-DeveloperEditorState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-AiNixOsWslState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1 -Json
```

These commands are observational. The trust command does not start stopped distributions; a
stopped distribution is reported as not inspected and returns drift instead.

## OpenCode themes and OpenUltraCode

`OpenCodeExtensions` installs the three Cream Blue themes from pinned commit
`7cef8d00dccd2c459df6bc1fe867a80bef668790` and selects `cream-blue-cobalt` in the global
`tui.json`. It installs the hash-verified OpenUltraCode 0.1.3 release under the user's local data
directory, publishes its commands, agents, and skill into the global OpenCode configuration, and
registers the release-local plugin while preserving unrelated configuration and assets.

Inspect first, then explicitly reconcile as the current user:

```powershell
pwsh -NoProfile -File .\scripts\Set-OpenCodeExtensionsState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-OpenCodeExtensionsState.ps1 -Mode Ensure
```

Ensure downloads only the declared commit/release, verifies SHA-256 and the complete release
inventory, and backs up managed files before replacing drift. Restart an already-running OpenCode
TUI after reconciliation so it loads the selected theme and plugin.

## Selected tools and sources

| Product | Location | Declared channel |
|---|---|---|
| OpenCode Desktop | Windows | signed official release payload with pinned SHA-256, extracted to the standard per-user Programs path |
| OpenCode CLI | Windows | official global npm package `opencode-ai` |
| OpenCode CLI (sandboxed) | `NixOS-AI` | pinned Nix derivation in the complete verified Nix store |
| Claude Code | Windows | `irm https://claude.ai/install.ps1 \| iex` |
| Antigravity CLI (`agy`) | Windows | `irm https://antigravity.google/cli/install.ps1 \| iex` |
| Cline CLI | Windows | `npm i -g cline` |
| GitHub Copilot CLI | Windows | `npm i -g @github/copilot` |
| nono | `NixOS-AI` | `brew install nono`, pinned after review |

Homebrew bootstrap and package maintenance run as the non-login `ai-maint` identity through the
locked `homebrew-fhs` compatibility wrapper. The daily `ai` user cannot write that prefix. The
installed `nono` bottle runs directly through the narrow NixOS `nix-ld` bridge rather than inside
the maintenance FHS environment.

Claude Code is not declared through WinGet. If the state command observes the former
`Anthropic.ClaudeCode` WinGet path, an explicit `AiTools` Ensure removes it before running the
official installer. A failed installer stops the module; no alternate package source is used.

Install only the two native Windows OpenCode products as the current user:

```powershell
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Ensure -Product OpenCode
```

The focused Ensure installs the replacements first, then removes any former Scoop OpenCode Desktop
and CLI packages. Both silent and interactive execution of the Desktop installer faulted on this
workstation, so the command verifies its pinned hash and Authenticode signature, extracts the
embedded application payload with inbox Windows `tar.exe`, and creates the normal Start-menu
shortcut without executing the broken installer wrapper.

Omitting `-Product` selects every enabled Windows AI product. That broader Ensure executes
network-delivered vendor code as the current Windows user:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module AiTools,AiNixOsWsl
```

Review the Plan output first. Automated repository tests never run this command.

## Developer editor

`DeveloperEditor` maintains stable `Microsoft.VisualStudioCode`, activates the pinned Berg theme,
installs these exact extensions, and owns only the theme and two font keys in the user settings:

- `saoudrizwan.claude-dev` (Cline)
- `ms-toolsai.jupyter`
- `ms-python.python`
- `GitHub.copilot-chat` (the current stable VS Code bundled GitHub Copilot extension)

The resource installs exact extension `teehausamberg.berg@0.0.4`, whose manifest identifies
`https://github.com/jx22/berg`, and requires VS Code to report it. It also verifies the contributed
theme JSON against pinned commit `32e03bf59ae9408edc2d0c382a7003a57f1d2bc0` and SHA-256
`290433bf27cd893a3f13bd3c5e01238f0885d1dbbad7934bfc20f9f63b3873e1`. A downloaded file that VS
Code has not discovered is drift, even when its digest matches. The managed
`workbench.colorTheme` value is `Berg Theme`.

The `fonts.terminalFamily` value in ignored `config.json` remains the local font choice. Berkeley Mono is selected when
Windows registers the family or when a font in the per-user Windows font directory exposes that
exact embedded family name. Public configuration without that valid local family falls back to
the installed `Fira Code` family. Existing settings are backed up and unrelated settings,
extensions, profiles, and workspace configuration are preserved.

## WSL trust matrix

| Distribution role | Interop | Windows PATH | Windows automount | Daily sudo | Intended content |
|---|---:|---:|---:|---:|---|
| ordinary Debian (`TrustedUtility`) | on | on | on | allowed | trusted administration, Homebrew, Docker/Dagger |
| DevOps NixOS | off | off | off | off | private SSH/cloud/Kubernetes credentials and IaC tools |
| Debian-MW | off | off | off | off | hostile static inputs and rootless parser containers |
| AI NixOS | off | off | off | off | private agent projects and OpenCode runtime state |

Windows Terminal labels the two restricted NixOS profiles `NixOS DevOps` and `NixOS AI`; their
underlying WSL distribution identities remain `NixOS` and `NixOS-AI`.

Ordinary Debian is trusted. Do not run autonomous AI agents or hostile parsers there, and do not
store DevOps private keys there. The three restricted distributions receive tracked configuration
through `wsl.exe` standard input rather than `/mnt/c` or `/mnt/d`.

DevOps credentials stay under the DevOps NixOS private Linux home. The trust check inspects only
path resolution, owner, mode, kind, mounts, and sockets. It never reads a private key, token, or
credential file. Shared Windows SSH configuration is now limited to ordinary Debian; DevOps NixOS,
AI NixOS, and Debian-MW are excluded.

This is an intra-WSL workload boundary. The trusted Windows user and Windows administrators can
still enter every distribution as root and access its VHD. It is not a boundary against a
compromised Windows host, WSL kernel, or administrator.

## Managed OpenCode launch

Choose the entry point according to the trust boundary needed for the task:

| Task | Command | Boundary |
|---|---|---|
| Ordinary work in a Windows-accessible project | `opencode` | Native Windows user access |
| Autonomous or higher-risk work in a private AI project | `Invoke-OpenCodeSandbox.ps1` below | Private `NixOS-AI` VHD plus verified `nono` policy |

The native CLI is intentionally convenient and is not confined by the Nix/nono policy. Use the
sandbox command when the project or agent activity needs the narrower filesystem, credential,
socket, and network boundary.

Keep AI projects in the private AI VHD beneath `/home/<ai-user>/projects`. Windows VS Code can open
the distribution explicitly. The guest does not receive a Windows drive mount.

```powershell
pwsh -NoProfile -File .\scripts\Invoke-OpenCodeSandbox.ps1 `
  -Project /home/ai/projects/example `
  -CheckOnly
```

Remove `-CheckOnly` only after the preflight is compliant. The immutable launcher checks the
maintenance-owned `nono` binary, exact root-owned profile hash, `nono setup --check-only`, secure
Landlock TCP rule support, representative credential/host/socket denials, and a dry-run. It then
runs `opencode` through `nono`; it never falls back to a direct launch.

The AI generation copies WSL resolver data into an independent `/etc/resolv.conf` and removes the
cross-distribution `/mnt/wsl` mount during boot. The tracked policy records the official
`nolabs-ai/opencode` lineage, extends nono's conservative `default` profile, and selects the
installed `developer` proxy policy plus the reviewed provider/domain allowlist. The WSL2
`insecure_proxy` fallback is not enabled. If secure network enforcement is unavailable, the
managed launch is blocked before OpenCode starts.

## Debian-MW case transfer

Debian-MW no longer needs a host mount. Import and export are explicit streamed state changes:

```powershell
pwsh -NoProfile -File .\scripts\Import-MalwareCase.ps1 `
  -Source D:\Cases\input `
  -CaseId case-20260817

pwsh -NoProfile -File .\scripts\Export-MalwareCase.ps1 `
  -CaseId case-20260817 `
  -Destination D:\Cases\case-20260817-results
```

Import refuses an existing case, reparse points, links, traversal-like names, devices, pipes, and
sockets; it compares every SHA-256 before committing the private case directory. Export performs
the corresponding guest and Windows staging checks and refuses an existing destination. The
receipts contain paths, sizes, and hashes—not evidence bytes.
