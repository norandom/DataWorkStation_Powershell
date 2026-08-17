# Tasks: Spec Feature Governance

**Input**: Design documents from `specs/012-spec-feature-governance/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/feature-governance-command.md`, `quickstart.md`

**Tests**: Mandatory. Synthetic behavioral tests precede all implementation. The public command and
test suite are observational and must leave the active feature pointer and unrelated drafts intact.

## Phase 1: Setup and Red Evidence

- [X] T001 Record the missing-core red run and confirm no production governance command exists yet in `specs/012-spec-feature-governance/research.md` for REQ-012 and REQ-015 using `tests/Test-SpecFeatureGovernance.ps1#NonMutation` and `#UnrelatedDraft`
- [X] T002 Run `ears-sdd validate --feature specs/012-spec-feature-governance --phase spec` and `--phase plan` against `specs/012-spec-feature-governance/traceability.toml`

---

## Phase 2: Foundational Contracts

- [X] T003 [P] Add failing synthetic catalog, feature-path, artifact, gate, pairing, legacy, output, hook, documentation, and non-mutation selectors in `tests/Test-SpecFeatureGovernance.ps1` for REQ-001–REQ-015
- [X] T004 Define the private evaluation adapter, canonical result, failure record, fingerprint, feature normalization, and human rendering boundaries in `scripts/FeatureGovernance.Core.ps1` for REQ-001–REQ-012 and REQ-015 using `#HumanCommand`, `#OutputParity`, `#PathBoundary`, `#ActionableFailure`, `#LegacyFingerprint`, and `#NonMutation`

**Checkpoint**: Synthetic declarations can be evaluated without real filesystem access or external validator execution.

---

## Phase 3: User Story 1 - Catch an Unspecced State Capability (Priority: P1)

**Goal**: Reject non-grandfathered declarations without a complete, passing dedicated feature.

**Independent Test**: Synthetic modules/routes fail for missing or invalid references, missing
artifacts, failed final gates, and paired-reference disagreement; the valid pair passes.

### Tests for User Story 1

- [X] T005 [US1] Run the failing module, route, path, artifact, final-gate, failure, and pairing selectors in `tests/Test-SpecFeatureGovernance.ps1` for REQ-003–REQ-009 using `#ModuleReference`, `#StateRouteReference`, `#PathBoundary`, `#RequiredArtifacts`, `#FinalGate`, `#ActionableFailure`, and `#PairedReference`

### Implementation for User Story 1

- [X] T006 [US1] Implement nonlegacy reference enforcement, normalized `specs` containment, artifact checks, distinct final-gate evaluation, actionable failures, and route/module agreement in `scripts/FeatureGovernance.Core.ps1` for REQ-003–REQ-009 using the T005 selectors
- [X] T007 [US1] Add the first governed `FeatureSpec`/`Modules` declarations for Exploit Protection in `config/workstation-modules.psd1` and `config/capabilities.psd1` for REQ-003–REQ-009 using `#ModuleReference`, `#StateRouteReference`, and `#PairedReference`

**Checkpoint**: A future module or state route cannot pass without a valid referenced feature.

---

## Phase 4: User Story 2 - Keep Legacy Scope Explicit (Priority: P1)

**Goal**: Preserve a visible, non-expanding exception boundary for historical declarations.

**Independent Test**: Duplicate, unknown, added, removed, and reordered legacy identities produce
the declared deterministic fingerprint behavior.

### Tests for User Story 2

- [X] T008 [US2] Run the failing legacy-boundary and fingerprint selectors in `tests/Test-SpecFeatureGovernance.ps1` for REQ-010–REQ-011 using `#LegacyBoundary` and `#LegacyFingerprint`

### Implementation for User Story 2

- [X] T009 [US2] Add the reviewed 2026-08-17 legacy module/state-route membership and pinned canonical SHA-256 in `config/spec-feature-governance.psd1`, then enforce it in `scripts/FeatureGovernance.Core.ps1` for REQ-010–REQ-011 using `#LegacyBoundary` and `#LegacyFingerprint`

**Checkpoint**: Later catalog additions cannot enter the legacy boundary implicitly.

---

