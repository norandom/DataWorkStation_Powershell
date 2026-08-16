# Implementation Plan: Native Forensic EWF Verification

**Feature**: `008-native-forensic-verification` | **Date**: 2026-08-16 | **Spec**: [spec.md](spec.md)

## Summary

Add an evidence-preserving, native-Windows command for verifying segmented EWF images. The command uses a cataloged and hash-pinned `ewfverify` package, holds read-only handles across pre-verification and post-verification hashes, records raw tool output, and emits a durable human report plus a stable JSON contract. Only a fully supported image whose stored digest verifies and whose segment bytes remain unchanged receives `verified` status.

The runtime package is built once from pinned upstream sources on native Windows, certified with a repository-owned corpus, attached to an immutable GitHub Release, and installed without a compiler. Build and publication remain explicit maintainer operations, separate from workstation updates.

## Technical Context

**Language/Version**: Windows PowerShell 5.1 and PowerShell 7.x; native C/C++ built with MSVC Build Tools 2022 (v143, x64)

**Primary Dependencies**: libewf/`ewfverify` 20231119, zlib 1.3.2, bzip2 1.0.8, pinned libyal `vstools` conversion commit, Pester 5, GitHub Releases and artifact attestations

**Build-only Authenticity Dependency**: official standalone GnuPG 2.5.21 for Windows with pinned installer hash/Authenticode identity and an isolated repository-owned libyal verification key; neither is shipped at runtime

**Storage**: Git-tracked PSD1 catalogs and test fixtures; versioned per-user runtime installation; immutable GitHub Release assets; append-only report directories

**Testing**: repository smoke/contract tests, Pester in PowerShell 5.1 and 7.x, native-package certification corpus, EARS/TDD traceability gate

**Target Platform**: Windows 11 Pro x64. Runtime verification and build are native Windows only.

**Project Type**: PowerShell infrastructure-as-code repository with a native helper package

**Performance Goals**: stream segment hashes without loading evidence into memory; add no unbounded stdout/stderr buffering; verification speed remains dominated by sequential evidence reads and upstream verification

**Constraints**: no WSL, Linux container, Cygwin, MSYS/MSYS2, MinGW runtime, or Git Bash in the forensic path; no evidence writes; no network during verification; no runtime compilation; no floating download; no overwrite of completed reports

**Scale/Scope**: one initially certified EWF family and one Windows x64 build; segmented evidence sets may be much larger than RAM; acquisition, mounting, export, recovery, and case management are excluded

## Constitution Check

The pre-design and post-design checks pass.

| Principle | Design response |
|---|---|
| Human/AI parity | `ewf-verify` and the underlying script are the primary interface. JSON is an option on the same command; the skill only routes to it. |
| Evidence before capture | The feature verifies existing images and records existing tool output. It starts no ambient capture. |
| Explicit privileged/state changes | Planning is read-only. Installation uses explicit `-Mode Plan`, `Test`, or `Ensure`; build and publish are separate confirmed commands. Verification requires no elevation. |
| Capability catalog | The final command and evidence contract will be registered in `config/capabilities.psd1`. |
| Human default, machine JSON | The default is concise human output and `-Json` produces one schema-conformant object. |
| Focused skills | A narrow `verify-forensic-evidence` skill will route this feature; it will not absorb unrelated workstation or malware workflows. |
| Publication gates | PowerShell lint, Tricky smoke tests, Pester lanes, certification, EARS validation, and strict MkDocs build are required before publication. |

## Project Structure

### Documentation for this feature

```text
specs/008-native-forensic-verification/
|-- spec.md
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- traceability.toml
|-- checklists/
`-- contracts/
    |-- ewf-verification-cli.md
    |-- ewf-verification-plan.schema.json
    |-- forensic-tool-catalog.md
    `-- ewf-verification-report.schema.json
```

### Proposed implementation paths

```text
.github/workflows/
|-- forensic-tool-build.yml
|-- forensic-tool-publish.yml
`-- release.yml
.agents/skills/verify-forensic-evidence/SKILL.md
config/
|-- capabilities.psd1
|-- forensic-tools.psd1
`-- forensic-builds/
    |-- ewfverify-20231119-b1.psd1
    `-- keys/libyal-0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E.asc
