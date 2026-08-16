# Tasks: Native Forensic EWF Verification

**Input**: Design documents from `specs/008-native-forensic-verification/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and `quickstart.md`

**Tests**: Mandatory. Every behavior begins with an observed failing selector. Runtime tests use benign repository fixtures, synthetic catalog/package state, and an injected native-process seam; they do not process case evidence, contact the network, install software, or publish releases unless a later task explicitly says so.

## Phase 1: Setup and test infrastructure

**Purpose**: Establish safe, reusable test support without implementing forensic behavior.

- [X] T001 Create the Pester adapter in `tests/pester/NativeForensicVerification.Tests.ps1`, register it in `tests/Test-PowerShellTestingState.ps1`, and expose individually runnable selector cases from `tests/Test-NativeForensicVerification.ps1`
- [X] T002 [P] Add isolated synthetic catalog, package, process-result, report-root, and cleanup builders in `tests/helpers/NativeForensicTestSupport.ps1`; generated state MUST remain under the test temporary directory
- [X] T003 [P] Generate and commit minimal valid and hashless segmented E01 fixtures from a documented non-case byte pattern using pinned `ewfacquirestream` for the ordinary image and the reviewed MSVC/libewf source in `tests/fixtures/ewf/generator/ewf_fixture_writer.c` that omits MD5/SHA1 setter calls for the hashless image; prove both are readable, record generator/toolchain identity plus physical/media hashes in `tests/fixtures/ewf/README.md` and `tests/fixtures/ewf/expected.psd1`, and commit no case evidence or generator executable

---

## Phase 2: Foundational red baseline

**Purpose**: Prove that the approved contracts exist while the production surface remains unimplemented.

**Critical gate**: No production task starts until the selector harness runs in both PowerShell lanes and the missing production commands are recorded as expected failures.

- [X] T004 Validate both JSON schemas, verify every committed fixture against `tests/fixtures/ewf/expected.psd1`, run every section of `tests/Test-NativeForensicVerification.ps1` in PowerShell 7 and Windows PowerShell 5.1, and retain the expected production-command failures in `specs/008-native-forensic-verification/verification-log.md`

---

## Phase 3: User Story 1 - Verify an EWF evidence set (Priority: P1) MVP

**Goal**: One human-readable native Windows command plans or verifies a complete EWF segment set without mounting or modifying it.

**Independent test**: Run `HumanInterface`, `NativeWindowsBoundary`, `Planning`, `EvidenceReadOnly`, `SegmentInventory`, `SegmentIntegrity`, `MediaDigests`, `HashlessEvidence`, `FormatCertification`, `InvocationEvidence`, `OfflineExecution`, and `RuntimeCompatibility` against the real repository-owned EWF segment fixtures and an injected deterministic native-process result in both PowerShell lanes. The packaged-verifier integration reruns the same fixtures at T046.

### Failing tests

- [X] T005 [US1] Expand and observe failing human-command, separate plan-schema, plan-only, native-boundary, documentation-routing, and dual-runtime assertions for REQ-001 through REQ-003, REQ-024, and REQ-025 in `tests/Test-NativeForensicVerification.ps1#HumanInterface`, `#Planning`, `#NativeWindowsBoundary`, `#DocumentationRouting`, and `#RuntimeCompatibility`
- [X] T006 [US1] Expand and observe failing read-only held-handle, complete ordered inventory, gap/duplicate/ambiguity, per-segment pre/post hash, and mutation assertions over repository EWF fixtures for REQ-004 through REQ-007 in `tests/Test-NativeForensicVerification.ps1#EvidenceReadOnly`, `#SegmentInventory`, and `#SegmentIntegrity`
- [X] T007 [US1] Expand and observe failing stored/calculated media digest, real hashless-fixture non-verdict, certified-format allowlist, unsupported-feature, derived corrupt-input, and bounded-status assertions for REQ-008 through REQ-010 in `tests/Test-NativeForensicVerification.ps1#MediaDigests`, `#HashlessEvidence`, and `#FormatCertification`
- [X] T008 [US1] Expand and observe failing exact-argument, UTC timing, exit-code, stdout/stderr identity, no-network, and PowerShell parity assertions for REQ-011, REQ-022, and REQ-025 in `tests/Test-NativeForensicVerification.ps1#InvocationEvidence`, `#OfflineExecution`, and `#RuntimeCompatibility`

