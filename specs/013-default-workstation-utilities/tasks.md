# Tasks: Default Workstation Utilities

**Input**: Design documents from `specs/013-default-workstation-utilities/`

**Tests**: Mandatory brownfield characterization and regression coverage precedes release ownership.

## Phase 1: Setup and Characterization

- [X] T001 [P] Record reviewed mpv decisions and alternatives in `specs/013-default-workstation-utilities/research.md`
- [X] T002 [P] Record reviewed Safe-Chain trust and integrity decisions in `specs/013-default-workstation-utilities/research.md`
- [X] T003 Add failing/characterization mpv contract assertions in `tests/Test-MpvState.ps1` for REQ-001–REQ-005 using `#All`
- [X] T004 Add failing/characterization Safe-Chain assertions in `tests/Test-SafeChainState.ps1` for REQ-006–REQ-010 using `#All`

## Phase 2: User Story 1 - Reliable Accelerated Media Playback (Priority: P1)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-MpvState.ps1`

- [X] T005 [US1] Declare the official package and bounded GPU policy in `.config/mpv.winget`, `config/mpv.psd1`, and `config/mpv.conf` for REQ-001 and REQ-003–REQ-005 using `tests/Test-MpvState.ps1#All`
- [X] T006 [US1] Implement observational comparison and explicit bounded repair in `scripts/Set-MpvState.ps1` for REQ-002–REQ-005 using `tests/Test-MpvState.ps1#All`
- [X] T007 [US1] Document playback, fallback, and FFmpeg boundaries in `docs/media-playback.md` for REQ-012 using `tests/Test-MpvState.ps1#All`

## Phase 3: User Story 2 - Protected Package-Manager Use (Priority: P1)

**Independent Test**: `pwsh -NoProfile -File .\tests\Test-SafeChainState.ps1`

- [X] T008 [US2] Declare per-platform releases and digests in `config/safe-chain.psd1` for REQ-006–REQ-010 using `tests/Test-SafeChainState.ps1#All`
- [X] T009 [US2] Implement verification, trusted-target selection, registration checks, and explicit repair in `scripts/Set-SafeChainState.ps1` for REQ-007–REQ-010 using `tests/Test-SafeChainState.ps1#All`
- [X] T010 [US2] Add human routing and operator documentation in `config/capabilities.psd1`, `docs/desired-state.md`, and `docs/Aliases.md` for REQ-012 using `tests/Test-SafeChainState.ps1#All`

## Phase 4: User Story 3 - Select and Publish Focused State Safely (Priority: P2)

**Independent Test**: Focused module contracts and feature governance pass without state changes.

- [X] T011 [US3] Register both modules and their dependencies in `Apply-Workstation.ps1` and `config/workstation-modules.psd1` for REQ-011 using `tests/Test-MpvState.ps1#All` and `tests/Test-SafeChainState.ps1#All`
- [X] T012 [US3] Attach module and route feature ownership in `config/workstation-modules.psd1` and `config/capabilities.psd1` for REQ-011–REQ-013 using `tests/Test-SpecFeatureGovernance.ps1#Repository`
- [X] T013 [US3] Add Pester adapters in `tests/pester/MpvState.Tests.ps1` and `tests/pester/SafeChainState.Tests.ps1` for REQ-013 using the focused `#All` selectors

## Phase 5: Publication Gates

- [X] T014 Run focused mpv, Safe-Chain, baseline, capability, and governance tests for REQ-001–REQ-013
- [X] T015 Run full PowerShell lint, Tricky human/JSON smoke, full Pester, and strict MkDocs gates for REQ-013
- [X] T016 Run `ears-sdd validate --feature specs/013-default-workstation-utilities --phase final` and confirm complete traceability

## Dependencies & Execution Order

- Characterization and design decisions precede reviewed implementation ownership.
- User Stories 1 and 2 are independent after setup.
- User Story 3 depends on both focused module contracts.
- Publication gates depend on all stories.

## Parallel Opportunities

- T001 and T002 address separate decisions.
- User Stories 1 and 2 touch independent state resources and tests.
- The two focused contract tests in T014 can run concurrently.

## Implementation Strategy

Treat existing behavior as brownfield: preserve characterization evidence, attach explicit feature
ownership, and publish only after focused and repository-wide regression gates pass.
