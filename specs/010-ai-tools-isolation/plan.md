# Implementation Plan: AI Tools and WSL Isolation

**Branch**: `main` | **Date**: 2026-08-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/010-ai-tools-isolation/spec.md`

## Summary

Add two focused desired-state modules: an opt-in `AiTools` module for the requested native agents
and a separate opt-in `AiNixOsWsl` module for the OpenCode CLI boundary; add a `DeveloperEditor`
module for stable VS Code, the pinned Berg source theme, four extensions, and the existing local-font
selection. Strengthen the existing DevOps NixOS and Debian-MW distributions by disabling WSL
interop and automatic host mounts, deploy their configuration through Windows-owned standard-input
streams, keep ordinary Debian explicitly trusted, and add bounded case import/export commands for
Debian-MW. The AI launcher uses a root-owned reviewed `nono` policy and refuses to start unless the
runtime, profile, kernel, filesystem, and network gates pass.

## Technical Context

**Language/Version**: Windows PowerShell 5.1-compatible orchestration; PowerShell 7 validation;
NixOS 26.05 modules; POSIX shell only inside bounded guest helpers

**Primary Dependencies**: WSL 2, NixOS-WSL 2605.7.2, stable VS Code, Node.js LTS/npm, GitHub release
assets, vendor PowerShell installers, Homebrew `nono`, Nix integrity tooling, Windows `tar.exe`

**Storage**: Reviewed PSD1 declarations; separate WSL VHDs; private Linux homes; merge-preserving
VS Code JSON; case manifests containing paths, sizes, and hashes but no evidence content

**Testing**: Focused PowerShell contract harness in Windows PowerShell and PowerShell 7, Pester
adapter, synthetic filesystem/command adapters, Nix evaluation where available, baseline routing,
pre-commit, strict docs

**Target Platform**: Windows 11 Pro, WSL 2, x64; one trusted Windows user; no separate Windows
account

**Performance Goals**: Test/Plan returns in under 20 seconds when distributions are stopped and
does not start an agent; editor JSON merge remains bounded to managed keys; case transfers stream
without a Windows mount inside Debian-MW

**Constraints**: AI tools are opt-in; no installer runs during Test/Plan; no automatic unregister;
no silent package-source substitution; restricted daily users have no sudo; AI, DevOps NixOS, and
Debian-MW have interop/path injection/automount disabled; ordinary Debian remains trusted; no
secret contents are read; managed OpenCode launches fail closed

**Scale/Scope**: Five Windows AI products, one editor and four Marketplace extensions, one pinned
source theme, one new AI NixOS distribution, three restricted WSL boundaries, one trusted Debian
utility distribution, and one bounded Debian-MW case-transfer lifecycle

## Constitution Check

- **Human/AI parity**: PASS. `Set-AiToolsState.ps1`, `Set-DeveloperEditorState.ps1`,
  `Set-AiNixOsWslState.ps1`, `Test-WslTrustBoundary.ps1`, `Import-MalwareCase.ps1`,
  `Export-MalwareCase.ps1`, and `Invoke-OpenCodeSandbox.ps1` are human-first commands before aliases
  or agent routing.
- **Evidence before mutation**: PASS. Test and Plan are observational; state-changing Ensure and
  case-transfer commands are explicit. No live vendor installer or WSL mutation occurs during
  implementation validation.
- **EARS/TDD**: PASS. All 37 requirements map to focused selectors and red contract tests precede
  production files.
- **Focused desired state**: PASS. Native AI tools, editor state, AI NixOS, WSL trust inspection,
  and case transfer remain separate commands; they share only deterministic helpers.
- **Deterministic interfaces**: PASS. Default output is human-readable and `-Json` represents the
  same records. Wrong source, missing enforcement, or drift returns nonzero.
- **Privileged operations**: PASS. Guest root maintenance and distribution restarts occur only in
  explicit Ensure. No module unregisters a distribution.
- **Publication workflow**: PASS. Catalog/capability updates reference this feature and therefore
  activate the final Spec Kit governance gate before commit.

Post-design review: PASS. The trusted Windows host can always administer every WSL VHD; the design
claims an intra-WSL workload boundary, not protection from Windows administrator compromise.

## Project Structure

### Documentation (this feature)

```text
specs/010-ai-tools-isolation/
├── checklists/requirements.md
├── contracts/commands.md
├── data-model.md
├── plan.md
├── quickstart.md
├── research.md
├── spec.md
├── tasks.md
└── traceability.toml
```

### Source Code (repository root)

```text
.config/developer-editor.winget
config/
├── ai-tools.psd1
├── ai-nixos-wsl.psd1
├── capabilities.psd1
├── developer-editor.psd1
├── workstation-modules.psd1
└── wsl-trust-boundaries.psd1
nixos/                         # existing DevOps boundary, interop/automount disabled
nixos-ai/                      # separate locked AI generation and self-check
scripts/
├── AiTools.Core.ps1
├── DeveloperEditor.Core.ps1
├── WslBoundary.Core.ps1
├── Set-AiToolsState.ps1
├── Set-AiNixOsWslState.ps1
├── Set-DeveloperEditorState.ps1
├── Test-WslTrustBoundary.ps1
├── Invoke-OpenCodeSandbox.ps1
├── Import-MalwareCase.ps1
└── Export-MalwareCase.ps1
tests/Test-AiToolsIsolation.ps1
tests/pester/AiToolsIsolation.Tests.ps1
docs/ai-tools-isolation.md
```

**Structure Decision**: Use small core files with injected command/filesystem adapters for tests.
Public scripts own live observation, rendering, explicit process invocation, and exit codes. NixOS
declarations own immutable guest boundary files; PSD1 files own reviewed channels and identities.

## Design Decisions

1. `AiTools` and `AiNixOsWsl` are separately opt-in. `DeveloperEditor` is a separate developer
   module and does not imply AI WSL launch access.
2. Claude Code and Antigravity use only the exact vendor PowerShell-script channels selected by the
   user. Cline and Copilot CLI use their official npm packages. No WinGet Claude declaration
   remains.
3. OpenCode Desktop is a pinned official Windows release asset; OpenCode CLI is a root-owned pinned
   release asset inside the separate AI NixOS distribution.
4. Berg is installed as a local VS Code theme wrapper around the hash-pinned `jx22/berg` theme JSON
   because the repository lacks a package manifest and its old Marketplace listing is not a stable
   source.
5. The existing `.terminal-fonts` preference selects Berkeley Mono when valid; otherwise the
   public `Fira Code` fallback is merged into `editor.fontFamily` and terminal font settings.
6. The AI daily user is non-root and has no sudo. A separate non-login Linux maintenance identity,
   invoked only from trusted Windows, owns the Homebrew prefix and runs `brew install nono`; the
   daily user cannot replace `nono`, OpenCode, the launcher, or its policy.
7. The tracked `nono` profile is root-owned, names the official `nolabs-ai/opencode` lineage, denies
   credential/host/socket paths, and grants only the selected project plus reviewed runtime paths.
8. The managed launcher runs `nono setup --check-only`, policy validation/diff checks, filesystem
   probes, and secure network checks before `exec`. It never enables WSL2 `insecure_proxy`; if
   secure allowlisted network enforcement cannot be proved, OpenCode does not start.
9. DevOps NixOS, AI NixOS, and Debian-MW use `[interop] enabled=false` and `[automount]
   enabled=false`. Deployment is streamed from trusted Windows through `wsl.exe` standard input,
   so no restricted guest needs `/mnt/c` or `/mnt/d`.
10. DevOps credential checks inspect metadata only: private-Linux-filesystem resolution, ownership,
    modes, symlink targets, and socket exposure. Secret bytes are never read or exported.
11. Debian-MW case import/export uses native tar streams driven by Windows, private guest case
    directories, pre/post traversal and link checks, SHA-256 manifests, and explicit output roots.
12. Ordinary Debian retains interop and automount as a trusted administration environment, but no
    AI or hostile-analysis route targets it.

## Complexity Tracking

| Complexity | Why needed | Containment |
|---|---|---|
| Two NixOS declarations | DevOps and AI have different packages, users, and trust roles | Share only reviewed helper concepts and the pinned base image; keep separate flake targets/manifests |
| Linux maintenance identity | A daily agent-owned Homebrew prefix would permit persistent replacement of its future sandbox | Non-login, no sudo, used only through explicit Windows-root maintenance |
| Streaming guest deployment | Restricted guests cannot retain Windows drive mounts | One bounded text/tar streaming helper with synthetic tests |
| Fail-closed network gate | `nono` WSL2 domain filtering is not securely available in every configuration | Never enable insecure proxy fallback; block launch and report the missing gate |