### Implementation

- [X] T009 [US1] Implement the PowerShell 5.1-compatible command parameters, catalog/tool preflight, plan-only result conforming to `specs/008-native-forensic-verification/contracts/ewf-verification-plan.schema.json`, native-Windows boundary checks, and injected process seam for REQ-001 through REQ-003 in `scripts/Invoke-EwfVerification.ps1` using `#HumanInterface`, `#Planning`, and `#NativeWindowsBoundary`
- [X] T010 [US1] Implement deterministic mixed-case EWF segment discovery and rejection of gaps, duplicates, conflicting basenames, unexpected suffixes, and ambiguous sets for REQ-004 through REQ-006 in `scripts/Invoke-EwfVerification.ps1` using `#EvidenceReadOnly`, `#SegmentInventory`, and `#SegmentIntegrity`
- [X] T011 [US1] Implement held read-only segment streams, streaming SHA-256 before and after invocation, length comparison, disposal, and `evidence-changed` precedence for REQ-004, REQ-006, and REQ-007 in `scripts/Invoke-EwfVerification.ps1` using `#EvidenceReadOnly` and `#SegmentIntegrity`
- [X] T012 [US1] Implement absolute-path `ewfverify` invocation, exact argument/timing/exit evidence, supported output parsing, stored/calculated media digests, and network-free execution for REQ-008, REQ-011, and REQ-022 in `scripts/Invoke-EwfVerification.ps1` using `#MediaDigests`, `#InvocationEvidence`, and `#OfflineExecution`
- [X] T013 [US1] Implement `verified`, `readable-no-stored-hash`, `integrity-failed`, `evidence-changed`, `unsupported`, `tool-integrity-failed`, and `parser-output-unrecognized` status/exit precedence for REQ-006, REQ-009, REQ-010, and REQ-025 in `scripts/Invoke-EwfVerification.ps1`, then run all US1 selectors in both PowerShell lanes
- [X] T014 [US1] Add the thin `ewf-verify` human wrapper for REQ-001 and REQ-025 in `profile/ForensicTools.ps1`, deploy it through `scripts/Set-PowerShellProfile.ps1`, and prove `#HumanInterface` and `#RuntimeCompatibility` resolve the same script in Windows PowerShell 5.1 and PowerShell 7

**Checkpoint**: US1 exercises real repository-owned EWF segment structures and fails closed for derived corrupt, incomplete, changed, hashless, and unsupported cases without requiring package approval. T046 repeats the same corpus with the actual immutable package.

---

## Phase 4: User Story 2 - Produce a defensible verification report (Priority: P1)

**Goal**: Every verification creates a non-overwriting human report, schema-conformant JSON, and bounded raw artifacts that attribute the evidence and exact tool package.

**Independent test**: Run `ReportContract`, `JsonParity`, `HostileOutput`, `InvocationEvidence`, `HistoricalAttribution`, `ReportPersistence`, and `RuntimeCompatibility` twice against a fixed synthetic run, then compare stable facts and verify raw artifact hashes and unchanged source evidence.

### Failing tests

