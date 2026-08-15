# Tasks: PowerShell Test Framework

**Input**: Design documents from `specs/004-powershell-testing/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and
`traceability.toml`

**Tests**: Mandatory. Contract tests precede each implementation slice. Framework installation and
live suite execution remain explicit late-stage tasks.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a different file and has no incomplete dependency.
- **[Story]**: Maps to one independently testable user story.

## Phase 1: Setup and red contracts

- [X] T001 Record the installed Pester and PowerShell runtime baseline and official parallel-execution constraints in `specs/004-powershell-testing/research.md`
- [X] T002 Add and run failing state, runner, JSON, failure, parallel, compatibility, adapter, and command-surface contracts for REQ-001–REQ-014 in `tests/Test-PowerShellTestingState.ps1`
- [X] T003 Add standard discoverable adapter files for REQ-001, REQ-006, REQ-009, and REQ-013 in `tests/pester/RootlessPodman.Tests.ps1`, `tests/pester/MalwareAnalysis.Tests.ps1`, `tests/pester/MalwareContainerAnalysis.Tests.ps1`, and `tests/pester/PowerShellTesting.Exclusive.Tests.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#Adapters` and `#ParallelContract`

---

## Phase 2: User Story 1 - One aggregate test command (Priority: P1) 🎯 MVP

**Goal**: Discover standard files, run one framework invocation, report human/JSON results, and
return reliable failure status without dependency repair.

**Independent Test**: Synthetic passing/failing files prove discovery, aggregation, bounded output,
and process exit behavior.

- [X] T004 [US1] Define the pinned framework release, result bounds, default paths, and command defaults for REQ-001–REQ-004 and REQ-012 in `config/pester.psd1`, verified by `tests/Test-PowerShellTestingState.ps1#StateContract` and `#RunnerContract`
- [X] T005 [US1] Implement exact-version import, one Pester invocation, human output, bounded JSON summary, and failure exit behavior for REQ-001–REQ-004 and REQ-012 in `scripts/Invoke-PowerShellTests.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#RunnerContract`, `#JsonContract`, and `#FailureContract`
- [X] T006 [US1] Run synthetic passing and failing `*.Tests.ps1` inputs through `scripts/Invoke-PowerShellTests.ps1`; confirm REQ-001–REQ-004 and REQ-012 and refactor without installing dependencies

**Checkpoint**: One framework command has deterministic human, JSON, and failure contracts.

---

## Phase 3: User Story 2 - Safe parallel execution (Priority: P1)

**Goal**: Run eligible files concurrently under PowerShell 7.4+ with bounded throttle and keep
exclusive files sequential.

**Independent Test**: Timed synthetic files demonstrate overlap, finite concurrency, and exclusive
execution outside the concurrent batch.

- [X] T007 [US2] Implement runtime eligibility, bounded `Run.Parallel`, `ParallelThrottleLimit`, and fallback reporting for REQ-005 and REQ-007 in `scripts/Invoke-PowerShellTests.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#ParallelContract`
- [X] T008 [US2] Enforce and document `#pester:no-parallel` for exclusive/live-state files for REQ-006 in `scripts/Invoke-PowerShellTests.ps1` and `tests/pester/PowerShellTesting.Exclusive.Tests.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#ParallelContract`
- [X] T009 [US2] Run bounded timed synthetic files through the modern lane and confirm REQ-005–REQ-007 without overlapping the exclusive file

**Checkpoint**: Modern file-level concurrency is observable, bounded, and safe by declaration.

---

## Phase 4: User Story 3 - Windows PowerShell compatibility (Priority: P2)

**Goal**: Execute compatible adapters sequentially under Windows PowerShell 5.1 and account for
incompatible tests explicitly.

**Independent Test**: The compatibility option dispatches to `powershell.exe`, discovers the
compatible files, remains sequential, and aggregates failures.

