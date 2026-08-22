# Tasks: Brownfield Workstation Baseline

**Input**: Design documents from `specs/001-workstation-baseline/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and
`quickstart.md`

**Tests**: Mandatory. Each characterization test is written and observed failing before any
corresponding remediation. Existing behavior is changed only when its characterization evidence
shows a specification gap.

**Organization**: Tasks are grouped by independently testable user story. Requirement coverage and
test selectors are explicit on every behavior-changing task.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a separate file or independent verification area.
- **[Story]**: Maps the task to a user story in `spec.md`.
- Selectors use `tests/Test-WorkstationBaseline.ps1#<section>` for the dependency-free test runner.

## Phase 1: Setup

**Purpose**: Establish a human-runnable characterization boundary without changing workstation
state.

- [x] T001 Create the dependency-free test runner, section selector, assertion helpers, and clean failure reporting in `tests/Test-WorkstationBaseline.ps1`
- [x] T002 [P] Create the bounded manual evidence record with host, shell, command, result, and artifact fields in `specs/001-workstation-baseline/verification-log.md`
- [x] T003 [P] Add the baseline test command and expected output to `specs/001-workstation-baseline/quickstart.md`

---

## Phase 2: Foundational Traceability

**Purpose**: Make the future test suite part of the declared EARS/TDD and publication gate.

**Critical**: Complete this phase before changing any baseline behavior.

- [x] T004 Add a deliberately failing self-test for malformed catalog fixtures to `tests/Test-WorkstationBaseline.ps1#HarnessSelfTest`, then verify the runner returns nonzero before its fixture is corrected
- [x] T005 Make the harness self-test pass and add its human-readable invocation to `specs/001-workstation-baseline/quickstart.md`
- [x] T006 Add `pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1` to the reviewed `test_command` in `.specify/ears-sdd.toml` after T005 passes (REQ-037, REQ-039, REQ-040; selector `tests/Test-WorkstationBaseline.ps1#HarnessSelfTest`)

**Checkpoint**: The test boundary is independently runnable and the project gate declares it.

---

## Phase 3: User Story 1 - Inspect and Select Desired State (Priority: P1) — MVP

**Goal**: Characterize the complete module schema, dependency graph, focused selection, and plan
safety.

**Independent Test**: Run
`pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section Modules` and representative
`Apply-Workstation.ps1 -Plan` commands without elevation.

### Failing tests

- [x] T007 [US1] Add failing catalog membership, uniqueness, schema, and baseline-count assertions for REQ-001 and REQ-002 in `tests/Test-WorkstationBaseline.ps1#Modules`
- [x] T008 [US1] Add failing acyclic topological-order, dependency-closure, unrelated-module exclusion, and Sudo-precedence assertions for REQ-003, REQ-004, and REQ-009 in `tests/Test-WorkstationBaseline.ps1#ModulePlanning`
- [x] T009 [US1] Add failing plan non-dispatch, risk-metadata, default-selection, and Debloat-exclusion assertions for REQ-005 and REQ-011 in `tests/Test-WorkstationBaseline.ps1#PlanSafety`

### Conditional remediation and green pass

- [x] T010 [US1] Remediate only failing catalog or dependency behavior in `config/workstation-modules.psd1` and `Apply-Workstation.ps1` for REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-009, and REQ-011 using selectors `tests/Test-WorkstationBaseline.ps1#Modules`, `#ModulePlanning`, and `#PlanSafety`
- [x] T011 [US1] Run the three US1 selectors and the full, Contour, WindowsFeatures, and Debloat plans; record the passing output in `specs/001-workstation-baseline/verification-log.md`

**Checkpoint**: The complete module inventory and planning contract are automatically
characterized without workstation mutation.

---

## Phase 4: User Story 2 - Test and Apply State Safely (Priority: P1)

**Goal**: Characterize read-only modes and the explicit privilege, destructiveness, recovery,
restart, hardening, and removal boundaries.

**Independent Test**: Run
`pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section StateSafety`, then execute only
the reviewed Test/manual procedures applicable to the current host.

### Failing tests

- [x] T012 [US2] Add failing static assertions for Test/Ensure/Reinitialize mode declarations, explicit Sudo edges, destructive confirmation, and recovery sequencing for REQ-006, REQ-007, REQ-008, and REQ-010 in `tests/Test-WorkstationBaseline.ps1#StateSafety`
- [x] T013 [US2] Add failing Windows-feature graph, no-automatic-restart, separate-security-boundary, and no-managed-UAC assertions for REQ-014, REQ-015, REQ-016, and REQ-017 in `tests/Test-WorkstationBaseline.ps1#WindowsSafety`
- [x] T014 [US2] Add failing protected-package and pre-removal-snapshot assertions for REQ-018 and REQ-019 in `tests/Test-WorkstationBaseline.ps1#DebloatSafety`