- [X] T015 [US2] Expand and observe failing complete report-schema, tool/dependency/source attribution, mandatory catalog-file SHA-256, nullable clean catalog commit, stable-versus-volatile fact, human/JSON parity, and historical identity assertions for REQ-012, REQ-013, and REQ-021 in `tests/Test-NativeForensicVerification.ps1#ReportContract`, `#JsonParity`, and `#HistoricalAttribution`
- [X] T016 [US2] Expand and observe failing bounded raw stdout/stderr, invalid encoding, escape/control neutralization, long field, misleading success text, and cryptographic artifact identity assertions for REQ-011 and REQ-014 in `tests/Test-NativeForensicVerification.ps1#InvocationEvidence` and `#HostileOutput`
- [X] T017 [US2] Expand and observe failing staging, atomic commit, full/read-only destination, evidence-directory rejection, existing-run no-overwrite, and cleanup assertions for REQ-023 in `tests/Test-NativeForensicVerification.ps1#ReportPersistence`

### Implementation

- [X] T018 [US2] Implement bounded asynchronous raw stdout/stderr capture, byte-level SHA-256, sanitized display decoding, upstream log preservation, and truncation metadata for REQ-011 and REQ-014 in `scripts/Invoke-EwfVerification.ps1` using `#InvocationEvidence` and `#HostileOutput`
- [X] T019 [US2] Implement catalog-file SHA-256 attribution, nullable exact clean catalog commit resolution, warnings for dirty/missing Git metadata, unique staging, report artifact inventory, complete `report.json`/`report.txt`, atomic run-directory rename, and fail-closed cleanup/no-overwrite behavior for REQ-012, REQ-021, and REQ-023 in `scripts/Invoke-EwfVerification.ps1` using `#ReportContract`, `#HistoricalAttribution`, and `#ReportPersistence`
- [X] T020 [US2] Implement concise sanitized default output and one-object bounded JSON with equivalent evidence, provenance, digest, warning, and outcome facts for REQ-012 through REQ-014 in `scripts/Invoke-EwfVerification.ps1` using `#ReportContract`, `#JsonParity`, and `#HostileOutput`
- [X] T021 [US2] Add cross-runtime report normalization tests and make the smallest compatibility corrections for REQ-013 and REQ-025 in `tests/Test-NativeForensicVerification.ps1#JsonParity` and `#RuntimeCompatibility` plus `scripts/Invoke-EwfVerification.ps1`
- [X] T022 [US2] Run the US1 and US2 contract/Pester selectors twice in both PowerShell lanes and record deterministic facts, expected volatile fields, raw artifact identities, and unchanged input hashes in `specs/008-native-forensic-verification/verification-log.md`

**Checkpoint**: US2 produces defensible reports from a synthetic approved verifier without installing or publishing a real package.

---

## Phase 5: User Story 3 - Install a known forensic tool package (Priority: P1)

**Goal**: An explicit desired-state module plans, installs, and tests one native Windows package whose release and internal file identities are independently pinned in Git.

**Independent test**: Feed synthetic matching and mismatching release packages to `Plan`, `Test`, and `Ensure`; confirm allowlisted atomic installation, drift detection, fail-closed execution, zero compilation, and no WSL/Unix compatibility path.

### Failing tests

- [X] T023 [US3] Expand and observe failing complete catalog schema, `Approved`-only installation, non-installable `Superseded` history, literal source/release identity, independent package digest, isolated trusted-key fingerprint, native `gpgv.exe`/PE/import allowlist, and no-floating-reference assertions for REQ-002, REQ-015, and REQ-029 in `tests/Test-NativeForensicVerification.ps1#NativeWindowsBoundary`, `#CatalogSchema`, and `#ReleaseTrustAnchor`
- [X] T024 [US3] Expand and observe failing `Absent`/`Compliant`/`Drifted`/`Unapproved`, archive traversal/extra-file rejection, atomic versioned install, installed-file recheck, and execution refusal assertions for REQ-016 and REQ-017 in `tests/Test-NativeForensicVerification.ps1#InstallIntegrity` and `#ToolDrift`
- [X] T025 [US3] Expand and observe failing minimal-package, manifest/checksum/license/SBOM/provenance, immutable release identity, and no-runtime-build assertions for REQ-026 and REQ-027 in `tests/Test-NativeForensicVerification.ps1#ReleasePackageContract`, `#InstallWithoutBuild`, and `#ReleaseTrustAnchor`

