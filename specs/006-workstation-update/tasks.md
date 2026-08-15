# Tasks: Managed Workstation Update

**Input**: Design documents from `specs/006-workstation-update/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and
`quickstart.md`

**Tests**: Mandatory. Every mutating integration is exercised through synthetic command executors;
no test or CI task installs host, WSL, package, or container updates.

## Phase 1: Setup and traceability

**Purpose**: Establish the approved feature and executable test boundary.

- [x] T001 Create and validate `specs/006-workstation-update/spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/workstation-update-cli.md`, checklist, and initial `traceability.toml`
- [x] T002 Create the failing section boundary in `tests/Test-WorkstationUpdate.ps1` and observe the missing production files before implementation
- [x] T003 Add the Pester adapter in `tests/pester/WorkstationUpdate.Tests.ps1`, register it in `tests/Test-PowerShellTestingState.ps1`, and include the contract in `.specify/ears-sdd.toml`

---

## Phase 2: User Story 1 - Review one complete update plan (Priority: P1) 🎯 MVP

**Goal**: One plan-first human/JSON command resolves selectable update targets in deterministic
dependency order without invoking an updater.

**Independent Test**: Run `tests/Test-WorkstationUpdate.ps1 -Section CommandSurface`,
`PlanContract`, `OutputContract`, `TargetContract`, `DependencyContract`, `SafetyContract`, and
`DualShellContract` without `-Run`.

- [x] T004 [US1] Expand and observe failing command/profile/discovery and dual-shell assertions for REQ-001, REQ-024, and REQ-025 in `tests/Test-WorkstationUpdate.ps1#CommandSurface` and `#DualShellContract`
- [x] T005 [US1] Expand and observe failing static plan, explicit Run, target closure, graph validation, and prohibited-command assertions for REQ-002, REQ-004 through REQ-006, and REQ-021 in `tests/Test-WorkstationUpdate.ps1#PlanContract`, `#TargetContract`, `#DependencyContract`, and `#SafetyContract`
- [x] T006 [US1] Expand and observe failing bounded human/JSON schema and terminal-state assertions for REQ-003 and REQ-023 in `tests/Test-WorkstationUpdate.ps1#OutputContract`
- [x] T007 [US1] Implement the validated update target/stage catalog for REQ-004 and REQ-006 in `config/workstation-update.psd1` using selectors `#TargetContract` and `#DependencyContract`
- [x] T008 [US1] Implement plan-only selection, dependency resolution, human rendering, and bounded JSON for REQ-002 through REQ-006 and REQ-023 in `scripts/Invoke-WorkstationUpdate.ps1` using selectors `#PlanContract`, `#OutputContract`, `#TargetContract`, `#DependencyContract`, and `#SafetyContract`
- [x] T009 [US1] Add the `update` profile wrapper for REQ-001 and REQ-025 in `profile/Aliases.ps1`, then run all US1 selectors in Windows PowerShell 5.1 and PowerShell Core to green

---

## Phase 3: User Story 2 - Apply host and package updates (Priority: P1)

**Goal**: Explicit Run services Windows software updates, WinGet, Scoop, and WSL while preserving
drivers, pins, retained versions, active distributions, and reboot control.

**Independent Test**: Run the Windows, WinGet, Scoop, WSL, privilege, safety, dependency, and
synthetic execution selectors without invoking a real updater.

- [x] T010 [US2] Add and observe failing WUA software-only, accepted-EULA, no-driver, restart-report, and no-reboot assertions for REQ-007 and REQ-008 in `tests/Test-WorkstationUpdate.ps1#WindowsContract` and `#SafetyContract`
- [x] T011 [US2] Add and observe failing WinGet known/unpinned/no-force/no-op-code assertions for REQ-009 in `tests/Test-WorkstationUpdate.ps1#WinGetContract`
- [x] T012 [US2] Add and observe failing Scoop declared-state/core/bucket/app update and no-cleanup assertions for REQ-010 in `tests/Test-WorkstationUpdate.ps1#ScoopContract`
- [x] T013 [US2] Add and observe failing supported WSL update and no-shutdown assertions for REQ-011 in `tests/Test-WorkstationUpdate.ps1#WslContract` and `#SafetyContract`
- [x] T014 [US2] Add and observe failing explicit elevation, synthetic success/failure/restart, dependent-skip, and result assertions for REQ-005, REQ-008, REQ-018, REQ-022, and REQ-023 in `tests/Test-WorkstationUpdate.ps1#PrivilegeContract`, `#ExecutionContract`, and `#DependencyContract`
- [x] T015 [US2] Implement the focused software-only Windows Update wrapper for REQ-007, REQ-008, REQ-021, and REQ-022 in `scripts/Invoke-WindowsUpdate.ps1` using `#WindowsContract`, `#SafetyContract`, and `#PrivilegeContract`
- [x] T016 [US2] Implement WinGet, Scoop, WSL, explicit elevation, normalized no-op/restart/failure results, and dependent skipping for REQ-005, REQ-008 through REQ-011, REQ-018, REQ-021 through REQ-023 in `scripts/Invoke-WorkstationUpdate.ps1` using all US2 selectors

---

## Phase 4: User Story 3 - Update Linux and container environments (Priority: P1)

**Goal**: Both declared Debian distributions update independently, declared Homebrew instances
upgrade safely, and existing Docker/Podman pyinfra resources restore their separate boundaries.

