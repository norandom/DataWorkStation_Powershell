# Tasks: Quantitative Research Environment

**Input**: Design documents from `specs/009-quant-research-environment/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`

**Tests**: Mandatory. Every behavior begins with an observed failing selector. Tests use disposable research trees, deterministic uv/OpenBB process seams, and temporary kernel registries; they do not resolve packages from the network, modify the real doctoral tree, start a persistent notebook server, or perform relocation.

**Organization**: Tasks are grouped by user story so each story produces an independently testable increment. Production code does not contain requirement IDs; the task and test layers carry traceability.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because the task uses different files and has no dependency on incomplete work
- **[Story]**: Maps the task to the corresponding user story in `spec.md`
- Every behavior task names its covered `REQ-NNN` requirements and test selectors

## Phase 1: Setup and Test Infrastructure

**Purpose**: Establish isolated test support without implementing quantitative-environment behavior.

- [X] T001 Create the section-addressable focused runner in `tests/Test-QuantResearchEnvironment.ps1`, the Pester adapter in `tests/pester/QuantResearchEnvironment.Tests.ps1`, and register the adapter in `tests/Test-PowerShellTestingState.ps1`
- [X] T002 [P] Add disposable research-root, manifest/lock, protected-content, process-result, kernel-registry, reparse-point, and cleanup builders in `tests/helpers/QuantResearchTestSupport.ps1`; all generated state must remain under the test temporary directory
- [X] T003 [P] Add minimal synthetic base/thesis declarations, lock inventories, OpenBB reference metadata, and expected hashes in `tests/fixtures/quant-research/README.md` and `tests/fixtures/quant-research/expected.psd1` without credentials, datasets, environments, or downloaded packages
- [X] T004 Run the empty-production command-contract harness and schema parsing checks, then record the expected missing-command red baseline and the current real base/thesis `uv lock --check`, `uv sync --check`, relative-path, and global-kernel characterization in `specs/009-quant-research-environment/verification-log.md`

---

## Phase 2: Foundational Portable Boundary

**Purpose**: Define the portable configuration and shared command-routing contracts that block all user stories.

**Critical gate**: T005 and T006 must be observed failing before T007 or any story implementation begins.

### Failing tests

- [X] T005 Expand and observe failing portable-root expansion, project-boundary, protected-pattern, credential/data rejection, and focused-capability assertions for REQ-015 and REQ-022 in `tests/Test-QuantResearchEnvironment.ps1#CredentialBoundary`, `#FocusedBoundary`, and `#ConfigurationContract`
- [X] T006 Expand and observe failing direct-command-before-wrapper, module metadata/dependency/order, Apply dispatcher, profile deployment, and capability-route assertions for REQ-001, REQ-016, and REQ-022 in `tests/Test-QuantResearchEnvironment.ps1#CommandContract`, `#CapabilityRouting`, and `#FocusedBoundary`

### Implementation

- [X] T007 Define schema-versioned portable research-root, Python, base, overlay, OpenBB, kernel, protected-content, and disabled-relocation settings for REQ-015 and REQ-022 in `config/quant-research.psd1` using `#CredentialBoundary`, `#FocusedBoundary`, and `#ConfigurationContract`

**Checkpoint**: Configuration is portable and safe to publish; direct commands, wrappers, and catalog routing remain red until their story implementations exist.

---

## Phase 3: User Story 1 - Run Thesis Research from One Stable Base (Priority: P1) MVP

**Goal**: Inspect the existing base/thesis relationship and start Jupyter from the thesis `.venv` without global kernels.

**Independent test**: Against the synthetic fixture and the existing tree in observational mode, validate the Python/base/lock relationship, run representative imports with OpenBB auto-build and bytecode disabled, invoke a bounded Jupyter version probe through the locked thesis environment, and compare exact user/system kernel inventories before and after.

### Failing tests

- [X] T008 [US1] Expand and observe failing supported-Python, installable shared library, OpenBB/shared dependency, exact lock, relative `../../quant-base` containment, and whole-tree portability assertions for REQ-003 through REQ-005 in `tests/Test-QuantResearchEnvironment.ps1#BaseDeclaration`, `#LockReproducibility`, and `#RelativeBaseRelationship`
- [X] T009 [US1] Expand and observe failing locked thesis Jupyter invocation, overlay interpreter identity, representative base/thesis import, argument-forwarding, no-install-command, and unchanged global kernelspec assertions for REQ-008 and REQ-009 in `tests/Test-QuantResearchEnvironment.ps1#NotebookEntryPoint` and `#KernelRegistryIsolation`

### Implementation