### Implementation

- [X] T026 [US3] Define the candidate build inputs, exact source/signature hashes, standalone GnuPG 2.5.21 Windows installer hash/Authenticode identity, reviewed libyal key/fingerprint, MSVC/vstools identities, package shape, parser profile, and independent release trust fields for REQ-015 and REQ-029 in `config/forensic-builds/ewfverify-20231119-b1.psd1`, `config/forensic-builds/keys/libyal-0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E.asc`, and `config/forensic-tools.psd1` using `#CatalogSchema` and `#ReleaseTrustAnchor`
- [X] T027 [US3] Implement catalog validation and observational `Plan`/`Test` installed-state evaluation for REQ-015 and REQ-017 in `scripts/Set-NativeForensicToolsState.ps1` using `#CatalogSchema`, `#ToolDrift`, and `#NativeWindowsBoundary`
- [X] T028 [US3] Implement explicit `Ensure` download, release/package validation, safe extraction, internal allowlist/hash checks, atomic versioned per-user install, and rollback preservation for REQ-016, REQ-017, REQ-027, and REQ-029 in `scripts/Set-NativeForensicToolsState.ps1` using `#InstallIntegrity`, `#ToolDrift`, `#InstallWithoutBuild`, and `#ReleaseTrustAnchor`
- [X] T029 [US3] Implement pinned-source hashing, isolated `gpgv.exe --keyring` detached-signature verification with exact signer fingerprint, native MSVC x64 build, minimal package assembly, manifest/checksums/licenses/SBOM/provenance generation, and forbidden import/tool rejection for REQ-002, REQ-026, and REQ-027 in `scripts/Build-NativeForensicTool.ps1` using `#NativeWindowsBoundary`, `#ReleasePackageContract`, and `#InstallWithoutBuild`
- [X] T030 [US3] Implement offline candidate package structure, PE architecture/import, internal digest, source/build provenance, Authenticode-state, and certification-result validation for REQ-002, REQ-015, and REQ-026 in `scripts/Test-ForensicReleaseCandidate.ps1` using `#NativeWindowsBoundary`, `#CatalogSchema`, and `#ReleasePackageContract`
- [X] T031 [US3] Add a manual, full-SHA-pinned Windows build workflow that produces an attested draft release asset without `--clobber` for REQ-026 in `.github/workflows/forensic-tool-build.yml` using `#ReleasePackageContract` and `#ReleaseTrustAnchor`
- [X] T032 [US3] Add the optional non-default `NativeForensicTools` module with declared PowerShell/profile dependencies and `Plan`/`Test`/`Ensure` routing for REQ-016 through REQ-018 and REQ-027 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1` using `#InstallIntegrity`, `#ToolDrift`, `#UpdatePolicy`, and `#InstallWithoutBuild`
- [X] T033 [US3] Make runtime verification revalidate the approved catalog plus every executable/DLL immediately before absolute-path invocation for REQ-016 and REQ-017 in `scripts/Invoke-EwfVerification.ps1` using `#InstallIntegrity`, `#ToolDrift`, and `#InvocationEvidence`
- [X] T034 [US3] Run synthetic `Plan`, `Test`, `Ensure`, drift, traversal, extra-file, mismatched-hash, rollback, and no-compiler cases in both PowerShell lanes and record the green US3 evidence in `specs/008-native-forensic-verification/verification-log.md`

**Checkpoint**: US3 can safely install and verify an immutable-shaped synthetic package. No external release or repository setting changes have occurred yet.

---

## Phase 6: User Story 4 - Review and upgrade forensic tooling (Priority: P2)

**Goal**: A maintainer can certify a new package, preserve historical identities, and publish a new immutable revision without ordinary update adopting it.

