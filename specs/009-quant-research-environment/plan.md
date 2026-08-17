# Implementation Plan: Quantitative Research Environment

**Branch**: `009-quant-research-environment` | **Date**: 2026-08-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-quant-research-environment/spec.md`

## Summary

Add an opt-in, non-privileged workstation capability for the existing quantitative-research tree. The shared `quant-base` remains an installable uv library project containing OpenBB and common quantitative dependencies. Every research project, including `thesis`, remains a separate uv project with its own declaration, lock, and `.venv`, and references the base through a relative editable path. Observational status uses uv's check/frozen modes and disables OpenBB auto-build; explicit reconciliation exact-syncs from reviewed locks and then refreshes OpenBB generated extension metadata. Jupyter runs from each overlay without global kernel registration.

The later `C:\Users\mariu\Source` to `D:\Source` move is not implemented by this feature. The feature provides only a read-only relocation plan with human and JSON output. Moving, renaming, copying without dry-run, deleting, or creating a junction requires a separate future specification and authorization.

## Technical Context

**Language/Version**: PowerShell 7 for workstation commands; Python 3.12 for the base and overlays; PSD1, TOML, JSON, and Markdown for configuration and contracts

**Primary Dependencies**: uv; OpenBB 4.7.x; JupyterLab 4.6.x; ipykernel; Git; native PowerShell storage/filesystem commands; Robocopy only in read-only `/L` planning/audit form

**Storage**: Tracked `pyproject.toml` and `uv.lock` files in the sibling research tree; generated project-local `.venv` directories; no database owned by this capability

**Testing**: Focused PowerShell contract tests, Pester wrappers, disposable filesystem fixtures, JSON-schema validation, EARS traceability validation, and brownfield characterization before changes

**Target Platform**: Windows 11 Pro x64; PowerShell 7; local NTFS research storage

**Project Type**: Brownfield PowerShell desired-state module controlling sibling uv CLI/library projects

**Performance Goals**: Start a synchronized thesis notebook in under two minutes; create and restore an overlay in under ten minutes with normal network access

**Constraints**: Status and relocation planning perform zero managed/user-file mutations; no global kernelspec registration; no credentials or datasets in tracked configuration; exact per-project locks; only generated `.venv` state may be rebuilt; no relocation executor in this feature

**Scale/Scope**: One shared base, the required `thesis` overlay, and direct child overlays discovered beneath `projects`; current locks contain approximately 109 base and 184 thesis packages

## Constitution Check

*GATE: Passed before Phase 0 research and re-checked after Phase 1 design.*

| Principle / gate | Design evidence | Result |
|---|---|---|
| I. Human/AI Command Parity | Direct scripts and profile commands are specified before capability routing; `config/capabilities.psd1` is updated with the same commands. | PASS |
| II. Evidence Before Capture or Mutation | `Test` and relocation planning use check/frozen/dry-run operations. `Ensure`, `Reinitialize`, overlay creation, and notebook launch remain explicit. | PASS |
| III. EARS Traceability and Test-First Change | All 22 requirements have current manual characterization mappings; tasks must introduce failing focused tests before implementation and replace practical mappings with selectors. | PASS |
| IV. Focused Desired State and Dependency Safety | One opt-in `QuantResearchEnvironment` module declares dependencies, modes, privilege, destructiveness, and order. Relocation execution is excluded. | PASS |
| V. Deterministic Operator Interfaces | Human output is default; `-Json` exposes the same checks; drift and failed gates return actionable nonzero results; commands are documented as PowerShell 7 only. | PASS |
| Platform and publication | No secret or local data is tracked. Implementation publication gates include lint, Tricky human/JSON smoke tests, and strict docs build. | PASS |

No constitutional exception or complexity waiver is required.

## Project Structure

### Documentation (this feature)

```text
specs/009-quant-research-environment/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── checklists/
│   └── requirements.md
└── contracts/
    ├── quant-research-cli.md
    ├── quant-research-config.md
    ├── quant-research-status.schema.json
    ├── source-relocation-cli.md
    └── source-relocation-plan.schema.json