- [X] T010 [US1] Implement portable configuration loading, base/thesis discovery, Python/declaration/lock checks, relative base containment, and frozen no-sync import probes for REQ-001 and REQ-003 through REQ-005 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#CommandContract`, `#BaseDeclaration`, `#LockReproducibility`, and `#RelativeBaseRelationship`
- [X] T011 [US1] Implement selected-overlay preflight and array-safe `uv run --locked --no-sync jupyter lab` foreground launch with exact kernel snapshots and no kernelspec installation for REQ-008 and REQ-009 in `scripts/Start-QuantResearchNotebook.ps1` using `#NotebookEntryPoint` and `#KernelRegistryIsolation`
- [X] T012 [US1] Add the thin `quant-notebook` wrapper only after the direct script is green and deploy it through `scripts/Set-PowerShellProfile.ps1` and `profile/QuantResearch.ps1` for REQ-008 and REQ-009 using `#NotebookEntryPoint` and `#KernelRegistryIsolation`
- [X] T013 [US1] Run all US1 selectors against disposable fixtures plus bounded observational checks of `..\quant-research\quant-base` and `..\quant-research\projects\thesis`, and record imports, timing, lock checks, and zero global-kernel delta in `specs/009-quant-research-environment/verification-log.md`

**Checkpoint**: The thesis notebook workflow is usable without global kernel management. This is the suggested MVP stopping point.

---

## Phase 4: User Story 2 - Create an Independent Project Overlay (Priority: P2)

**Goal**: Plan and explicitly create one independently locked overlay that inherits the base without changing existing projects.

**Independent test**: Create a disposable overlay with one overlay-only dependency through a deterministic uv seam, reproduce it from tracked state, and compare the base plus every pre-existing overlay declaration and lock before and after.

### Failing tests

- [X] T014 [US2] Expand and observe failing plan-only default, destination refusal, relative editable base, independent manifest/lock/environment, no-workspace, and unaffected-project hash assertions for REQ-005 through REQ-007 in `tests/Test-QuantResearchEnvironment.ps1#RelativeBaseRelationship`, `#OverlayIsolation`, and `#OverlayMutationIsolation`
- [X] T015 [US2] Expand and observe failing staging-directory, dependency-resolution failure, validation failure, final-rename, cleanup, and last-recorded-state preservation assertions for REQ-012 in `tests/Test-QuantResearchEnvironment.ps1#FailureAtomicity`

### Implementation

- [X] T016 [US2] Implement human/JSON plan output, strict overlay naming, absent-destination and base containment checks, inert command preview, and relative editable base declaration for REQ-005 through REQ-007 in `scripts/New-QuantResearchOverlay.ps1` using `#RelativeBaseRelationship`, `#OverlayIsolation`, and `#OverlayMutationIsolation`
- [X] T017 [US2] Implement explicit `-Run` staging, Python 3.12 declaration, notebook dev group, requested dependency addition, independent lock/sync, frozen probes, atomic final rename, and own-staging-only rollback for REQ-006, REQ-007, and REQ-012 in `scripts/New-QuantResearchOverlay.ps1` using `#OverlayIsolation`, `#OverlayMutationIsolation`, and `#FailureAtomicity`
- [X] T018 [US2] Add the thin `quant-overlay` wrapper after direct plan/run behavior is green in `profile/QuantResearch.ps1` for REQ-006 and REQ-007 using `#OverlayIsolation` and `#OverlayMutationIsolation`
- [X] T019 [US2] Run the overlay plan, successful creation, overlay-only dependency, existing-destination, incompatible-resolution, and reproduction cases and record unchanged base/other-overlay hashes in `specs/009-quant-research-environment/verification-log.md`

**Checkpoint**: New experiments can extend the shared base while retaining independent locks and environments.

---

## Phase 5: User Story 3 - Maintain and Diagnose the Environment Safely (Priority: P3)

**Goal**: Report drift without mutation and explicitly reconcile or rebuild only generated declared state.

**Independent test**: Seed bounded drift and protected content in a disposable overlay, compare human and JSON status, apply Ensure and Reinitialize separately, and verify exact lock restoration, OpenBB extension freshness, actionable failures, rollback, and unchanged user content.

### Failing tests