**Independent test**: Present a synthetic newer candidate and changed build inputs; confirm ordinary update reports but does not adopt it, the full benign corpus gates approval, and every changed input requires a distinct non-replacing build revision.

### Failing tests

- [X] T035 [US4] Expand and observe failing pinned ordinary-update, candidate-only reporting, explicit approval, and valid/corrupt/incomplete/hashless/unsupported/hostile certification assertions for REQ-018 through REQ-020 in `tests/Test-NativeForensicVerification.ps1#UpdatePolicy`, `#UpgradeCertification`, and `#CertificationCorpus`
- [X] T036 [US4] Expand and observe failing historical record retention, non-self-referential approval evidence, clean containing-commit resolution at publish time, report attribution after upgrade, changed-input revision increment, immutable old asset, no-clobber, attestation, and release-setting assertions for REQ-021 and REQ-026 through REQ-029 in `tests/Test-NativeForensicVerification.ps1#HistoricalAttribution`, `#BuildRevisionPolicy`, and `#ReleaseTrustAnchor`

### Implementation

- [X] T037 [US4] Derive corrupt, incomplete, unsupported, hostile-output, and persistence-failure cases only in test-temporary storage from the committed benign EWF fixtures and validate their expected recipes for REQ-020 in `tests/helpers/NativeForensicTestSupport.ps1` and `tests/Test-NativeForensicVerification.ps1#CertificationCorpus`
- [X] T038 [US4] Extend offline candidate certification across valid, corrupt, incomplete, hashless, unsupported, hostile-output, persistence, and both-shell cases; block approval on any mismatch for REQ-019 and REQ-020 in `scripts/Test-ForensicReleaseCandidate.ps1` and `tests/Test-NativeForensicVerification.ps1` using `#UpgradeCertification` and `#CertificationCorpus`
- [X] T039 [US4] Keep the approved forensic version pinned during ordinary update and report only explicit `Candidate` records from the checked-out Git catalog without upstream/GitHub discovery or installation for REQ-018 in `scripts/Invoke-WorkstationUpdate.ps1` and `scripts/Set-NativeForensicToolsState.ps1` using `#UpdatePolicy` and `#ToolDrift`
- [X] T040 [US4] Implement candidate-versus-approved comparison, changed-input build revision enforcement, historical record preservation, draft validation, attestation verification, explicit confirmation, immutable publish, and no-clobber behavior for REQ-019, REQ-021, and REQ-026 through REQ-029 in `scripts/Publish-NativeForensicTool.ps1` and `.github/workflows/forensic-tool-publish.yml` using `#UpgradeCertification`, `#HistoricalAttribution`, `#BuildRevisionPolicy`, and `#ReleaseTrustAnchor`
- [X] T041 [US4] Migrate the general documentation release workflow from replaceable uploads to draft-upload-publish verification before repository immutability is enabled for REQ-026 and REQ-028 in `.github/workflows/release.yml` using `#BuildRevisionPolicy` and `#ReleaseTrustAnchor`
- [ ] T042 [US4] After explicit maintainer confirmation, verify the general release workflow is compatible and enable GitHub immutable releases without dispatching a build or publishing an asset for REQ-026 and REQ-028; record the setting evidence in `specs/008-native-forensic-verification/verification-log.md` using `#BuildRevisionPolicy` and `#ReleaseTrustAnchor`
- [ ] T043 [US4] Explicitly dispatch the reviewed `ewfverify-20231119-b1` build into a draft release, retain workflow/attestation/certification outputs, and make no catalog approval or publication change for REQ-019 and REQ-026 in `specs/008-native-forensic-verification/verification-log.md` using `#UpgradeCertification` and `#ReleasePackageContract`
- [ ] T044 [US4] Review the draft asset, source signature, package/internal hashes, imports, SBOM, provenance, corpus results, and attestation; then commit a non-self-referential `Approved` decision in `config/forensic-tools.psd1` for REQ-019, REQ-026, and REQ-029 using `#UpgradeCertification`, `#ReleasePackageContract`, and `#ReleaseTrustAnchor`
- [ ] T045 [US4] From the clean reviewed catalog commit, explicitly publish the draft immutable release, verify the tag/asset/attestations and recorded catalog-file SHA-256/containing commit, and prove the prior asset was not replaced for REQ-021 and REQ-026 through REQ-029 in `specs/008-native-forensic-verification/verification-log.md` using `#HistoricalAttribution`, `#BuildRevisionPolicy`, and `#ReleaseTrustAnchor`
- [ ] T046 [US4] Explicitly install the approved package locally, run the full committed/derived corpus and historical-attribution report in both PowerShell lanes, then record release tag, asset/package/internal hashes, attestation, zero local builds, and green results for REQ-019 through REQ-021 and REQ-026 through REQ-029 in `specs/008-native-forensic-verification/verification-log.md`

