# Implementation Plan: Managed Workstation Update

**Branch**: `main` | **Date**: 2026-08-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-workstation-update/spec.md`

## Summary

Add a plan-first `update` operator command backed by a focused PowerShell orchestrator and a
declarative update-stage catalog. Explicit `-Run` execution services Windows software updates,
ordinary WinGet and Scoop applications, the WSL host runtime, both declared Debian distributions,
the declared developer Homebrew instance, developer Docker, and Debian-MW rootless Podman. The
final stage reapplies and tests the current checkout's default non-destructive workstation state.
Synthetic execution tests cover ordering, failures, pins, privilege, and output without modifying
the host.

## Technical Context

**Language/Version**: Windows PowerShell 5.1-compatible scripts; PowerShell 7.6+ default lane;
existing Python 3.13/pyinfra 3.9.2 Linux deploys

**Primary Dependencies**: Windows Update Agent COM API, WinGet, Scoop, WSL CLI, Debian APT,
Homebrew, existing developer-Docker and rootless-Podman pyinfra resources, existing workstation DSL

**Storage**: `VERSION`, existing `.wsl-env`, existing package-manager state, update-stage result
objects retained only in process unless the caller redirects JSON

**Testing**: Dependency-free PowerShell contract harness with a synthetic native-command executor,
Pester adapter, dual-shell plan checks, final EARS validation

**Target Platform**: x64 Windows 11 Pro with Windows PowerShell 5.1 and PowerShell Core

**Project Type**: PowerShell workstation desired-state and operator CLI

**Performance Goals**: Static plan renders in under two seconds without network access; each
selected stage reports progress immediately; no artificial sleeps or hidden background work

**Constraints**: No automatic reboot, WSL shutdown, source-checkout replacement, container prune,
Scoop cleanup, pin override, driver update, undeclared-distribution discovery, or security weakening

**Scale/Scope**: Nine public targets resolving to eight ordered stages across one Windows host and
two declared WSL distributions

## Constitution Check

- **Human/AI parity**: `update` and `scripts/Invoke-WorkstationUpdate.ps1` are the primary public
  interfaces; capability routing references those exact human commands.
- **Evidence before mutation**: The default invocation is a static observational plan. `-Run` is
  mandatory for all mutations and the final Test records unresolved drift.
- **EARS/TDD**: All 25 requirements have named selectors. Synthetic failing tests precede command
  implementation; no production source contains copied EARS prose or requirement IDs.
- **Focused desired state**: Update orchestration has its own catalog because servicing actions are
  not idempotent workstation resources. Docker, Podman, profiles, and policy continue through their
  existing focused resources and module dependencies.
- **Deterministic interfaces**: Human output is default, `-Json` is bounded and schema-versioned,
  selected targets resolve topologically, and failures skip only dependent stages.
- **Platform safety**: Windows servicing is software-only and explicit; WSL roots are named from
  `.wsl-env`; Homebrew targets are declared; no restart, cleanup, prune, or discovery is implicit.

No constitutional exception is required. The same checks still pass after Phase 1 design.

## Project Structure

### Documentation (this feature)

```text
specs/006-workstation-update/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── checklists/requirements.md
├── contracts/workstation-update-cli.md
└── tasks.md
```

### Source Code (repository root)

```text
config/
└── workstation-update.psd1
profile/
└── Aliases.ps1
scripts/
├── Invoke-WindowsUpdate.ps1
└── Invoke-WorkstationUpdate.ps1
tests/
├── Test-WorkstationUpdate.ps1
└── pester/WorkstationUpdate.Tests.ps1
```

Existing integration points change narrowly: `config/capabilities.psd1`,
`tests/Test-PowerShellTestingState.ps1`, `.specify/ears-sdd.toml`, README, desired-state/alias/sample
output docs, MkDocs navigation if a dedicated page is added, and the release changelog.

**Structure Decision**: Keep release-neutral servicing out of `Apply-Workstation.ps1`; after external
updaters finish, call that existing orchestrator as the final release-aware drift correction. Keep
Windows Update in a separately human-runnable script so privilege and restart reporting remain
inspectable without the aggregate command.

## Requirement-to-design translation

| Requirements | Design decision | Verification |
|---|---|---|
| REQ-001, REQ-024, REQ-025 | One profile wrapper and direct script with shared syntax, docs, routing, discovery, and dual-shell parse/plan | `CommandSurface`, `DualShellContract` |
| REQ-002–REQ-006 | Static catalog, target closure, topological sort, default plan, explicit `-Run`, bounded schema | `PlanContract`, `OutputContract`, `TargetContract`, `DependencyContract`, `SafetyContract` |
| REQ-007, REQ-008 | Separate WUA wrapper searches `Type='Software'`, excludes drivers, installs only accepted updates, and reports reboot state | `WindowsContract`, `SafetyContract` |
| REQ-009 | `winget upgrade --all` with agreements/interactivity bounds; omit unknown, pinned, and forced-uninstall switches; accept official no-update code | `WinGetContract` |
| REQ-010 | Verify declared Scoop state, then update core/buckets and `*`; omit cleanup/removal | `ScoopContract` |
| REQ-011 | Use supported `wsl.exe --update`; never issue `wsl --shutdown` | `WslContract`, `SafetyContract` |
| REQ-012, REQ-013 | Resolve only `.wsl-env` pairs and run root APT refresh/full-upgrade once per declared distribution | `LinuxContract`, `SafetyContract` |
| REQ-014, REQ-015 | Catalog declares developer Homebrew only; pin release-owned formulae before `brew update`/`brew upgrade` | `HomebrewContract` |
| REQ-016, REQ-017 | Invoke existing Docker and Podman Ensure/Test resources after Linux packages | `ContainerContract` |
| REQ-018 | Per-stage dependency state skips blocked dependants while independent roots continue | `DependencyContract`, `ExecutionContract` |
| REQ-019, REQ-020 | Final current-checkout `Apply-Workstation Ensure` and Test using default non-destructive module selection | `ReconciliationContract`, `DualShellContract` |
| REQ-021, REQ-022 | Negative command allowlist and explicit sudo/root metadata and invocation | `SafetyContract`, `PrivilegeContract` |
| REQ-023 | One normalized terminal state per selected stage, aggregate restart and exit flags | `OutputContract`, `ExecutionContract` |

## Complexity Tracking

No constitution violations or exceptional architecture are introduced.