- [X] T020 [US3] Expand and observe failing human/JSON field parity, schema, exit code, runtime/base/lock/notebook/import coverage, frozen/no-sync command, disabled bytecode/OpenBB auto-build, repeated-status hash, and no-bare-uv assertions for REQ-002 and REQ-011 in `tests/Test-QuantResearchEnvironment.ps1#OutputParity` and `#ObservationalStatus`
- [X] T021 [US3] Expand and observe failing installed-entry-point versus generated-reference comparison, stale-extension drift, Ensure-only `openbb-build`, fresh-process provider/router verification, and post-build compliance assertions for REQ-010 in `tests/Test-QuantResearchEnvironment.ps1#OpenBbExtensions`
- [X] T022 [US3] Expand and observe failing locked-sync, declaration/lock preservation, generated-state-only diff, protected notebook/source/data/credential/export hash, busy environment, failed replacement, backup restore, and actionable nonzero assertions for REQ-012 through REQ-014 in `tests/Test-QuantResearchEnvironment.ps1#FailureAtomicity`, `#ReconciliationScope`, and `#UserContentPreservation`

### Implementation

- [X] T023 [US3] Complete observational `Test` project selection, `uv lock --check`, `uv sync --check`, frozen/no-sync probes, OpenBB auto-build suppression, kernel inventory, drift aggregation, and actionable nonzero status for REQ-001, REQ-002, and REQ-011 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#CommandContract`, `#OutputParity`, and `#ObservationalStatus`
- [X] T024 [US3] Implement one internal result model with concise default rendering and exactly one schema-conformant JSON object for REQ-002 and REQ-011 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#OutputParity` and `#ObservationalStatus`
- [X] T025 [US3] Implement explicit `Ensure` with manifest/lock pre-hashes, `uv sync --locked`, extension-drift-triggered `openbb-build`, fresh-process probes, and post-hash/content safeguards for REQ-010 and REQ-013 through REQ-015 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#OpenBbExtensions`, `#ReconciliationScope`, `#UserContentPreservation`, and `#CredentialBoundary`
- [X] T026 [US3] Implement explicit `Reinitialize` with exact `.venv` path validation, busy-path refusal, unique backup rename, locked replacement at the final path, validation, and backup restoration on failure for REQ-012 through REQ-014 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#FailureAtomicity`, `#ReconciliationScope`, and `#UserContentPreservation`
- [X] T027 [US3] Add thin `quant-status`, `quant-sync`, and `quant-rebuild` wrappers after the direct Test/Ensure/Reinitialize command is green in `profile/QuantResearch.ps1` for REQ-001 and REQ-002 using `#CommandContract` and `#OutputParity`
- [X] T028 [US3] Register the opt-in non-privileged `QuantResearchEnvironment` module with stage/order/dependencies/modes, add direct dispatcher routing, and deploy the focused profile component for REQ-001, REQ-016, and REQ-022 in `config/workstation-modules.psd1`, `Apply-Workstation.ps1`, and `scripts/Set-PowerShellProfile.ps1` using `#CommandContract`, `#CapabilityRouting`, and `#FocusedBoundary`
- [X] T029 [US3] Run repeated Test, Ensure, Reinitialize success/failure, stale OpenBB metadata, protected-content, and busy-environment cases and record mutation boundaries, restoration evidence, human/JSON parity, and actionable exits in `specs/009-quant-research-environment/verification-log.md`

**Checkpoint**: Maintenance owns only declared packages and generated runtime state; research content and recorded dependency state survive failed operations.

---

## Phase 6: User Story 4 - Plan a Later Source-Directory Relocation (Priority: P4, Deferred)

**Goal**: Produce a complete read-only Source relocation plan while exposing no relocation execution capability.

**Independent test**: Run human and JSON planning against disposable suitable, missing-drive, insufficient-capacity, conflicting-target, reparse-point, encrypted-file, and active-use fixtures; compare all source/target trees and link metadata before and after; then move only a disposable complete research fixture and test environment recreation separately.

### Failing tests

- [X] T030 [US4] Expand and observe failing exact path/volume/capacity/repository/environment/risk/preview/verification/rollback/rebuild field parity plus zero-filesystem-change assertions for REQ-017 and REQ-018 in `tests/Test-QuantResearchEnvironment.ps1#RelocationNonMutation` and `#RelocationPlanContract`
- [X] T031 [US4] Expand and observe failing unsuitable-volume, conflict, reparse/loop, EFS, active-use, stale-plan, dry-run-only Robocopy, no-executor, no-copy/move/rename/delete/junction/process-kill, and deferred backup-before-junction disposition assertions for REQ-019 and REQ-020 in `tests/Test-QuantResearchEnvironment.ps1#RelocationGuard`
- [X] T032 [US4] Expand and observe failing disposable whole-tree move, copied-environment rejection, generated `.venv` recreation, independent locked sync, relative base revalidation, imports, OpenBB inventory, and unchanged global kernels assertions for REQ-021 in `tests/Test-QuantResearchEnvironment.ps1#MovedRootRebuild`

### Implementation