**Checkpoint**: The first package is published once, installed from its immutable release, fully attributable, and protected from silent upgrade or rebuild.

---

## Phase 7: Documentation, orchestration, and final gates

**Purpose**: Make the human command discoverable before adding focused AI routing, and close publication evidence.

- [X] T047 Update the human command, separate plan/report schemas, status/exit meanings, examples, sample outputs, read-only boundary, report interpretation, native-Windows restriction, attack surface, package lifecycle, and explicit install/build/publish operations for REQ-024 in `docs/ewf-verification.md`, `docs/forensic-tools.md`, `docs/sample-outputs.md`, `README.md`, and `mkdocs.yml` using `tests/Test-NativeForensicVerification.ps1#DocumentationRouting`
- [X] T048 Update human/AI routing for REQ-001 and REQ-024 in `config/capabilities.psd1`, then create the focused `.agents/skills/verify-forensic-evidence/SKILL.md` only after the documented `ewf-verify` command is green using `#HumanInterface` and `#DocumentationRouting`
- [X] T049 [P] Add the feature, immutable forensic package, explicit privilege/network boundaries, and operator-visible changes to `CHANGELOG.md` and the relevant release documentation using REQ-024 and `tests/Test-NativeForensicVerification.ps1#DocumentationRouting`
- [ ] T050 Run all dependency-free contracts, both PowerShell Pester lanes, native candidate certification, `ears-sdd validate --phase final`, `lint-powershell`, Tricky human/JSON smoke tests, focused skill validation, `uv run --group docs mkdocs build --strict`, and `git diff --check`; record every gate in `specs/008-native-forensic-verification/verification-log.md`
- [ ] T051 Reconcile `specs/008-native-forensic-verification/traceability.toml` with the green selector inventory and confirm all 29 requirements have a preceding failing test plus passing implementation evidence in `specs/008-native-forensic-verification/verification-log.md`

---

## Dependencies and execution order

- Phase 1 test infrastructure blocks the red baseline in Phase 2.
- US1 starts after the red baseline and uses an injected native-process result; it does not depend on a published tool package.
- US2 depends on US1's verification result model and invocation seam, but remains independently testable with synthetic tool output.
- US3 depends on the US1 preflight contract and makes the synthetic approved-package lifecycle executable; it does not publish externally.
- US4 depends on US3 build/install contracts. T042 through T046 separate the explicitly confirmed external setting change, draft build, approval commit, immutable publication, and local consumption so each state is independently reviewable.
- Documentation and focused skill routing depend on the stable human command. Final publication gates depend on all selected stories.
- Within every story, listed failing-test tasks must be observed red before the corresponding implementation task begins.

## Parallel opportunities

