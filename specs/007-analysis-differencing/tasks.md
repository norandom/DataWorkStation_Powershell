# Tasks: General Sandbox and Binary Differencing

**Input**: Design documents from `specs/007-analysis-differencing/`

**Tests**: Mandatory and written before each behavior change.

## Phase 1: Specification and test foundation

- [x] T001 Create EARS specification, research, plan, data model, CLI contract, quickstart, checklist, and traceability in `specs/007-analysis-differencing/`
- [x] T002 Add failing general behavior, binary planning, graph-schema, query-schema, hostile-evidence, interface, compatibility, and documentation selectors for REQ-001 through REQ-022 in `tests/Test-AnalysisDifferencing.ps1`
- [x] T003 Add the dual-runtime Pester adapter for REQ-022 in `tests/pester/AnalysisDifferencing.Tests.ps1`

## Phase 2: User Story 1 - General Sandbox behavior (Priority: P1)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-AnalysisDifferencing.ps1 -Section Behavior`

- [x] T004 [US1] Implement `sandbox-behavior-control`, `sandbox-behavior-target`, and `sandbox-behavior-diff` as public wrappers over the existing engine for REQ-001 through REQ-006 in `profile/Aliases.ps1` using selectors `#BehaviorInterfaces`, `#BehaviorPlanning`, `#BehaviorSafety`, and `#BehaviorDifferential`
- [x] T005 [US1] Route the general behavior commands for REQ-001 and REQ-019 in `config/capabilities.psd1` using selector `#BehaviorInterfaces`

## Phase 3: User Story 2 - Graph-based binary comparison (Priority: P1)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-AnalysisDifferencing.ps1 -Section BinaryGraph`

- [x] T006 [US2] Add pinned BinExport and BinDiff inventory, build inputs, image checks, and stale-image behavior for REQ-009 through REQ-012 in `config/malware-container.psd1`, `linux/malware-analysis/tool-inventory.json`, and `linux/malware-analysis/Dockerfile` using selectors `#GraphArtifacts` and `#GraphSafety`
- [x] T007 [US2] Implement two-input read-only rootless container planning and explicit run confirmation for REQ-007 through REQ-008 in `scripts/Invoke-BinaryDiffAnalysis.ps1` using selectors `#BinaryPlanning` and `#BinaryIsolation`
- [x] T008 [US2] Implement bounded Ghidra graph export, BinDiff matching, immutable result retention, and explicit failure states for REQ-009 through REQ-013 and REQ-016 in `linux/malware-analysis/entrypoint.py` using selectors `#GraphArtifacts`, `#GraphSafety`, `#GraphSchema`, and `#BinaryReporting`

## Phase 4: User Story 3 - Query static evidence (Priority: P2)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-AnalysisDifferencing.ps1 -Section Query`

- [x] T009 [US3] Implement bounded line-oriented Ghidra function, instruction, graph, call, and decompilation export for REQ-014 and REQ-016 in `scripts/ExportGhidraAnalysis.java` using selector `#QuerySchema`
- [x] T010 [US3] Implement isolated validation and `binary-analysis.sqlite` creation without altering `.BinDiff` for REQ-014 through REQ-017 in `linux/malware-analysis/entrypoint.py` and `linux/malware-analysis/evidence_ingest.py` using selectors `#QuerySchema` and `#EvidenceBoundary`
- [x] T011 [US3] Implement bounded human/JSON binary-diff reports and `binary-diff`/`binary-diff-report` commands for REQ-011, REQ-016 through REQ-018, and REQ-022 in `scripts/Invoke-BinaryDiffAnalysis.ps1` and `profile/Aliases.ps1` using selectors `#BinaryReporting`, `#Interfaces`, and `#Compatibility`

## Phase 5: User Story 4 - Static-analysis case guidance (Priority: P2)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-AnalysisDifferencing.ps1 -Section Documentation`

- [x] T012 [US4] Add the case-selection guide, graph-versus-sidecar boundary, artifact descriptions, queries, partial-result interpretation, and attack surface for REQ-020 through REQ-021 in `docs/analysis-differencing.md` and `docs/malware-analysis.md` using selector `#Documentation`
- [x] T013 [US4] Add command reference, navigation, sample output, README summary, and focused-skill workflow for REQ-019 through REQ-021 in `docs/Aliases.md`, `docs/index.md`, `docs/sample-outputs.md`, `mkdocs.yml`, `README.md`, and `.agents/skills/is-this-malware/SKILL.md` using selectors `#Interfaces` and `#Documentation`

## Phase 6: Validation

- [x] T014 Run the focused harness in PowerShell 5.1 and PowerShell Core, Pester in both runtimes, Python lint, and existing malware regression suites for REQ-001 through REQ-022
- [x] T015 Run full PowerShell lint, Tricky human/JSON smoke, repository skill validation, strict MkDocs, and the final EARS gate for REQ-018 through REQ-022
- [x] T016 After separate explicit approval for an image rebuild and benign two-binary parser run, validate SC-003 through SC-006 and record local evidence in `specs/007-analysis-differencing/verification-log.md`

## Dependencies & Execution Order

- T002 and T003 follow T001 and must fail before behavior implementation.
- T004–T005 can complete independently of the binary container work.
- T006 blocks T007–T011 because the tool and image contract must be fixed first.
- T007 blocks T008; T008 blocks T009–T011.
- T012–T013 follow the stable public interfaces.
- T014–T015 follow all automated implementation tasks.
- T016 is state-changing, optional for publication, and requires fresh explicit operator approval.

## Implementation Strategy

1. Deliver general behavior aliases by reusing the validated engine.
2. Establish the graph toolchain and immutable result contract.
3. Add the derived code-query sidecar.
4. Teach case selection and query workflows.
5. Validate without launching unapproved isolation or rebuilding images.