## Phase 5: User Story 3 - Run the Guard Before Publication (Priority: P2)

**Goal**: Expose one human/JSON command and invoke it from normal publication paths.

**Independent Test**: Human and JSON results agree, failures return nonzero, the hook invokes the
same command, documentation routes it, and unreferenced drafts remain untouched.

### Tests for User Story 3

- [X] T010 [US3] Run the failing human, output-parity, non-mutation, hook, documentation, and unrelated-draft selectors in `tests/Test-SpecFeatureGovernance.ps1` for REQ-001–REQ-002 and REQ-012–REQ-015 using `#HumanCommand`, `#OutputParity`, `#NonMutation`, `#PreCommitHook`, `#DocumentationAndRouting`, and `#UnrelatedDraft`

### Implementation for User Story 3

- [X] T011 [US3] Bind production catalog loading, read-only file checks, explicit-feature `ears-sdd` JSON final validation, rendering, and exit behavior in `scripts/Test-SpecFeatureGovernance.ps1` for REQ-001–REQ-002, REQ-007–REQ-008, and REQ-012–REQ-015 using `#HumanCommand`, `#OutputParity`, `#ActionableFailure`, `#NonMutation`, and `#UnrelatedDraft`
- [X] T012 [US3] Add the focused pre-commit hook, capability commands, operator documentation, samples, and Pester adapter in `.pre-commit-config.yaml`, `config/capabilities.psd1`, `docs/spec-driven-development.md`, `docs/sample-outputs.md`, `tests/pester/SpecFeatureGovernance.Tests.ps1`, and `tests/Test-PowerShellTestingState.ps1` for REQ-013–REQ-014 using `#PreCommitHook` and `#DocumentationAndRouting`

**Checkpoint**: The governance guard is directly usable and runs before a commit is accepted.

---

## Phase 6: Integration and Publication Gates

- [X] T013 Run all selectors under Windows PowerShell 5.1 and PowerShell 7, the Pester Core/Desktop adapters, the public human/JSON commands, baseline Capabilities/Governance, and `git diff --check` without repository mutation
- [X] T014 Run `lint-powershell`, Tricky human and JSON smoke tests, `uv run --locked --group docs mkdocs build --strict --site-dir site`, and `pre-commit run spec-feature-governance --all-files`
- [X] T015 Run `ears-sdd validate --feature specs/012-spec-feature-governance --phase final`, append exact verification results to `specs/012-spec-feature-governance/quickstart.md`, and confirm every task is complete

---

## Dependencies & Execution Order

- Phase 1 records the honest red state and artifact gates.
- Phase 2 establishes the shared synthetic evaluation contract.
- User Story 1 implements the blocking dedicated-feature rule.
- User Story 2 adds the historical exception boundary required by the real catalogs.
- User Story 3 publishes the already-proven core through human, JSON, hook, and documentation paths.
- Integration and publication depend on all story checkpoints.

## Parallel Opportunities

- T003 selector review can proceed independently of core design review, but production work waits
  for its red result.
- Documentation and Pester adapter edits within T012 touch separate files after the public command
  contract is stable.
- Dual-runtime focused tests in T013 are observational and may run concurrently.

## Implementation Strategy

1. Preserve the red missing-core evidence.
2. Implement only the private synthetic evaluation boundary.
3. Prove new declaration failures before adding the real legacy catalog.
4. Publish the public command and hook only after catalog behavior passes.
5. Complete both runtime lanes and all publication gates.

## Requirement Coverage Matrix

| Requirement | Failing/characterization task | Implementation/verification task |
|---|---|---|
| REQ-001–REQ-002 | T003, T010 | T004, T011, T013 |
| REQ-003–REQ-009 | T003, T005 | T004, T006, T007, T013 |
| REQ-010–REQ-011 | T003, T008 | T004, T009, T013 |
| REQ-012 | T001, T003, T010 | T004, T011, T013 |
| REQ-013–REQ-014 | T003, T010 | T012, T014 |
| REQ-015 | T001, T003, T010 | T004, T011, T013 |

## Notes

- No task authorizes workstation mutation, active-feature changes, package installation, or Git
  staging/commit/reset by the governance command.
- Tests may name requirement IDs; production files must not.