- T002 and T003 touch separate test-support/fixture files and can run in parallel.
- After Phase 2, US1 must lead; once its result model is stable, report-schema work in US2 and catalog-schema work in US3 can be prepared in parallel, though shared edits to `tests/Test-NativeForensicVerification.ps1` must be serialized.
- T031 workflow authoring can proceed beside T032 module wiring after T026 through T030 establish their contracts.
- T037 derived-corpus test support and T039 ordinary-update pinning use separate files after their tests are red.
- T049 release-note writing can proceed alongside final test preparation after the public command/docs are stable.

## Parallel execution examples

### User Story 2 and User Story 3 preparation

```text
Task: T015-T017 define the red report and persistence contracts in tests/Test-NativeForensicVerification.ps1
Task: T026 define candidate/runtime catalog records in config/forensic-builds/ and config/forensic-tools.psd1
```

Do not edit the shared test file concurrently; finish the US2 test edit before T023-T025 expands the US3 selectors.

### User Story 4

```text
Task: T037 derive negative corpus cases in tests/helpers/NativeForensicTestSupport.ps1
Task: T039 implement pinned candidate reporting in scripts/Invoke-WorkstationUpdate.ps1
```

## Requirement coverage

| Requirements | Failing-test tasks | Implementation/verification tasks |
|---|---|---|
| REQ-001 | T005 | T009, T014, T048, T050 |
| REQ-002 | T005, T023 | T009, T029, T030, T050 |
| REQ-003 | T005 | T009, T050 |
| REQ-004 through REQ-007 | T006 | T010, T011, T050 |
| REQ-008 through REQ-010 | T007 | T012, T013, T050 |
| REQ-011 | T008, T016 | T012, T018, T050 |
| REQ-012, REQ-013 | T015 | T019 through T021, T050 |
| REQ-014 | T016 | T018, T020, T050 |
| REQ-015 | T023 | T026, T027, T030, T050 |
| REQ-016, REQ-017 | T024 | T027, T028, T032, T033, T050 |
| REQ-018 | T035 | T032, T039, T050 |
| REQ-019, REQ-020 | T035 | T037, T038, T040, T043, T044, T046, T050 |
| REQ-021 | T015, T036 | T019, T040, T045, T046, T050 |
| REQ-022 | T008 | T012, T050 |
| REQ-023 | T017 | T019, T050 |
| REQ-024 | T005 | T047 through T050 |
| REQ-025 | T005, T008 | T013, T014, T021, T022, T046, T050 |
| REQ-026 | T025, T036 | T029 through T031, T040 through T046, T050 |
| REQ-027 | T025 | T028, T029, T032, T046, T050 |
| REQ-028 | T036 | T040 through T045, T050 |
| REQ-029 | T023, T036 | T026, T028, T040, T044 through T046, T050 |

Coverage: 29 of 29 requirements have a preceding failing-test task and named implementation or verification tasks.

## Implementation strategy

### MVP first

1. Complete test infrastructure and observe the red baseline.
2. Complete US1 using the committed benign EWF fixtures and the injected native-process seam.
3. Stop and validate the read-only EWF transaction in both PowerShell lanes.
4. Add US2 reports, then validate report durability and hostile-output handling independently.

### Incremental delivery

1. US1: trustworthy read-only verification behavior.
2. US2: defensible retained reports.
3. US3: cataloged build/install lifecycle without external publication.
4. US4: reviewed corpus, immutable GitHub publication, and local consumption.
5. Documentation and focused orchestration only after the human command is stable.

## Completion conditions

- All 51 tasks use stable checklist IDs, exact paths, and story labels where required.
- Every behavior task names requirements and test selectors.
- Every production behavior has a preceding observed failing-test task.
- Test and plan modes remain non-mutating; T042 through T046 separate explicitly confirmed GitHub setting, draft-build, approval, publication, and local-install changes.
- No task uses WSL, Linux containers, Cygwin, MSYS/MSYS2, MinGW runtimes, or Git Bash for forensic tooling.
- No repository task commits case evidence or packaged executable binaries to ordinary Git history.