**Independent Test**: Run Linux, Homebrew, container, privilege, dependency, safety, and synthetic
execution selectors with declared fake distribution identities.

- [x] T017 [US3] Add and observe failing declared-distribution-only APT, root-boundary, and identity-separation assertions for REQ-012 and REQ-013 in `tests/Test-WorkstationUpdate.ps1#LinuxContract`, `#PrivilegeContract`, and `#SafetyContract`
- [x] T018 [US3] Add and observe failing declared-instance-only Homebrew update/upgrade and release-pin assertions for REQ-014 and REQ-015 in `tests/Test-WorkstationUpdate.ps1#HomebrewContract`
- [x] T019 [US3] Add and observe failing existing rootful Docker/rootless Podman resource routing assertions for REQ-016 and REQ-017 in `tests/Test-WorkstationUpdate.ps1#ContainerContract`
- [x] T020 [US3] Implement declared Debian APT and Homebrew stage execution for REQ-012 through REQ-015, REQ-018, REQ-021, and REQ-022 in `scripts/Invoke-WorkstationUpdate.ps1` and `config/workstation-update.psd1` using `#LinuxContract`, `#HomebrewContract`, `#DependencyContract`, `#PrivilegeContract`, and `#SafetyContract`
- [x] T021 [US3] Implement existing Docker/Podman resource reconciliation for REQ-016 through REQ-018 in `scripts/Invoke-WorkstationUpdate.ps1` using `#ContainerContract`, `#DependencyContract`, and `#ExecutionContract`

---

## Phase 5: User Story 4 - Restore current-release workstation state (Priority: P1)

**Goal**: Final reconciliation reapplies and tests the current checkout's default non-destructive
state, including equivalent PowerShell profiles and stable environment variables.

**Independent Test**: Run reconciliation, output, safety, execution, and dual-shell selectors with
a synthetic `Apply-Workstation` executor.

- [x] T022 [US4] Add and observe failing current-VERSION, default Ensure/Test, no-destructive-module, remaining-drift, new-shell, and dual-profile assertions for REQ-019, REQ-020, REQ-021, REQ-023, and REQ-025 in `tests/Test-WorkstationUpdate.ps1#ReconciliationContract`, `#OutputContract`, `#SafetyContract`, `#ExecutionContract`, and `#DualShellContract`
- [x] T023 [US4] Implement final release-aware Ensure/Test reconciliation and summary behavior for REQ-018 through REQ-023 and REQ-025 in `scripts/Invoke-WorkstationUpdate.ps1` using all US4 selectors

---

## Phase 6: Documentation and final gates

**Purpose**: Make the public command discoverable and close every requirement with reproducible
evidence.

- [x] T024 Update capability routing and operator documentation for REQ-024 in `config/capabilities.psd1`, `README.md`, `docs/desired-state.md`, `docs/Aliases.md`, `docs/sample-outputs.md`, `docs/workstation-update.md`, `mkdocs.yml`, and `CHANGELOG.md` using `tests/Test-WorkstationUpdate.ps1#CommandSurface`
- [x] T025 Promote passing selectors in `specs/006-workstation-update/traceability.toml`, run `ears-sdd validate --phase final`, and record synthetic/dual-shell evidence in `specs/006-workstation-update/verification-log.md`
- [x] T026 Run the non-mutating quickstart plans, full update contracts, modern and compatibility Pester, `lint-powershell`, Tricky human/JSON smoke, strict MkDocs, skill validation, and `git diff --check`

## Dependencies and execution order

- Phase 1 blocks every user story.
- US1 provides the catalog, resolver, output, and explicit Run gate used by every later story.
- US2 and US3 depend on US1 but their focused executor tests and implementation are otherwise separable.
- US4 depends on all external updater stages because it owns the final reconciliation result.
- Documentation and final gates depend on all four stories.
- Within every story, failing tests precede implementation and trace promotion follows passing regression tests.

## Requirement coverage

| Requirements | Failing-test tasks | Implementation/verification tasks |
|---|---|---|
| REQ-001–REQ-006 | T004–T006 | T007–T009, T026 |
| REQ-007, REQ-008 | T010, T014 | T015, T016, T026 |
| REQ-009 | T011 | T016, T026 |
| REQ-010 | T012 | T016, T026 |
| REQ-011 | T013 | T016, T026 |
| REQ-012, REQ-013 | T017 | T020, T026 |
| REQ-014, REQ-015 | T018 | T020, T026 |
| REQ-016, REQ-017 | T019 | T021, T026 |
| REQ-018 | T014, T017–T019 | T016, T020, T021, T023 |
| REQ-019, REQ-020 | T022 | T023, T026 |
| REQ-021, REQ-022 | T005, T010, T013, T014, T017, T022 | T015, T016, T020, T023, T026 |
| REQ-023 | T006, T014, T022 | T008, T016, T023, T026 |
| REQ-024 | T004 | T009, T024, T026 |
| REQ-025 | T004, T022 | T009, T023, T026 |

Coverage: 25 of 25 requirements have preceding failing-test tasks and named implementation or verification tasks.

## Completion conditions

- All 26 tasks use stable checklist IDs and concrete paths.
- Every behavior task names requirements and selectors.
- Automated validation never invokes a real updater or privileged mutation.
- `update` remains a plan; only `update -Run` authorizes system changes.