- [X] T010 [US3] Implement compatibility dispatch, sequential configuration, runtime accounting, and explicit skip/exclusion reporting for REQ-007–REQ-009 in `scripts/Invoke-PowerShellTests.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#CompatibilityContract`
- [X] T011 [US3] Run the migrated adapter suite through the Windows PowerShell lane and confirm REQ-008–REQ-009 with no ambiguous discovery omissions

**Checkpoint**: The same pinned framework and adapters validate declared 5.1 behavior sequentially.

---

## Phase 5: User Story 4 - Desired state and command surface (Priority: P2)

**Goal**: Inspect or explicitly install the exact framework version and expose one stable human
command through the DSL and capability catalog.

**Independent Test**: Synthetic absent/correct inventories prove observational Test, exact Ensure,
dependency order, aliases, and capability routing.

- [X] T012 [US4] Implement observational human/JSON state and explicit exact-version per-user Ensure for REQ-010–REQ-012 in `scripts/Set-PesterState.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#StateContract`
- [X] T013 [US4] Add default dependency-safe `PowerShellTesting` routing for REQ-010–REQ-011 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, verified by `tests/Test-PowerShellTestingState.ps1#CommandSurface`
- [X] T014 [US4] Add `test-powershell` and capability routes for REQ-014 in `profile/Aliases.ps1` and `config/capabilities.psd1`, verified by `tests/Test-PowerShellTestingState.ps1#CommandSurface`
- [X] T015 [US4] Run `tests/Test-PowerShellTestingState.ps1` in PowerShell 7 and Windows PowerShell 5.1 and confirm REQ-010–REQ-014

**Checkpoint**: Framework state and execution remain separate, human-readable commands.

---

## Phase 6: Documentation and validation

- [X] T016 Update installation, runner, parallel-safety, compatibility, and sample-output documentation for REQ-002–REQ-003, REQ-005–REQ-009, and REQ-014 in `README.md`, `docs/workstation-modules.md`, `docs/Aliases.md`, `docs/desired-state.md`, and `docs/sample-outputs.md`
- [X] T017 Run the migrated `tests/pester/*.Tests.ps1` suite through the modern lane for REQ-001–REQ-007 and REQ-013
- [X] T018 Run the migrated compatible suite through `test-powershell -Compatibility` for REQ-008–REQ-009 and REQ-013
- [X] T019 Run `lint-powershell`, Tricky human/JSON smoke tests, and `uv run --group docs mkdocs build --strict` for REQ-014
- [X] T020 Run `ears-sdd validate --phase final` for REQ-001–REQ-014 and update `specs/004-powershell-testing/spec.md`, `traceability.toml`, and `tasks.md` to completed status

---

## Phase 7: Explicit local installation

- [X] T021 Run observational `./Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan` and `scripts/Set-PesterState.ps1 -Mode Test -Json` for REQ-010–REQ-011
- [X] T022 After explicit operator approval, run `./Apply-Workstation.ps1 -Mode Ensure -Module PowerShellTesting` and verify both runtimes import Pester 6.1.0 for REQ-011

## Dependencies & Execution Order

- Red contracts precede all implementation.
- US1 provides the runner used by the parallel and compatibility stories.
- US2 and US3 both depend on US1 but are otherwise independently testable.
- US4 can be implemented after the config shape from US1 is stable.
- Documentation and repository gates depend on every story.
- Explicit installation happens only after non-mutating gates and operator review.

```text
US1 aggregate runner ──┬──> US2 parallel lane
                      └──> US3 compatibility lane
US1 config ───────────────> US4 desired state and commands
```

## Implementation Strategy

1. Deliver the aggregate framework command without parallelism.
2. Add bounded modern-runtime parallelism and exclusive-file policy.
3. Add the sequential compatibility dispatch.
4. Add desired state, routing, documentation, and full gates.
5. Install the pinned module explicitly and resume the Podman migration gates through the new runner.

## Notes

- Tests remain file-parallel only; assertions within one file are sequential.
- Existing section runners remain the source of detailed traceability during gradual migration.
- Pester parallel mode is experimental and is never enabled on Windows PowerShell 5.1.
- Test execution never authorizes package installation or workstation mutation.