### Conditional remediation and bounded verification

- [x] T015 [US2] Remediate only failing safety behavior in `Apply-Workstation.ps1`, `config/windows-features.psd1`, `config/hardening-profiles.psd1`, `config/debloat-profiles.psd1`, `scripts/Set-WindowsFeatureState.ps1`, `scripts/Set-HardeningState.ps1`, or `scripts/Set-DebloatState.ps1` for REQ-006 through REQ-010 and REQ-014 through REQ-019 using selectors `tests/Test-WorkstationBaseline.ps1#StateSafety`, `#WindowsSafety`, and `#DebloatSafety`
- [x] T016 [US2] Run the three US2 selectors and record only explicitly approved host-dependent Test/idempotence/recovery procedures in `specs/001-workstation-baseline/verification-log.md`

**Checkpoint**: Safe behavior is automated where static and read-only; high-impact behavior remains
bounded by a concrete evidence record.

---

## Phase 5: User Story 3 - Diagnose from Existing Evidence (Priority: P1)

**Goal**: Characterize complete capability routing, human/JSON output, evidence-first ordering, and
focused skill boundaries.

**Independent Test**: Run
`pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section Diagnostics`, then run Tricky
capability discovery in human and JSON forms.

### Failing tests

- [x] T017 [US3] Add failing capability membership, uniqueness, schema, inspection-command, and explicit-capture assertions for REQ-026 and REQ-027 in `tests/Test-WorkstationBaseline.ps1#Capabilities`
- [x] T018 [US3] Add failing Tricky human-output and parseable-JSON subprocess assertions for REQ-030 and REQ-031 in `tests/Test-WorkstationBaseline.ps1#TrickyOutput`
- [x] T019 [US3] Add failing focused-skill, existing-evidence-first, explicit-mutation, and profiler-route assertions for REQ-028, REQ-029, REQ-032, and REQ-033 in `tests/Test-WorkstationBaseline.ps1#DiagnosticSkills`

### Conditional remediation and green pass

- [x] T020 [US3] Remediate only failing routing or output behavior in `config/capabilities.psd1`, `scripts/Invoke-Tricky.ps1`, `scripts/Get-ProfilerStatus.ps1`, and the affected focused `.agents/skills/*/SKILL.md` files for REQ-026 through REQ-033 using selectors `tests/Test-WorkstationBaseline.ps1#Capabilities`, `#TrickyOutput`, and `#DiagnosticSkills`
- [x] T021 [US3] Run all US3 selectors plus Tricky human and JSON discovery and record passing evidence in `specs/001-workstation-baseline/verification-log.md`

**Checkpoint**: All 25 routes are characterized and no diagnostic skill hides state-changing
automation.

---

## Phase 6: User Story 4 - Use the Managed Developer Environment (Priority: P2)

**Goal**: Characterize shell, terminal, native-tool, Debian-local, isolated-environment, profile,
and released specification-tool boundaries.

**Independent Test**: Run
`pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section DeveloperEnvironment` and the
dual-shell Spec Kit resource Test commands.

### Failing tests

- [x] T022 [US4] Add failing dual-shell declaration and profile-surface assertions for REQ-012 and REQ-025 in `tests/Test-WorkstationBaseline.ps1#PowerShellRuntimes`
- [x] T023 [US4] Add failing Contour migration and graphics-gate assertions for REQ-020 and REQ-021 in `tests/Test-WorkstationBaseline.ps1#Contour`
- [x] T024 [US4] Add failing native-tool exclusion, Debian-local package, and isolated-environment assertions for REQ-022, REQ-023, and REQ-024 in `tests/Test-WorkstationBaseline.ps1#DeveloperTools`
- [x] T025 [US4] Add failing release version, hash, upstream dependency, and dual-shell resource assertions for REQ-038 in `tests/Test-WorkstationBaseline.ps1#SpecDrivenDevelopment`

### Conditional remediation and bounded verification

- [x] T026 [US4] Remediate only failing developer-environment contracts in `config/contour-terminal.psd1`, `scripts/Set-ContourTerminalState.ps1`, `config/native-text-tools.psd1`, `config/linux-homebrew.psd1`, `config/linux-automation.psd1`, `config/developer-tools.psd1`, `profile/`, `config/spec-driven-development.psd1`, or `scripts/Set-SpecDrivenDevelopmentState.ps1` for REQ-012 and REQ-020 through REQ-025 and REQ-038 using the corresponding US4 selectors
- [x] T027 [US4] Run all US4 selectors, both PowerShell runtime tests, and only explicitly approved Contour/WSL host checks; record results in `specs/001-workstation-baseline/verification-log.md`

