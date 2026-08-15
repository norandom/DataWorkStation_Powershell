# Tasks: Migrate Debian-MW to Podman

**Input**: Design documents from `specs/003-migrate-podman-mw/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and
`traceability.toml`

**Tests**: Mandatory. Each behavior group starts with a failing test task and ends with a passing
test/refactor task. Runtime mutation and image building remain explicit late-stage validation tasks.

**Organization**: Tasks are grouped by independently testable user story and retain the public
malware workflow while replacing only the Debian-MW runtime.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes different files and has no incomplete dependency.
- **[Story]**: Maps the task to its user story from `spec.md`.
- Every behavior-changing task names its EARS coverage and automated selector.

## Phase 1: Setup and baseline

**Purpose**: Confirm the active design and current regression baseline before changing behavior.

- [X] T001 Run the plan gate and current affected characterization tests for `specs/003-migrate-podman-mw/traceability.toml`, `tests/Test-RootlessDockerState.ps1`, `tests/Test-MalwareAnalysis.ps1`, and `tests/Test-MalwareContainerAnalysis.ps1`; record any pre-existing failure before edits
- [X] T002 Verify `.gitignore` and `.dockerignore` already exclude `.venv/`, generated malware evidence, local environment selections, and build-only context data required by `specs/003-migrate-podman-mw/plan.md`

---

## Phase 2: User Story 1 - Inspect and migrate safely (Priority: P1) 🎯 MVP

**Goal**: Provide observational state/plan output, install and validate local rootless Podman first,
retire Docker only after that gate, and isolate legacy-data deletion.

**Independent Test**: Synthetic absent, Docker-only, Podman-ready, wrong-boundary, failed-gate,
partial-retirement, and retained-data records prove safe order without changing Debian-MW.

### Tests for User Story 1

- [X] T003 [US1] Add and run failing `#Inspection`, `#PodmanState`, `#Boundary`, `#MigrationOrder`, and `#ModuleContract` assertions for REQ-001–REQ-006, REQ-019–REQ-020, and REQ-025 in `tests/Test-RootlessDockerState.ps1`

### Implementation for User Story 1

- [X] T004 [US1] Define Debian Podman packages, local/rootless checks, retained Docker paths, and exact migration stages for REQ-001–REQ-006 and REQ-019–REQ-020 in `config/rootless-podman.psd1`, verified by `tests/Test-RootlessDockerState.ps1#Inspection` and `#PodmanState`
- [X] T005 [US1] Implement Podman-first provisioning and no-service rootless configuration for REQ-002–REQ-005 in `linux/rootless_podman.py`, verified by `tests/Test-RootlessDockerState.ps1#PodmanState`
- [X] T006 [US1] Implement post-readiness Docker service/package/repository retirement without data deletion for REQ-006 and REQ-019–REQ-020 in `linux/retire_rootless_docker.py`, verified by `tests/Test-RootlessDockerState.ps1#MigrationOrder`
- [X] T007 [US1] Implement bounded human/JSON Test and staged Ensure orchestration for REQ-001–REQ-005 and REQ-019–REQ-020 in `scripts/Set-RootlessPodmanState.ps1`, verified by `tests/Test-RootlessDockerState.ps1#Inspection`, `#PodmanState`, `#Boundary`, and `#MigrationOrder`
- [X] T008 [US1] Replace `RootlessDocker` with dependency-safe `RootlessPodman` routing for REQ-025 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, verified by `tests/Test-RootlessDockerState.ps1#ModuleContract`
- [X] T009 [US1] Remove superseded runtime declarations for REQ-019 in `config/rootless-docker.psd1`, `linux/rootless_docker.py`, and `scripts/Set-RootlessDockerState.ps1`, verified by `tests/Test-RootlessDockerState.ps1#MigrationOrder`
- [X] T010 [US1] Run `tests/Test-RootlessDockerState.ps1` in PowerShell 7 and Windows PowerShell 5.1, refactor the state boundary if needed, and confirm `#Inspection`, `#PodmanState`, `#Boundary`, `#MigrationOrder`, and `#ModuleContract` pass for REQ-001–REQ-006, REQ-019–REQ-020, and REQ-025

### Separate destructive cleanup