```

### Source Code (repository root)

```text
config/
├── quant-research.psd1                    # portable capability configuration
├── workstation-modules.psd1               # opt-in module registration
└── capabilities.psd1                      # operator/AI routing
scripts/
├── Set-QuantResearchEnvironmentState.ps1  # Test, Ensure, Reinitialize
├── New-QuantResearchOverlay.ps1           # plan/create one new overlay
├── Start-QuantResearchNotebook.ps1        # locked project-local launch
├── Get-SourceRelocationPlan.ps1            # observational plan only
└── Set-PowerShellProfile.ps1               # profile component deployment
profile/
└── QuantResearch.ps1                       # human convenience functions
tests/
├── Test-QuantResearchEnvironment.ps1       # focused contract/integration runner
└── pester/
    └── QuantResearchEnvironment.Tests.ps1  # Pester wrapper
docs/
├── quant-research-environment.md
├── workstation-modules.md
├── desired-state.md
├── Aliases.md
├── sample-outputs.md
└── capabilities/
    └── index.md
```

### Managed sibling research tree

```text
../quant-research/
├── quant-base/
│   ├── pyproject.toml
│   ├── uv.lock
│   ├── src/quant_base/
│   └── .venv/                 # generated, never portable state
└── projects/
    └── thesis/
        ├── pyproject.toml      # relative editable ../../quant-base source
        ├── uv.lock             # overlay-specific exact resolution
        ├── src/thesis/
        ├── notebooks/
        └── .venv/              # generated, isolated runtime