**Checkpoint**: Developer-environment declarations are automated and hardware or distribution
state remains explicitly verified.

---

## Phase 7: User Story 5 - Discover and Evolve the Project (Priority: P2)

**Goal**: Characterize platform documentation, local-sample safety, command/document coupling,
publication gates, EARS traceability, TDD ordering, and SkillOpt restrictions.

**Independent Test**: Run
`pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section Governance`, all EARS phases,
and the publication commands.

### Failing tests

- [x] T028 [US5] Add failing Windows 11 Pro, local-sample/ignore, operator-content, and command-to-capability coupling assertions for REQ-013, REQ-034, REQ-035, and REQ-036 in `tests/Test-WorkstationBaseline.ps1#Documentation`
- [x] T029 [US5] Add failing publication-command declarations and executable smoke assertions for REQ-037 in `tests/Test-WorkstationBaseline.ps1#PublicationGates`
- [x] T030 [US5] Add failing traceability completeness and test-before-implementation task-order assertions for REQ-039 and REQ-040 in `tests/Test-WorkstationBaseline.ps1#SpecificationWorkflow`
- [x] T031 [US5] Add failing explicit-target, gating, staging, no-schedule, and explicit-adoption assertions for REQ-041 in `tests/Test-WorkstationBaseline.ps1#SkillOptSafety`

### Conditional remediation and green pass

- [x] T032 [US5] Remediate only failing governance contracts in `README.md`, `docs/`, `.gitignore`, `config/capabilities.psd1`, `.specify/ears-sdd.toml`, `specs/001-workstation-baseline/traceability.toml`, `specs/001-workstation-baseline/tasks.md`, `config/skillopt.psd1`, or `scripts/Invoke-SkillOpt.ps1` for REQ-013 and REQ-034 through REQ-041 using the corresponding US5 selectors
- [x] T033 [US5] Run all US5 selectors, all deterministic EARS phases, PowerShell lint, repository-skill validation, Tricky human/JSON smoke, and strict MkDocs; record passing evidence in `specs/001-workstation-baseline/verification-log.md`

**Checkpoint**: Contributors can discover, specify, test, review, and publish through one governed
human-readable workflow.

---

## Phase 8: Traceability Promotion and Final Review

**Purpose**: Replace brownfield manual entries with automated selectors only where execution
evidence now exists, without fabricating automation for unsafe host operations.

- [x] T034 Update each safely automated requirement from manual rationale to its passing selector in `specs/001-workstation-baseline/traceability.toml`
- [x] T035 [P] Retain and review concrete manual rationales for privileged, destructive, graphics, reboot, capture, attach, package-repair, and WSL-host requirements in `specs/001-workstation-baseline/traceability.toml`
- [x] T036 Run `ears-sdd validate --phase final`, the full `tests/Test-WorkstationBaseline.ps1`, and the quickstart sequence; record the final zero-finding result in `specs/001-workstation-baseline/verification-log.md`
- [x] T037 Review the frozen module and capability tables against their live catalogs, confirm drift, and update `specs/001-workstation-baseline/spec.md` only through the approved requirement change

## Phase 9: Go and released hash-tool adoption

- [x] T038 [US4] Add failing dual-shell official-package, environment, built-in toolchain, narrow-release, SHA-256, embedded-version, module, and capability assertions for REQ-042 and REQ-043 in `tests/Test-GoState.ps1` and `tests/Test-MalwareHashesState.ps1`
- [x] T039 [US4] Implement focused Go and MalwareHashes state resources, package declarations, module dependency order, and capability routes for REQ-042 and REQ-043
- [x] T040 [US4] Document Go's built-in compatible toolchain selection, MSI-owned GOROOT, the released hash command, focused plans, and representative state output for REQ-042 and REQ-043
- [x] T041 [US4] Run both resources under PowerShell 7 and Windows PowerShell 5.1, full workstation baseline tests, publication gates, and the final EARS validator
- [x] T042 Review the updated 40-module and 25-capability inventories against their live catalogs and record the migration result in `specs/001-workstation-baseline/verification-log.md`

## Phase 10: Staged PowerShell bootstrap and Windows Terminal default

**Goal**: Bootstrap from inbox Windows safely, preserve dual-shell profile parity, and make the
newest installed PowerShell Core the default Windows Terminal profile with shared appearance.