- [X] T011 [US1] Add and run failing `#LegacyCleanup` path-resolution, ownership, symlink, broad-target, dependency, and confirmation assertions for REQ-021 in `tests/Test-RootlessDockerState.ps1`
- [X] T012 [US1] Implement observational retained-data inspection and exact-path destructive cleanup for REQ-021 in `scripts/Remove-LegacyDockerMwState.ps1`, verified by `tests/Test-RootlessDockerState.ps1#LegacyCleanup`
- [X] T013 [US1] Add the non-default destructive `LegacyDockerCleanup` module and routing for REQ-021 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, verified by `tests/Test-RootlessDockerState.ps1#LegacyCleanup`
- [X] T014 [US1] Re-run `tests/Test-RootlessDockerState.ps1` in both PowerShell runtimes and confirm `#LegacyCleanup` passes without deleting any live data for REQ-021

**Checkpoint**: RootlessPodman and cleanup contracts are independently testable with synthetic
state. No live Debian-MW state has changed.

---

## Phase 3: User Story 2 - Run bounded static analysis (Priority: P1)

**Goal**: Switch the gated static parser invocation to local rootless Podman without changing its
isolation or permitting runtime repair.

**Independent Test**: Synthetic Podman information and exact argument arrays pass only when local,
rootless, socketless, networkless, bounded, and case-scoped; all unsafe variants fail before run.

### Tests for User Story 2

- [X] T015 [US2] Add and run failing Podman-local, rootful, remote, API-service, unsafe-argument, and exact-mount assertions for REQ-007–REQ-012 in `tests/Test-MalwareAnalysis.ps1#RootlessContainer` and `tests/Test-MalwareContainerAnalysis.ps1#Planning`
- [X] T016 [P] [US2] Add and run a failing static-only backend regression for REQ-028 in `tests/Test-MalwareAnalysis.ps1#SandboxSafety` and `tests/Test-MalwareContainerAnalysis.ps1#Runner`

### Implementation for User Story 2

- [X] T017 [US2] Generalize the isolation gate to bounded Podman JSON, local/rootless/service checks, and unchanged unsafe-argument refusal for REQ-008–REQ-011 in `scripts/Test-MalwareContainerIsolation.ps1`, verified by `tests/Test-MalwareAnalysis.ps1#RootlessContainer`
- [X] T018 [US2] Generate, inspect, run, time-bound, and clean up only Podman containers in Debian-MW for REQ-007–REQ-012 and REQ-028 in `scripts/Invoke-MalwareContainerAnalysis.ps1`, verified by `tests/Test-MalwareContainerAnalysis.ps1#Planning` and `#Runner`
- [X] T019 [US2] Run `tests/Test-MalwareAnalysis.ps1 -Section RootlessContainer`, `tests/Test-MalwareAnalysis.ps1 -Section SandboxSafety`, `tests/Test-MalwareContainerAnalysis.ps1 -Section Planning`, and `tests/Test-MalwareContainerAnalysis.ps1 -Section Runner`; refactor and confirm REQ-007–REQ-012 and REQ-028 pass

**Checkpoint**: Static analysis plans and gates are Podman-native and remain non-executing under
test. Windows Sandbox is still the sole dynamic-execution backend.

---

## Phase 4: User Story 3 - Keep the human analysis interface stable (Priority: P2)

**Goal**: Preserve high-level human/JSON contracts, remove engine-shaped aliases, and route direct
diagnosis through generic `wsl-mw podman`.

**Independent Test**: Command discovery and source contracts show all supported malware commands,
no Docker/Podman-MW or Compose alias, correct capability routes, stable result fields, and nonzero
gate failures.

### Tests for User Story 3

- [X] T020 [US3] Add and run failing high-level compatibility, generic low-level command, removed-alias, capability, and documentation assertions for REQ-016–REQ-018 and REQ-026 in `tests/Test-MalwareAnalysis.ps1#Interfaces` and `tests/Test-RootlessDockerState.ps1#CommandSurface` and `#Documentation`

### Implementation for User Story 3

- [X] T021 [US3] Remove `docker-mw` and malware Compose wrappers while retaining generic `wsl-mw` for REQ-017–REQ-018 in `profile/Aliases.ps1`, verified by `tests/Test-RootlessDockerState.ps1#CommandSurface`
- [X] T022 [US3] Replace Docker-MW state and inspection routes with human and JSON Podman commands for REQ-016–REQ-018 and REQ-026 in `config/capabilities.psd1`, verified by `tests/Test-MalwareAnalysis.ps1#Interfaces` and `tests/Test-RootlessDockerState.ps1#CommandSurface`
- [X] T023 [US3] Align the focused malware skill with the stable high-level commands and generic low-level Podman boundary for REQ-016–REQ-018 and REQ-026 in `.agents/skills/is-this-malware/SKILL.md`, verified by `tests/Test-RootlessDockerState.ps1#Documentation`
- [X] T024 [US3] Run `tests/Test-MalwareAnalysis.ps1 -Section Interfaces` and `tests/Test-RootlessDockerState.ps1`; refactor and confirm REQ-016–REQ-018 and REQ-026 pass

