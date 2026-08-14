# Changelog

## Unreleased

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