**Independent Test**: Run `pwsh -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section
BootstrapStages`, `-Section PowerShellRuntimes`, and `-Section WindowsTerminal`, then run the same
profile selector through Windows PowerShell 5.1.

- [x] T043 [US4] Amend the brownfield specification, plan, research, data model, CLI/Terminal contracts, quickstart, checklist, and trace placeholders for REQ-044 through REQ-051 in `specs/001-workstation-baseline/`
- [x] T044 [US4] Add the dependency-free harness, malformed-catalog self-test, failing stage-schema, forward-stage, stage-order, stage-barrier, and no-early-pwsh assertions for REQ-044 through REQ-047 in `tests/Test-WorkstationBaseline.ps1#HarnessSelfTest` and `#BootstrapStages`, plus `tests/pester/WorkstationBaseline.Tests.ps1`
- [x] T045 [US4] Add failing dual-runtime profile-load and equivalent public-surface assertions for REQ-012, REQ-025, and REQ-048 in `tests/Test-WorkstationBaseline.ps1#PowerShellRuntimes`
- [x] T046 [US4] Add failing synthetic-settings drift, observational Test, Core-default, retained-5.1, shared-appearance, backup, idempotence, and unrelated-setting preservation assertions for REQ-049 through REQ-051 in `tests/Test-WorkstationBaseline.ps1#WindowsTerminal`
- [x] T047 [US4] Implement declared Inbox/Core/Extended stages, per-module runtime metadata, stage validation/barriers, and lazy PowerShell 7 resolution for REQ-044 through REQ-047 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1` using `tests/Test-WorkstationBaseline.ps1#BootstrapStages`
- [x] T048 [US4] Implement the focused Windows Terminal package/settings module and merge-preserving human/JSON resource for REQ-049 through REQ-051 in `.config/windows-terminal.winget`, `config/windows-terminal.psd1`, `scripts/Set-WindowsTerminalState.ps1`, `config/workstation-modules.psd1`, and `Apply-Workstation.ps1` using `tests/Test-WorkstationBaseline.ps1#WindowsTerminal`
- [x] T049 [US4] Update the PowerShell environment capability route and operator documentation for REQ-025, REQ-035, REQ-036, and REQ-048 through REQ-051 in `config/capabilities.psd1`, `README.md`, `docs/desired-state.md`, `docs/workstation-modules.md`, `docs/Aliases.md`, and `docs/sample-outputs.md`
- [x] T050 Promote REQ-012, REQ-025, and REQ-044 through REQ-051 to their passing automated selectors and add the baseline command to `.specify/ears-sdd.toml` and `specs/001-workstation-baseline/traceability.toml`
- [x] T051 [US4] Run Test then Ensure for the focused `PowerShellProfile` and `WindowsTerminal` modules, verify both runtime profile smokes and the Terminal default locally, and record the non-privileged state result in `specs/001-workstation-baseline/verification-log.md`
- [x] T052 Run modern parallel Pester, the Windows PowerShell compatibility lane, PowerShell lint, Tricky human/JSON smoke, strict MkDocs, and the final EARS gate for REQ-037 and SC-006 through SC-009

**Checkpoint**: A fresh host can reach Core using only inbox tooling; both supported shells load the
managed profile; Windows Terminal defaults to Core without losing Windows PowerShell or unrelated
settings.

---

## Phase 11: Native mkdir and directory readability

- [x] T053 Add failing dual-runtime assertions for native `mkdir` precedence and foreground-only
  PowerShell directory styling in `tests/Test-WorkstationBaseline.ps1#PowerShellRuntimes` for REQ-052.
- [x] T054 Remove available native-command function shims and declare the PowerShell Core directory
  style in `profile/Config.ps1` for REQ-052.
- [x] T055 Update PowerShell capability triggers, operator documentation, traceability, and run the
  focused profile Test/Ensure/smoke sequence for REQ-035, REQ-036, and REQ-052.

---

## Phase 12: pnpm in the base developer package set

- [x] T056 Add failing exact-once, channel, ordering, and routing assertions in
  `tests/Test-WorkstationBaseline.ps1#StateSafety` for REQ-053.
- [x] T057 Add `pnpm.pnpm` beside Node.js LTS in `.config/configuration.winget` and update package
  documentation, capability routing, and the release note for REQ-035, REQ-036, and REQ-053.
- [x] T058 Promote traceability and run StateSafety, routing smoke, repository lint, strict docs,
  host Test/install/Test readback, and the final EARS gate for REQ-037 and REQ-053.

---

## Requirement Coverage Matrix

