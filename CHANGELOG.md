# Changelog

## Unreleased

## 2.3.0 - 2026-08-16

- Add the optional, hash-pinned Autopsy 4.23.1 Windows forensic GUI with complete private dependencies, namespaced helper commands, matching native Sleuth Kit 4.15.0 CLI tools, deterministic installed-file verification, and MSI repair for binary drift.
- Keep Microsoft Defender installed while exposing explicit protection controls and durable, verified Autopsy process and case-output exclusions so forensic results are not silently quarantined.
- Keep unmatched inbound traffic blocked while honoring an expert's application-listener approval on every firewall profile, with the resulting exposure and Autopsy Solr listener documented for review.

## 2.2.0 - 2026-08-16

- Add native-Windows, read-only segmented EWF verification with pre/post evidence identities, pinned tool provenance, bounded raw artifacts, and durable human/JSON reports in both supported PowerShell runtimes.
- Add an opt-in forensic package lifecycle with verified source signatures, AMD64/import policy, two-lane benign compatibility certification, candidate-only ordinary update reporting, atomic rollback, draft/no-clobber release workflows, and explicit approval/publication boundaries.

## 2.1.0 - 2026-08-16

- Add a release-pinned NixOS-WSL environment for Helm, kubectl, a separately locked current Pulumi CLI, and native OpenSSH, with locked-flake drift checks, complete Nix-store content verification, and one permission-safe SSH client configuration shared by Windows, trusted Debian, and NixOS while excluding Debian-MW.
- Document the NixOS environment lifecycle, SSH boundaries, reviewed input updates, generation rollback, alteration response, verification cost, and the exact boundary between complete immutable-store hashing and mutable WSL state.
- Expand pre-commit with non-mutating YAML, JSON, TOML, staged-file safety, Hadolint, and actionlint checks backed by direct human lint commands and explicit native dependency installation.
- Add a plan-first `update` command for Windows software servicing, WinGet, Scoop, WSL, both declared Debian distributions, managed Homebrew instances, Docker/Podman reconciliation, and final current-release drift correction.
- Add general clean-versus-target Windows Sandbox behavior commands and graph-first binary differencing through Ghidra, BinExport, and BinDiff, retaining canonical `.BinDiff` SQLite plus a separate bounded address-keyed analysis sidecar without raw/version/decompiler fallback.
- Rewrite the developer documentation around human-operable commands, representative local output, execution boundaries, and direct paths from common Windows troubleshooting tasks to the corresponding evidence tools.

## 2.0.0 - 2026-08-15

- Expand the staged workstation DSL with PowerShell 7 bootstrap gates, native development toolchains, Java, Go, Rust, CMake, MSBuild, Pester, and compatible shared profiles for Windows PowerShell 5.1 and PowerShell Core.
- Add rootless Podman and pyinfra-managed Debian WSL automation, keeping Dagger isolated to its Docker-first Linux environment.
- Add evidence-first suspicious-file analysis for binaries, Office documents, and PDFs with static tooling, Windows Sandbox detonation plans, clean-control diffs, host/guest hash comparison, and explicit execution and networking confirmations.
- Add the release-pinned `malware_hashes` command, Ghidra and related analysis tools, retained ETW/file/handle evidence, and human-readable aliases before AI routing.
- Migrate the repository to release-pinned Spec Kit with reusable EARS/TDD validation, complete requirement traceability, dependency-ordered tasks, and governance tests that prevent requirements from silently falling out of the implementation flow.
- Add strict publication gates for PowerShell lint, human and JSON Tricky routes, capability documentation, specification integrity, and reproducible MkDocs builds.

## 1.0.0 - 2026-08-14

- Add managed focus-follows-mouse behavior that explicitly preserves window Z-order.
- Convert the defensible legacy Windows hardening state into a reviewed `DeveloperBaseline` DSL, idempotent resource, and separate attack-surface documentation.
- Add a separate opt-in `DeveloperMinimal` debloat profile with protected-package checks, pre-removal snapshots, and explicit confirmation.
- Add inclusion-based workstation modules with a declarative dependency catalog, topological plans, and focused Test/Ensure execution.
- Install Contour Terminal from the hash-pinned official MSI, migrate away from the broken Scoop package, translate the BlueTerm theme, create a Desktop shortcut, and gate compliance on the active display driver and a bounded graphics launch.
- Add hash-pinned per-user Fira Code state, ignored local terminal-font selection, PowerShell 7 dependency ordering, blinking Contour cursor, vertical prompt marks, clickable working-directory links, and documented tab controls.
- Add focused Git, PowerShell 7, Scoop, Windows feature, Linux Homebrew, and Linux automation resources so optional tools are installed before dependants use them.
- Run Debian developer-package state locally through pinned pyinfra, with `.wsl-env` selecting the distribution and normal user, and install Dagger through its official Homebrew tap for future Docker-first projects.
- Add `workstation-help` / `wshelp` discovery for managed commands, aliases, and repository skills with human and JSON output.
- Improve headless WinDbg analysis with CLI symbol downloads and document the display-driver verification lesson for OpenGL/GLSL failures.
- Add MkDocs sample outputs for dependency plans, focused state tests, Contour deployment, help discovery, and `tricky ... -Json` routing.

## 0.2.0 - 2026-08-14

- Declare Hyper-V and Windows Sandbox with validated dependency ordering and idempotent test/ensure commands.
- Bootstrap Windows sudo before privileged resources and stop dependent repairs when bootstrap fails.
- Add Windows virtualization routing, operator commands, and desired-state documentation.
- Make npm and npx explicit outputs of the managed Node.js LTS package.
- Add a pinned Microsoft SkillOpt-Sleep integration with one-skill targeting, reviewed task files, held-out validation, ignored staging, and explicit adoption.
- Add repository skill validation locally and in GitHub Actions.
- Add a pinned PSScriptAnalyzer pre-commit hook and matching GitHub Actions lint workflow.
- Keep Defender exclusion paths in ignored local state and expose SSH, RDP, and HTTP application ports in the managed firewall policy.

## 0.1.0 - 2026-08-13

- Establish the Linux-style PowerShell workstation desired state.
- Add memory, event-log, crash, network, firewall, security-state, developer-tool, and profiling commands.
- Add the evidence-first Tricky case format with JSON, Markdown, and standalone HTML reports.
- Add capability-focused MkDocs documentation and separate repository-local Codex skills.
- Add reproducible GitHub Pages and tagged documentation-release workflows.