docs/
|-- forensic-tools.md
`-- ewf-verification.md
profile/ForensicTools.ps1
scripts/
|-- Build-NativeForensicTool.ps1
|-- Invoke-EwfVerification.ps1
|-- Publish-NativeForensicTool.ps1
|-- Set-NativeForensicToolsState.ps1
`-- Test-ForensicReleaseCandidate.ps1
tests/
|-- Test-NativeForensicVerification.ps1
|-- fixtures/ewf/
|   |-- README.md
|   |-- expected.psd1
|   |-- generator/ewf_fixture_writer.c
|   `-- benign segmented EWF fixtures
`-- pester/NativeForensicVerification.Tests.ps1
```

**Structure decision**: extend the repository's existing module, profile, capability, script, documentation, and test conventions. Keep build-input records separate from approved runtime records. Store only small benign certification fixtures in Git; publish executables in GitHub Releases.

Existing integration points to update during implementation are `Apply-Workstation.ps1`, the module catalog, profile deployment, `config/capabilities.psd1`, `.gitignore`, README, MkDocs navigation, test inventory, and release notes.

## Build and Release Lifecycle

1. A candidate build record pins every source archive, signature or authenticity record, SHA-256 digest, converter commit, compiler family, architecture, and build option. It also pins the standalone native Windows `gpgv.exe` provider, its installer identity, and the reviewed libyal key fingerprint.
2. `Build-NativeForensicTool.ps1` validates source hashes and the detached signature with the isolated pinned keyring, creates modern Visual Studio projects with the pinned converter, and builds only `ewfverify` plus required libraries on native Windows.
3. The build rejects unexpected architecture or imports and packages only the verifier, required DLLs, licenses, manifest, SBOM, and provenance.
4. Certification runs the package against the committed corpus in both PowerShell lanes and creates an attested candidate asset in a draft GitHub Release.
5. A maintainer reviews the result and commits an `Approved` catalog record containing the final release tag, asset identity, package digest, internal file digests, provenance, reviewed candidate digest, and approval decision. The record does not self-reference its containing Git commit.
6. From a clean checkout, the publish command resolves the commit containing the exact catalog bytes, records that commit plus the catalog-file SHA-256 in release provenance, checks the draft asset against the approved record, then publishes it as an immutable release. It never overwrites an existing asset.
7. Any change to source, dependency, compiler, converter, recipe, option, or security correction increments the build revision. Existing release records remain attributable and immutable.

The initial identity is `forensic-ewfverify-20231119-b1`, with asset `ewfverify-20231119-windows-x64-b1.zip`. Repository release automation must stop using `gh release upload --clobber` before immutable releases are enabled.

## Runtime Verification Design

1. Resolve the selected segment into a complete, ordered EWF set using a certified extension sequence and reject gaps, duplicates, unsupported layouts, or ambiguous sets.
2. Open every segment read-only with sharing that permits readers but denies write, rename, and delete; retain all handles for the full verification transaction.
3. Stream SHA-256 for every segment from those handles and record lengths and pre-verification hashes.
4. Validate the catalog, package, executable, and DLL digests, then invoke the absolute cataloged `ewfverify` path with the full ordered segment list and SHA-256 verification enabled.
5. Capture stdout and stderr as bounded raw byte artifacts, preserve the upstream log, and parse a sanitized decoded view. Do not pipe untrusted native output directly into a PowerShell expression.
6. Re-hash all held segment handles. Any byte or length change overrides a parser-reported success with `evidence-changed`.
7. Write all report artifacts to a staging directory and atomically rename it to a new run directory. Never overwrite a completed report.

Verification statuses are `verified`, `readable-no-stored-hash`, `integrity-failed`, `evidence-changed`, `unsupported`, `tool-integrity-failed`, `parser-output-unrecognized`, and `report-failed`. Only `verified` exits successfully. Plan output is a separate non-verification contract with status `planned`; it never impersonates a verification report or requires evidence hashes.

## Requirement-to-design Translation

| Requirements | Design and verification |
|---|---|
| REQ-001, REQ-003, REQ-013, REQ-024 | One human-first command, explicit plan mode, JSON parity, capability and docs routing. Contract and smoke tests exercise both output modes. |
| REQ-002, REQ-022, REQ-025 | Native-Windows-only dependency/import checks, offline execution test, and Windows PowerShell/PowerShell 7 test matrix. |
| REQ-004 through REQ-008 | Held read-only handles, deterministic segment inventory, streaming pre/post segment hashes, upstream stored-digest verification, and media digest recording. Fixture and mutation-race tests verify the transaction. |
| REQ-009, REQ-010 | Explicit non-success for images without a stored digest and strict format/version allowlist backed by certification metadata. |
| REQ-011 through REQ-014, REQ-023 | Exact argv and exit evidence, durable human/JSON/raw artifacts, hostile-output handling, atomic persistence, and no overwrite. Schema and fault-injection tests verify this. |
| REQ-015 through REQ-019 | Versioned catalog, hash-verified install, drift detection, no implicit build/update, and recertification for every revision. Catalog and state-transition tests cover each rule. |
| REQ-020, REQ-021 | Repository-owned benign corpus, recorded expected results, preserved historical catalog identities, and report attribution tests. |
| REQ-026 through REQ-029 | Minimal release package, install from immutable release without compiler, build-revision policy, and independent Git catalog trust anchor. Candidate/publish contract tests verify release behavior. |

Every requirement has an automated selector in [traceability.toml](traceability.toml). Production code will not contain requirement IDs; tests may use them for traceability.

## Complexity Tracking

There are no constitution violations. One controlled exception to the normal versioned-archive preference is necessary: libyal `vstools` has no release tags, so the build-only converter is pinned to full commit `ce1bd73b3e23b34e98c206b26df4c2d663500554` with its verified commit identity recorded. The converter is never installed or shipped in the runtime package.