```

**Structure Decision**: Extend the repository's existing declarative module/script/profile/test/documentation layout. Keep the research tree a separate portable Git repository and do not make it a uv workspace: a workspace would share a lock and environment, contradicting overlay isolation.

## Module and Configuration Design

Register `QuantResearchEnvironment` with this desired-state contract:

| Field | Value |
|---|---|
| Stage / Order | `Extended` / `58` |
| Runtime | `PowerShell7` |
| DependsOn | `Packages`, `PowerShellProfile` |
| SupportedModes | `Test`, `Ensure`, `Reinitialize` |
| Default | `false` |
| Privileged / Destructive | `false` / `false` |

`config/quant-research.psd1` records portable relative structure and expected declarations, not credentials or local data. It includes schema version 1, logical root `%USERPROFILE%\Source\quant-research`, base `quant-base`, overlay root `projects`, Python 3.12, generated environment `.venv`, representative imports, notebook packages, OpenBB entry-point groups, protected content patterns, and the disabled deferred-relocation target `D:\Source`.

Overlay discovery is convention-based from `projects/*/pyproject.toml`; adding an experiment does not require changing the workstation catalog. Every base source must be relative, resolve within the research root, and for the current thesis resolve from `../../quant-base`.

## Lifecycle Design

### Brownfield characterization

Before behavior changes, tests characterize the current base and thesis declarations, exact locks, relative relationship, imports, OpenBB extension inventory, Jupyter entry point, global kernelspec inventory, and absence of changes from observational checks. The present base and thesis `uv lock --check` and `uv sync --check` results form initial evidence, not an excuse to skip tests.

### Observational status (`Test`)

For each selected project, the command:

1. validates configuration, project boundaries, runtime declarations, base paths, locks, and generated-environment state;
2. runs `uv lock --check` and `uv sync --check` (or the equivalent dry-run contract where reconciliation details are needed);
3. runs representative imports through `uv run --frozen --no-sync python -B` with `PYTHONDONTWRITEBYTECODE=1` and `OPENBB_AUTO_BUILD=false`;
4. compares installed OpenBB extension entry points with generated reference metadata without invoking `openbb-build`;
5. verifies the project-local notebook command and snapshots user/system kernel directories; and
6. emits equivalent human or schema-valid JSON results, returning nonzero on drift/failure.

The status path must not run bare `uv run`, `uv sync`, OpenBB's builder, an installer, a kernelspec registration command, or any relocation mutation.

### Explicit reconciliation (`Ensure` and `Reinitialize`)

`Ensure` hashes the declaration and lock, performs `uv sync --locked`, explicitly runs `openbb-build` only when extension reconciliation is required, verifies imports in a fresh process, and confirms the declaration/lock hashes remain unchanged. It owns generated runtime state only.

`Reinitialize` replaces only `.venv`. It first renames the generated environment to a unique backup, creates and validates the replacement at its final path from the existing lock, and restores the backup if validation fails. A busy environment or failed rename stops before replacement. Neither mode rewrites notebooks, source, datasets, credentials, exports, arbitrary user files, `pyproject.toml`, or `uv.lock`.

### New overlay transaction

`New-QuantResearchOverlay.ps1` supports `-Plan`, human output, and `-Json`, refuses an existing destination, and stages a new project outside the final path. It declares Python 3.12, a relative editable dependency on `../../quant-base`, independent notebook dev dependencies, its own lock, and an isolated `.venv`. It validates the staged overlay before one final rename into `projects/<name>` and removes only its own staging directory on failure. Existing projects and the base are hash-compared before and after.

### Notebook launch

`Start-QuantResearchNotebook.ps1` resolves a selected overlay, requires the locked environment to be compliant, and launches `uv run --locked --no-sync jupyter lab` from that overlay. Profile function `quant-notebook` exposes it to a human operator. The implementation never calls `ipython kernel install` or `jupyter kernelspec install`; the environment-local default Python kernel is sufficient.

## Deferred Source Relocation Boundary

This feature implements `Get-SourceRelocationPlan.ps1` only. It resolves and reports source/target paths, local fixed-volume and NTFS suitability, health, size/capacity, conflicts, reparse points, encrypted files, generated environments, repositories, active-use risks, copy preview, verification gates, rollback, rebuild steps, and blockers. Human and JSON views represent the same data, with `planOnly=true`, `executionAvailable=false`, `authorized=false`, and `mutationPerformed=false`.

The implementation contains no relocation executor and no path that calls `Move-Item`, `Rename-Item`, `New-Item -ItemType Junction`, `mklink`, recursive deletion, or Robocopy without `/L`. Suggested future commands may appear only as rendered plan strings. A later feature must separately specify and authorize copy, cryptographic and repository verification, fresh confirmation, recoverable backup rename, junction creation, rollback, and post-move environment recreation.

## Requirement-to-Design Translation

Production code does not embed requirement IDs. Focused tests may use these stable selectors. Because the scripts do not yet exist, `traceability.toml` retains honest manual/characterization mappings during planning; `$speckit-tasks` must schedule failing tests first and implementation must replace every practical manual entry with the corresponding selector before the final EARS gate.

| Requirement | Design decision | Planned verification selector / disposition |
|---|---|---|
| REQ-001 | Direct status and reconciliation commands precede profile/capability routing. | `CommandContract` |
| REQ-002 | Human and JSON renderers share one result model. | `OutputParity` |
| REQ-003 | Validate Python, OpenBB, shared dependencies, and installable base package declarations. | `BaseDeclaration` |
| REQ-004 | Treat the reviewed base lock as the restoration source. | `LockReproducibility` |
| REQ-005 | Resolve and constrain the thesis relative path within the root. | `RelativeBaseRelationship` |
| REQ-006 | Discover separate declarations, locks, and `.venv` paths; prohibit a uv workspace. | `OverlayIsolation` |
| REQ-007 | Stage overlay changes and hash all unaffected declarations. | `OverlayMutationIsolation` |
| REQ-008 | Launch locked Jupyter from the selected overlay. | `NotebookEntryPoint` |
| REQ-009 | Never register kernels; compare exact global kernelspec inventories. | `KernelRegistryIsolation` |
| REQ-010 | Status compares extension metadata; Ensure explicitly rebuilds then verifies. | `OpenBbExtensions` |
| REQ-011 | Frozen/no-sync checks disable bytecode and OpenBB auto-build. | `ObservationalStatus` |
| REQ-012 | Stage risky creation/rebuild work and preserve the prior lock/declaration/runtime on failure. | `FailureAtomicity` |
| REQ-013 | Limit reconciliation to declared packages and generated `.venv`/OpenBB assets. | `ReconciliationScope` |
| REQ-014 | Seed and hash protected user-content classes around reconciliation. | `UserContentPreservation` |
| REQ-015 | Reject credentials/data in portable configuration and document external ownership. | `CredentialBoundary` |
| REQ-016 | Register module, profile functions, docs, and capability routes together. | `CapabilityRouting` |
| REQ-017 | Ordinary commands and relocation planning have no relocation mutation path. | `RelocationNonMutation` |
| REQ-018 | Emit all relocation-plan fields in both human and JSON views. | `RelocationPlanContract` |
| REQ-019 | Report unsuitable/conflicting destinations as blockers; no executor exists. | `RelocationGuard` |
| REQ-020 | Execution is intentionally deferred to a separately approved future feature. | Manual: verify executor absence now; future disposable cutover test must prove backup-before-junction ordering. |
| REQ-021 | Recreate generated environments after a disposable whole-tree move and reverify paths/imports. | `MovedRootRebuild` |
| REQ-022 | Keep the opt-in module and scripts separate from diagnostic/profiling/forensic capabilities. | `FocusedBoundary` |
| REQ-023 | Add PyXLL and plotting packages to the base declaration and lock. | `PyXllDeclaration` |
| REQ-024 | Observe package, architecture, add-in, config, WebView2, plots, and redacted license state. | `PyXllStatus` |
| REQ-025 | Activate only an installed payload against the base environment. | `PyXllActivation` |
| REQ-026 | Read the ignored local key and append only the final config license section. | `PyXllLicenseBoundary` |
| REQ-027 | Keep the key out of every output and process boundary. | `PyXllLicenseBoundary` |
| REQ-028 | Enable HTML/SVG/resizing and a local WebView2 data folder. | `PyXllInteractivePlots` |
| REQ-029 | Complete all prerequisites before activation or config replacement. | `PyXllFailureAtomicity` |
| REQ-030 | Gate the vendor's interactive installer behind a dedicated confirmation switch. | `PyXllActivation` |
| REQ-031 | Lock pyxll-jupyter and JupyterLab in the OpenBB base environment. | `PyXllJupyterRibbon` |
| REQ-032 | Observe the distributions, ribbon entry point, runtime, and active settings. | `PyXllJupyterRibbon` |
| REQ-033 | Render an enabled JupyterLab ribbon policy before the terminal license section. | `PyXllJupyterRibbon` |

The planned selector form is:

```powershell
pwsh -NoProfile -File .\tests\Test-QuantResearchEnvironment.ps1 -Section <Selector>
```

Pester parameterizes the same sections rather than maintaining a second behavioral implementation.

## Publication and Acceptance Gates

After implementation, run in this order:

1. focused contract/integration runner and Pester wrapper;
2. `ears-sdd validate --phase implementation` and the final traceability gate;
3. `lint-powershell`;
4. direct and `tricky` human/JSON smoke tests for status and relocation planning;
5. `uv run --group docs mkdocs build --strict`.

Documentation updates include direct command contracts, profile aliases, sample outputs, capability routing, desired-state/module catalogs, README, changelog, and mkdocs navigation. The frozen inventories in `specs/001-workstation-baseline/spec.md` must be updated from 45 to 46 modules and 28 to 29 capabilities with the new entries.

The PyXLL extension adds no module or capability-count change. Its implementation uses a focused
core helper for deterministic config/license/registry checks and keeps first-install interaction in
the existing direct quant state command. Tests inject disposable payload, registry-view, WebView2,
and license fixtures; they never require or expose the real entitlement.

## Complexity Tracking

No constitutional violations require justification. The two-root layout is intentional: workstation automation remains in this repository, while portable doctoral research projects retain independent declarations and locks in the sibling research repository.