| Requirement | Test-first task | Remediation or verification task |
|---|---|---|
| REQ-001, REQ-002 | T007 | T010, T011 |
| REQ-003, REQ-004, REQ-009 | T008 | T010, T011 |
| REQ-005, REQ-011 | T009 | T010, T011 |
| REQ-006, REQ-007, REQ-008, REQ-010 | T012 | T015, T016 |
| REQ-014, REQ-015, REQ-016, REQ-017 | T013 | T015, T016 |
| REQ-018, REQ-019 | T014 | T015, T016 |
| REQ-026, REQ-027 | T017 | T020, T021 |
| REQ-030, REQ-031 | T018 | T020, T021 |
| REQ-028, REQ-029, REQ-032, REQ-033 | T019 | T020, T021 |
| REQ-012, REQ-025 | T022 | T026, T027 |
| REQ-020, REQ-021 | T023 | T026, T027 |
| REQ-022, REQ-023, REQ-024 | T024 | T026, T027 |
| REQ-038 | T025 | T026, T027 |
| REQ-013, REQ-034, REQ-035, REQ-036 | T028 | T032, T033 |
| REQ-037 | T029 | T032, T033 |
| REQ-039, REQ-040 | T030 | T032, T033 |
| REQ-041 | T031 | T032, T033 |
| REQ-042, REQ-043 | T038 | T039–T041 |
| REQ-044, REQ-045, REQ-046, REQ-047 | T044 | T047, T050–T052 |
| REQ-048 | T045 | T049–T052 |
| REQ-049, REQ-050, REQ-051 | T046 | T048–T052 |
| REQ-052 | T053 | T054–T055 |
| REQ-053 | T056 | T057–T058 |

Coverage: 53 of 53 requirements have a preceding test task and a named remediation or verification
task.

### Success-criterion coverage

| Success criterion | Evidence tasks |
|---|---|
| SC-001 | T007, T008, T011, T037, T042 |
| SC-002 | T017, T021, T037, T042 |
| SC-003 | T030, T033, T036 |
| SC-004 | T030, T033 |
| SC-005 | T028, T033 |
| SC-006 | T029, T033, T036 |
| SC-007 | T044, T047, T052 |
| SC-008 | T045, T051, T052 |
| SC-009 | T046, T048, T051, T052 |

## Dependencies and Execution Order

### Phase dependencies

- Phase 1 has no dependencies.
- Phase 2 depends on Phase 1 and blocks every user story.
- US1, US2, US3, and US4 can begin independently after Phase 2, although US2 benefits from the US1
  planner characterization.
- US5 depends on the task file and policy produced in Phases 1–2 but not on other story
  implementations.
- Phase 8 depends on all selected user stories and cannot promote trace mappings before tests pass.

### Within every story

1. Add the named failing characterization.
2. Run only that selector and observe a nonzero result for the intended gap.
3. Remediate the smallest failing contract, if any.
4. Run the selector to green and then run the story's independent test.
5. Record host-dependent evidence without silently authorizing mutation.

### Parallel opportunities

- T002 and T003 can run in parallel with test-runner setup.
- Catalog, diagnostics, developer-environment, and documentation test sections occupy separate
  functions and can be authored in parallel after T006.
- Manual verification records for distinct host boundaries can run independently when explicitly
  authorized.
- Tasks that edit `Apply-Workstation.ps1`, `config/capabilities.psd1`, or
  `tests/Test-WorkstationBaseline.ps1` must be serialized to avoid overlapping edits.

## Parallel Examples

```text
US1: T007 module schema tests and T008 dependency-order tests can be drafted independently, then
merged before T010.

US3: T017 capability schema tests and T019 focused-skill audits can proceed independently; T018
Tricky subprocess tests use a separate selector.

US4: T023 Contour contracts, T024 Debian/native-tool contracts, and T025 Spec Kit release contracts
can be drafted independently.
```

## Implementation Strategy

### MVP first

1. Complete Setup and Foundational Traceability.
2. Complete US1 to lock module planning and safe inspection.
3. Stop and run the US1 independent test before any desired-state behavior changes.

### Incremental delivery

1. Add US2 safety characterization.
2. Add US3 evidence routing and structured-output characterization.
3. Add US4 developer-environment characterization.
4. Add US5 governance and publication characterization.
5. Promote only proven automated trace mappings and finish the final gate.

## Completion Conditions

- All 58 tasks follow the checklist format with stable IDs and concrete paths.
- Every behavior-changing task names its requirements and selectors.
- Every requirement is covered by a preceding failing-test task.
- Manual verification remains only where normal automated execution would violate a host or safety
  boundary.
- `ears-sdd validate --phase tasks` and `ears-sdd validate --phase final` report zero findings.
