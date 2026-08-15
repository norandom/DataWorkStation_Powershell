# Implementation Plan: General Sandbox and Binary Differencing

**Branch**: `main` | **Date**: 2026-08-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/007-analysis-differencing/spec.md`

## Summary

Expose the existing policy-matched Windows Sandbox behavior comparison through general-purpose
human commands. Extend the dedicated rootless static container with two-input Ghidra analysis,
BinExport graph export, BinDiff semantic matching, and an address-keyed SQLite code sidecar. Expand
the operator guide with case selection, artifacts, limitations, and representative queries.

## Technical Context

**Language/Version**: PowerShell 5.1 and PowerShell 7.6; Python 3.13-compatible container code;
Ghidra Java 21 scripts

**Primary Dependencies**: Existing Windows Sandbox malware engine, native Windows Git, rootless
Podman in `Debian-MW`, Ghidra 12.1.2, BinExport v2, BinDiff 8, SQLite 3.46

**Storage**: Ignored case directories containing manifests, graph exports, immutable `.BinDiff`
SQLite databases, derived query-sidecar SQLite databases, JSON summaries, logs, ETL, and canonical
diff trees

**Testing**: Direct PowerShell harness in both runtimes, synthetic command runner/container plans,
Python schema fixtures, Pester adapter, repository lint, Tricky smoke, skill validator, strict MkDocs,
and EARS gates

**Target Platform**: Windows 11 Pro host; Windows Sandbox guest for behavior; dedicated rootless
Debian-MW container for static binary parsing

**Project Type**: PowerShell CLI and declarative workstation repository with isolated Python/Java
analysis components

**Performance Goals**: Planning completes without launching a target; fixture database queries are
deterministic; every external analysis process is time and output bounded

**Constraints**: No host execution or rich parsing, no network during static analysis, no implicit
downloads, explicit execution confirmation, no raw-version fallback, hostile-output boundary,
PowerShell 5.1 compatibility, and no mutation of the BinDiff result database

**Scale/Scope**: One behavior target or one baseline/candidate pair per case; existing 512 MiB input
bound and configured output, record, memory, CPU, PID, and duration limits

## Constitution Check

| Principle | Design response | Gate |
|---|---|---|
| Human/AI Command Parity | Add public behavior and binary-diff commands before updating the focused skill. | PASS |
| Evidence Before Capture or Mutation | Report/compare existing cases first; planning is observational; launches and image builds remain explicit. | PASS |
| EARS Traceability and Test-First Change | REQ-001 through REQ-022 map to named failing selectors before implementation. | PASS |
| Focused Desired State and Dependency Safety | Reuse the optional static image module; BinExport/BinDiff are declared image inputs, not default host packages. | PASS |
| Deterministic Operator Interfaces | Default human output, explicit `-Json`, stable artifacts, both PowerShell runtimes. | PASS |

Post-design review: PASS. No constitutional exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/007-analysis-differencing/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── verification-log.md
├── checklists/requirements.md
└── contracts/analysis-differencing-cli.md
```

### Source Code (repository root)

```text
config/
├── capabilities.psd1
└── malware-container.psd1
profile/
└── Aliases.ps1
scripts/
├── Invoke-MalwareAnalysis.ps1
├── Invoke-MalwareContainerAnalysis.ps1
├── Compare-MalwareEvidence.ps1
└── ExportGhidraAnalysis.java
linux/malware-analysis/
├── Dockerfile
├── entrypoint.py
├── evidence_ingest.py
└── tool-inventory.json
tests/
├── Test-AnalysisDifferencing.ps1
└── pester/AnalysisDifferencing.Tests.ps1
docs/
├── analysis-differencing.md
├── malware-analysis.md
├── Aliases.md
└── sample-outputs.md
```

**Structure Decision**: Extend the existing isolated engines and focused malware-analysis skill.
The general commands are public wrappers; there is no second execution or comparison engine.

## Requirement-to-Verification Plan

| Requirements | Implementation surface | Automated selector |
|---|---|---|
| REQ-001–REQ-006 | general Sandbox behavior wrappers over existing engine | `tests/Test-AnalysisDifferencing.ps1#Behavior*` |
| REQ-007–REQ-008 | two-input rootless container plan and safety policy | `#BinaryPlanning`, `#BinaryIsolation` |
| REQ-009–REQ-013 | Ghidra/BinExport/BinDiff artifacts and schema | `#GraphArtifacts`, `#GraphSafety`, `#GraphSchema` |
| REQ-014–REQ-016 | Ghidra record export and SQLite sidecar | `#QuerySchema`, `#BinaryReporting` |
| REQ-017 | bounded hostile-evidence ingestion | `#EvidenceBoundary` |
| REQ-018–REQ-019, REQ-022 | public commands, routing, dual-shell output | `#Interfaces`, `#Compatibility` |
| REQ-020–REQ-021 | case-oriented operator documentation | `#Documentation` plus strict MkDocs |

## Complexity Tracking

No constitution violations.