**Checkpoint**: Operators use malware workflow commands, while engine-specific convenience commands
are absent.

---

## Phase 5: User Story 4 - Rebuild and compare the OCI image (Priority: P2)

**Goal**: Inspect/build the parser image in Podman's store and make backend identity part of case
compatibility without rewriting historical evidence.

**Independent Test**: Synthetic absent/matching/stale images and Docker/Podman case pairs prove
explicit rebuild, complete inventory, immutable history, and incompatible cross-runtime comparison.

### Tests for User Story 4

- [X] T025 [US4] Add and run failing Podman image inspection/build/no-import assertions for REQ-013–REQ-015 in `tests/Test-MalwareContainerAnalysis.ps1#ImageContract`
- [X] T026 [P] [US4] Add and run failing historical Docker-read, runtime-identity, cross-runtime incompatibility, and bounded-evidence assertions for REQ-022–REQ-024 in `tests/Test-MalwareContainerAnalysis.ps1#Differential` and `#EvidenceBoundary`

### Implementation for User Story 4

- [X] T027 [US4] Switch observational image inspection and explicit reviewed-source build to Podman's local store for REQ-013–REQ-015 in `scripts/Set-MalwareContainerImageState.ps1`, verified by `tests/Test-MalwareContainerAnalysis.ps1#ImageContract`
- [X] T028 [US4] Record Podman runtime name/version in new cases and require runtime compatibility without mutating historical manifests for REQ-022–REQ-024 in `scripts/Invoke-MalwareContainerAnalysis.ps1` and `scripts/Compare-MalwareEvidence.ps1`, verified by `tests/Test-MalwareContainerAnalysis.ps1#Differential` and `#EvidenceBoundary`
- [X] T029 [US4] Run `tests/Test-MalwareContainerAnalysis.ps1 -Section ImageContract`, `-Section Differential`, and `-Section EvidenceBoundary`; refactor and confirm REQ-013–REQ-015 and REQ-022–REQ-024 pass

**Checkpoint**: Podman image state and evidence compatibility are complete without a networked build
or live parser run.

---

## Phase 6: Documentation and cross-feature alignment

**Purpose**: Replace Docker-specific Debian-MW statements everywhere while preserving historical
feature context and explicit state-change guidance.

- [X] T030 Update runtime, module, alias, attack-surface, migration, and cleanup documentation plus human/JSON samples for REQ-026 in `README.md`, `docs/desired-state.md`, `docs/workstation-modules.md`, `docs/Aliases.md`, `docs/malware-analysis.md`, and `docs/sample-outputs.md`, verified by `tests/Test-RootlessDockerState.ps1#Documentation`
- [X] T031 Cross-link feature 003 as superseding the Debian-MW Docker assumptions without rewriting completed history for REQ-026 in `specs/002-is-this-malware/spec.md`, `specs/002-is-this-malware/research.md`, `specs/002-is-this-malware/plan.md`, and `specs/002-is-this-malware/quickstart.md`, verified by `tests/Test-RootlessDockerState.ps1#Documentation`
- [X] T032 Update the feature status and final verification mappings after implementation for REQ-026–REQ-027 in `specs/003-migrate-podman-mw/spec.md`, `specs/003-migrate-podman-mw/traceability.toml`, and `specs/003-migrate-podman-mw/tasks.md`, verified by the EARS final gate

---

## Phase 7: Repository validation

**Purpose**: Complete the mandatory non-mutating quality gates before touching live Debian-MW.