- [X] T033 [US4] Implement observational source/target canonicalization, local fixed NTFS volume/health/capacity checks, non-following reparse/EFS/environment/repository inventories, active-use warnings, deterministic plan fingerprint, and equivalent human/JSON output for REQ-017 and REQ-018 in `scripts/Get-SourceRelocationPlan.ps1` using `#RelocationNonMutation` and `#RelocationPlanContract`
- [X] T034 [US4] Implement blockers and inert `/L` copy, verification, rollback, and rebuild previews while hard-coding `planOnly=true`, `executionAvailable=false`, `authorized=false`, and `mutationPerformed=false` and exposing no executor for REQ-017 through REQ-020 in `scripts/Get-SourceRelocationPlan.ps1` using `#RelocationNonMutation`, `#RelocationPlanContract`, and `#RelocationGuard`
- [X] T035 [US4] Add the thin `source-relocation-plan` wrapper only after the direct observational command is green in `profile/QuantResearch.ps1` for REQ-017 and REQ-018 using `#RelocationNonMutation` and `#RelocationPlanContract`
- [X] T036 [US4] Make `Reinitialize -Project All` recreate only missing/generated environments from each moved fixture lock and reverify every contained relative base and representative import for REQ-021 in `scripts/Set-QuantResearchEnvironmentState.ps1` using `#MovedRootRebuild`
- [X] T037 [US4] Run all relocation-plan fixtures and the disposable moved-root rebuild, verify no global kernel delta and no operation against real `C:\Users\mariu\Source` or `D:\Source`, and record the plan-only/deferred REQ-020 disposition in `specs/009-quant-research-environment/verification-log.md`

**Checkpoint**: Operators can evaluate relocation readiness, but this repository still cannot copy, rename, delete, or create the junction.

---

## Phase 7: Human Documentation, Routing, and Final Gates

**Purpose**: Publish direct human commands before AI routing, synchronize catalogs, and close traceability.

- [X] T038 Document the direct Test/Ensure/Reinitialize, overlay, notebook, and plan-only relocation commands, expected exits, examples, protected-content/credential boundary, and deferred junction warning for REQ-001, REQ-002, REQ-008, REQ-015, REQ-018, and REQ-020 in `docs/quant-research-environment.md`, `docs/Aliases.md`, and `docs/sample-outputs.md` using `#CommandContract`, `#OutputParity`, `#NotebookEntryPoint`, `#CredentialBoundary`, and `#RelocationPlanContract`
- [X] T039 Add the `quant-research-environment` snapshot capability only after T038 documents its human commands, routing setup/status/notebook/overlay/relocation operations to those commands for REQ-016 and REQ-022 in `config/capabilities.psd1` and `docs/capabilities/index.md` using `#CapabilityRouting` and `#FocusedBoundary`
- [X] T040 [P] Update module ownership, opt-in behavior, dependencies, generated-state scope, and deferred relocation boundaries for REQ-013, REQ-014, and REQ-022 in `docs/workstation-modules.md` and `docs/desired-state.md` using `#ReconciliationScope`, `#UserContentPreservation`, and `#FocusedBoundary`
- [X] T041 [P] Add the feature navigation, operator summary, and release note without credentials or workstation-expanded paths for REQ-015 and REQ-016 in `mkdocs.yml`, `README.md`, and `CHANGELOG.md` using `#CredentialBoundary` and `#CapabilityRouting`
- [X] T042 [P] Update the frozen workstation baseline inventory from 45 to 46 modules and 28 to 29 capabilities with `QuantResearchEnvironment` and `quant-research-environment` for REQ-016 and REQ-022 in `specs/001-workstation-baseline/spec.md` using `#CapabilityRouting` and `#FocusedBoundary`
- [X] T043 Replace practical manual mappings with the green focused selectors, retain a precise manual/deferred rationale only for REQ-020, and verify coverage for all 22 requirements in `specs/009-quant-research-environment/traceability.toml` and `specs/009-quant-research-environment/verification-log.md`
- [X] T044 Run the focused runner, Pester adapter, `ears-sdd validate --phase final`, `lint-powershell`, direct and Tricky human/JSON smoke tests, strict docs build, and `git diff --check`; record command, exit, and result evidence in `specs/009-quant-research-environment/verification-log.md`

---

## Dependencies and Execution Order

### Phase dependencies

Phase 1 establishes the safe harness. Phase 2's red configuration and routing contracts block production work. US1 is the MVP and establishes project resolution plus notebook execution. US2 depends only on the portable base relationship from US1. US3 extends the US1 status surface with full reconciliation and can begin after US1; its shared edits to `Set-QuantResearchEnvironmentState.ps1` must be serialized with US1. US4 planning depends on the portable configuration but not on overlay creation; T036 depends on US3 Reinitialize behavior. Documentation/routing and final gates follow all selected stories.