- [X] T033 Run `tests/Test-RootlessDockerState.ps1`, affected malware tests, and module plan tests in PowerShell 7 for REQ-001–REQ-028 using selectors from `specs/003-migrate-podman-mw/traceability.toml`
- [X] T034 Run the supported state and affected malware contract tests in Windows PowerShell 5.1 for REQ-001, REQ-016, REQ-021, and REQ-027 using selectors from `specs/003-migrate-podman-mw/traceability.toml`
- [X] T035 Run `lint-python` and `tests/Test-PythonLint.ps1` against `linux/rootless_podman.py`, `linux/retire_rootless_docker.py`, and existing malware helpers for REQ-027
- [X] T036 Run `lint-powershell` across changed PowerShell files for REQ-027
- [X] T037 Run `tricky capabilities` and `tricky capabilities -Json` smoke tests against `config/capabilities.psd1` for REQ-016 and REQ-026
- [X] T038 Run `uv run --group docs mkdocs build --strict` against `mkdocs.yml` and updated `docs/` for REQ-026–REQ-027
- [X] T039 Run `ears-sdd validate --phase final` against `specs/003-migrate-podman-mw/` and repair only specification, task, traceability, test, or real implementation findings for REQ-027

---

## Phase 8: Explicit live migration and benign validation

**Purpose**: Apply only after repository gates pass and the operator reviews the exact impact.

- [X] T040 Run observational `./Apply-Workstation.ps1 -Mode Test -Module RootlessPodman -Plan` and `scripts/Set-RootlessPodmanState.ps1 -Mode Test -Json`; review Debian-MW package/service changes and retained paths for REQ-001 and REQ-025
- [X] T041 After explicit operator approval, run `./Apply-Workstation.ps1 -Mode Ensure -Module RootlessPodman`; verify Podman is local/rootless/socketless, Docker runtime state is retired, and legacy data remains for REQ-002–REQ-006 and REQ-019–REQ-020
- [X] T042 After explicit approval for a networked large build, run `scripts/Set-MalwareContainerImageState.ps1 -Mode Ensure` and repository-owned benign Office/PDF/binary fixture cases for REQ-007–REQ-015, REQ-022–REQ-024, and REQ-028; keep generated evidence ignored
- [X] T043 Run `./Apply-Workstation.ps1 -Mode Test -Module LegacyDockerCleanup -Plan` and retain legacy Docker data unless the operator separately selects `Ensure -ConfirmDestructive` for REQ-021

---

## Dependencies & Execution Order

### Phase dependencies

- Phase 1 establishes the baseline.
- User Story 1 provides the runtime state contract and must finish before live execution work.
- User Story 2 depends on US1's runtime information shape but is independently testable with
  synthetic input.
- User Story 3 can proceed after US1's final command names are fixed.
- User Story 4 depends on US2's runtime identity fields and run path.
- Documentation depends on all public names and behaviors being stable.
- Repository validation depends on all code and documentation tasks.
- Live migration depends on every repository gate; image build depends on successful migration.
- Legacy cleanup never blocks runtime or image readiness and remains separately optional.

### User story dependencies

```text
US1 Runtime migration ──┬──> US2 Static execution ──> US4 Image and evidence
                       └──> US3 Stable interface
```

### Within each user story

- Failing tests precede implementation.
- Shared state/config precedes orchestration and routing.
- Implementations precede the story's passing-test/refactor checkpoint.
- No live package, service, image, container, or cleanup operation occurs during story tests.

### Parallel opportunities

- T016 can proceed alongside the main US2 isolation test because it touches separate test sections.
- T026 can proceed alongside T025 because it covers evidence rather than image state.
- After US1, US2 and US3 can be developed independently if different files are coordinated.
- Documentation files can be divided after command names stabilize, but final terminology review is
  sequential.

## Parallel example: User Story 2

```text
Task: "Add failing Podman isolation and planning tests in the RootlessContainer and Planning selectors"
Task: "Add the independent Windows Sandbox static-only regression in SandboxSafety and Runner"
```

## Implementation Strategy

### MVP first

1. Complete baseline tasks.
2. Complete US1 synthetic state, migration-order, DSL, and cleanup contracts.
3. Stop and validate US1 without applying the migration.
4. Continue only when Podman-first rollback behavior is demonstrably correct.

### Incremental delivery

1. Runtime state and migration safety.
2. Podman-native static planning and gating.
3. Stable operator commands and removed aliases.
4. Podman image and evidence compatibility.
5. Documentation and repository gates.
6. Explicit live migration, explicit image build, and benign validation.

## Notes

- `[P]` tasks change different files or independent test selectors.
- Requirement IDs belong in tests and specification artifacts, never production source.
- `Test` and `-Plan` are observational.
- T041 and T042 are state-changing and require explicit operator approval when reached.
- T043 does not authorize destructive cleanup; the default outcome is retained legacy data.