Within every story, the listed failing-test tasks must be run and observed red before the corresponding implementation tasks. A green test caused by pre-existing behavior must be recorded as brownfield characterization before refactoring.

### User story dependencies

| Story | Starts after | Independent delivery evidence |
|---|---|---|
| US1 (P1) | Phase 2 | Locked thesis Jupyter probe, imports, and zero kernel delta |
| US2 (P2) | US1 base relationship | Disposable overlay creation and unchanged existing project hashes |
| US3 (P3) | US1 status skeleton | Drift/repair/rebuild cases with protected-content preservation |
| US4 (P4) | Phase 2; T036 waits for US3 | Plan-only fixture matrix and separate disposable moved-root rebuild |

## Parallel Opportunities

T002 and T003 can run together. After Phase 2, T008/T009 test writing and the US4 relocation test design can be prepared in separate files only if the shared test runner is not edited concurrently; otherwise serialize those edits. Once US1 stabilizes the common resolver, US2's overlay script and US4's relocation-plan script are independent. T040, T041, and T042 touch separate documentation/specification files and can run in parallel after public behavior is stable.

## Parallel Execution Examples

### User Story 2 and User Story 4

```text
Task: T016-T017 implement and verify scripts/New-QuantResearchOverlay.ps1
Task: T033-T034 implement and verify scripts/Get-SourceRelocationPlan.ps1
```

Do not run T036 until US3's Reinitialize transaction is green.

### Cross-cutting publication

```text
Task: T040 update docs/workstation-modules.md and docs/desired-state.md
Task: T041 update mkdocs.yml, README.md, and CHANGELOG.md
Task: T042 update specs/001-workstation-baseline/spec.md
```

## Requirement Coverage

| Requirements | Preceding failing-test tasks | Implementation / verification tasks |
|---|---|---|
| REQ-001 | T006 | T010, T023, T027, T028, T038, T044 |
| REQ-002 | T020 | T023, T024, T027, T038, T044 |
| REQ-003, REQ-004 | T008 | T010, T013, T044 |
| REQ-005 | T008, T014 | T010, T016, T019, T044 |
| REQ-006, REQ-007 | T014 | T016 through T019, T044 |
| REQ-008, REQ-009 | T009 | T011 through T013, T038, T044 |
| REQ-010 | T021 | T025, T029, T044 |
| REQ-011 | T020 | T023, T024, T029, T044 |
| REQ-012 | T015, T022 | T017, T026, T029, T044 |
| REQ-013, REQ-014 | T022 | T025, T026, T029, T040, T044 |
| REQ-015 | T005 | T007, T025, T038, T041, T044 |
| REQ-016 | T006 | T028, T038, T039, T041, T042, T044 |
| REQ-017, REQ-018 | T030 | T033 through T035, T037, T038, T044 |
| REQ-019 | T031 | T034, T037, T044 |
| REQ-020 | T031 | T034, T037, T038, T043 (manual deferred execution remains justified) |
| REQ-021 | T032 | T036, T037, T044 |
| REQ-022 | T005, T006 | T007, T028, T039, T040, T042, T044 |

Coverage: 22 of 22 requirements have a preceding failing-test task or, for the deferred execution portion of REQ-020, a preceding executable boundary test plus an explicit retained manual rationale.

## Implementation Strategy

### MVP first

1. Complete Phase 1 and observe the Phase 2 red contracts.
2. Implement only US1.
3. Stop and run the independent thesis notebook/import/kernel test.
4. Use the workflow immediately if green; it needs neither overlay creation nor relocation planning.

### Incremental delivery

1. US1 provides the daily thesis workflow.
2. US2 adds repeatable experiment overlays without destabilizing US1.
3. US3 adds explicit maintenance and recovery while preserving research content.
4. US4 adds read-only relocation readiness without authorizing a move.
5. Publish docs and AI routing only after the direct human commands are green.

## Completion Conditions

- All 44 tasks use stable checklist IDs, exact file paths, and story labels only in user-story phases.
- Every behavior task names its requirements and selectors, and every production behavior follows an observed failing test.
- Each story meets its independent test without requiring a later story.
- `Test`, overlay default planning, and relocation planning remain observational.
- No task copies the real Source tree, creates a junction, registers a global kernel, commits credentials/data, or silently resolves a reviewed lock.
- Final traceability covers all 22 requirements, with REQ-020's future cutover behavior remaining explicitly deferred and manual.
