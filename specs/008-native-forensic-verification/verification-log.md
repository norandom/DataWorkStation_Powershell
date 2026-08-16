# Native forensic verification log

This log records implementation gates that are useful to review but should not
be inferred from a green final test run. Commands were run from the repository
root on native Windows. No WSL or container runtime was used.

## 2026-08-16: foundational red baseline (T004)

### Contract schemas

Both JSON contracts passed `jsonschema.Draft202012Validator.check_schema`:

- `contracts/ewf-verification-plan.schema.json`
- `contracts/ewf-verification-report.schema.json`

### Fixture corpus

`CertificationCorpus` passed 25 assertions in PowerShell 7.6.4 and Windows
PowerShell 5.1.26100.9168. The assertions imported `expected.psd1`, checked all
six segment lengths and SHA-256 values, checked both three-segment inventories,
and rejected committed executables or build output.

Pinned native `ewfverify` 20231119 also read all 2,621,440 media bytes from
both sets and calculated MD5 `91d8ae3beabcd4f8469a2fcb8055ba14`:

| Fixture | Exit | Stored MD5 | Result at this gate |
| --- | ---: | --- | --- |
| `ordinary.E01` | 0 | `91d8ae3beabcd4f8469a2fcb8055ba14` | readable; stored and calculated MD5 match |
| `hashless.E01` | 0 | `N/A` | readable; deliberately not an integrity verdict |

### Selector baseline

Every selector was invoked separately in both PowerShell lanes so one expected
failure could not hide another. Both lanes produced the same state:

- PASS: `ReportContract`, `UpdatePolicy`, `CertificationCorpus`
- EXPECTED FAIL, `scripts/Invoke-EwfVerification.ps1` not yet present:
  `HumanInterface`, `Planning`, `EvidenceReadOnly`, `SegmentInventory`,
  `SegmentIntegrity`, `MediaDigests`, `HashlessEvidence`, `InvocationEvidence`,
  `JsonParity`, `HostileOutput`, `OfflineExecution`, `ReportPersistence`, and
  `RuntimeCompatibility`
- EXPECTED FAIL, `scripts/Build-NativeForensicTool.ps1` not yet present:
  `NativeWindowsBoundary`, `ReleasePackageContract`
- EXPECTED FAIL, `config/forensic-tools.psd1` not yet present:
  `FormatCertification`, `CatalogSchema`, `HistoricalAttribution`,
  `ReleaseTrustAnchor`
- EXPECTED FAIL, `scripts/Set-NativeForensicToolsState.ps1` not yet present:
  `InstallIntegrity`, `ToolDrift`, `InstallWithoutBuild`
- EXPECTED FAIL, `.github/workflows/forensic-tool-build.yml` not yet present:
  `UpgradeCertification`
- EXPECTED FAIL, `docs/ewf-verification.md` not yet present:
  `DocumentationRouting`
- EXPECTED FAIL, `scripts/Publish-NativeForensicTool.ps1` not yet present:
  `BuildRevisionPolicy`

This is the intended red baseline. Production implementation starts only after
these failures are visible in both supported runtimes.

## 2026-08-16: EWF verification MVP (T009-T014)

The direct verifier and the thin `ewf-verify` profile command passed the US1
runtime selectors separately in PowerShell 7.6.4 and Windows PowerShell
5.1.26100.9168. Each lane passed `HumanInterface`, `NativeWindowsBoundary`,
`Planning`, `EvidenceReadOnly`, `SegmentInventory`, `SegmentIntegrity`,
`MediaDigests`, `HashlessEvidence`, `FormatCertification`,
`InvocationEvidence`, `OfflineExecution`, and `RuntimeCompatibility`.

The tests used copied benign fixtures, an injected native-process result, and
synthetic catalog/package state. They proved plan-only behavior, held read-only
segment handles, deterministic segment ordering, pre/post identities, bounded
outcomes, exact invocation facts, and the same profile script resolution in
both shells. No package was installed, no network operation ran, and no report
was persisted at this gate. `DocumentationRouting` remains deliberately red
until T047-T048 add the human documentation before AI routing.

## 2026-08-16: defensible-report red gate (T015-T017)

The expanded `ReportContract`, `JsonParity`, `HistoricalAttribution`,
`InvocationEvidence`, `HostileOutput`, and `ReportPersistence` selectors failed
individually in both PowerShell lanes before report implementation. The failures
exposed the missing committed-report path and source attribution, missing
source-stream identities and bounds, and missing atomic staging behavior. The
hostile fixture is generated only below the test temporary root and includes
invalid UTF-8, terminal controls, a long field, and a misleading success-like
condition; none of it is executed or written to the console.

## 2026-08-16: defensible-report implementation gate (T018-T022)

Both report schemas passed the JSON Schema 2020-12 meta-schema check after the
report contract gained an explicit committed directory, source provenance, and
separate retained-artifact versus complete-source-stream identities.

The 17 US1/US2 selectors passed twice as direct contracts and twice through the
tagged Pester adapter in PowerShell 7.6.4 and Windows PowerShell 5.1.26100.9168:
17 passed, 0 failed, and 11 later-phase tests were not selected in each Pester
run. Focused PSScriptAnalyzer lint also passed for the five implementation,
profile, helper, contract, and adapter files.

Stable normalized facts were equal across repeat runs: status, tool version and
build revision, catalog/package/file/source hashes, segment ordinals, lengths,
pre/post SHA-256 values, digest comparisons, parser profile, exit code,
warnings, and failure facts. Expected volatile facts were distinct run IDs,
report directories, UTC timing/host runtime facts, and the exact upstream-log
path in the retained argument vector.

The hostile-output test retained exactly 1,048,576 bytes, marked truncation,
matched the retained file SHA-256, and separately matched the complete source
length and SHA-256. Invalid UTF-8, CSI controls, NUL, and misleading text were
not rendered unsafely. Atomic-commit tests covered a duplicate run ID, injected
disk-full and access-denied failures, a destination inside the evidence tree,
and a non-directory destination. Existing reports stayed byte-identical and no
staging directory survived. Every fixture segment's pre/post identity remained
equal in both passes.

## 2026-08-16: native-package lifecycle red gate (T023-T025)

`NativeWindowsBoundary`, `CatalogSchema`, `ReleaseTrustAnchor`,
`InstallIntegrity`, `ToolDrift`, `ReleasePackageContract`, and
`InstallWithoutBuild` each failed independently in both PowerShell lanes before
the runtime catalog, installer, candidate inspector, builder, or workflow
existed. The synthetic cases cover approved-only selection, all four installed
states, traversal and extra entries, package/file drift, atomic rollback, full
source/build/release attribution, native PE/import policy, and zero runtime
compilation. No package was downloaded, installed on the workstation, or built.

## 2026-08-16: native-package lifecycle implementation gate (T026-T034)

The complete US3 selector set passed independently in PowerShell 7.6.4 and
Windows PowerShell 5.1.26100.9168: `NativeWindowsBoundary` (9 assertions),
`CatalogSchema` (22), `ReleaseTrustAnchor` (9), `InstallIntegrity` (28),
`ToolDrift` (29), `ReleasePackageContract` (19), and `InstallWithoutBuild` (8).

Synthetic `Plan`, `Test`, and `Ensure` cases covered approved-only selection,
safe archive extraction, exact file allowlisting, mismatched hashes, path
traversal, package and installed-file drift, and rollback after an injected
post-commit validation failure. The previous installation was restored
byte-for-byte, with no staging or rollback directory left behind. A separate
pre-invocation hook changed an installed file after initial validation; the
verifier detected that change at the final integrity gate and did not invoke
the native process.

The module planner selected `PowerShell7`, `PowerShellProfile`, then the
non-default `NativeForensicTools` module. Runtime installation consumed only a
release-shaped package and contained no compiler or build invocation. Build and
workflow checks remained plan/static-only: no native package was compiled,
downloaded, installed on the workstation, or published at this gate.

## 2026-08-16: review-and-upgrade local gates (T035-T041)

The expanded `UpdatePolicy`, `UpgradeCertification`, `CertificationCorpus`,
`HistoricalAttribution`, `BuildRevisionPolicy`, and `ReleaseTrustAnchor`
selectors first failed independently in both PowerShell lanes. The failures
identified candidate reporting, complete negative-corpus recipes, exact catalog
commit attribution, the missing publish boundary, and replaceable general
release uploads.

After implementation, the six selectors passed independently in PowerShell
7.6.4 and Windows PowerShell 5.1.26100.9168. The derived corpus contains valid,
corrupt, incomplete, hashless, unsupported, hostile-output, and
persistence-failure cases below test-temporary storage; all committed fixture
hashes remained unchanged. Candidate validation requires all seven results in
both lanes and fails closed when even one result is omitted or mismatched.

Ordinary update reports only cataloged `Candidate` records and leaves the
approved record pinned. The plan-first publication boundary requires clean Git
state, exact catalog blob/commit identity, a matching approved build-record
digest, an existing draft asset, candidate certification, and attestation
verification. Both forensic and general release workflows contain no clobber
path and validate a draft before publication.

No external release task ran. Repository immutability, candidate build,
approval, publication, and local package installation remain T042-T046 and
require separate explicit confirmation.

## 2026-08-16: local final-gate checkpoint (T047-T049; T050 pending)

The complete dependency-free feature suite passed 463 assertions in PowerShell
7.6.4 and 463 assertions in Windows PowerShell 5.1.26100.9168. The Pester 6.1.0
adapter passed 28 of 28 cases in each lane (parallel in PowerShell 7, sequential
in the compatibility lane). Synthetic publication tests covered a read-only
ready plan, refusal without explicit confirmation, and one confirmed transition
with injected Git and GitHub boundaries; no external command ran.

Additional local gates passed:

- focused PSScriptAnalyzer 1.25.0: 18 files, no findings;
- actionlint: all three affected workflows;
- workstation update regression: 230 assertions;
- workstation baseline regression: 2,214 assertions;
- PowerShell testing regression: 83 assertions;
- Tricky human and JSON capability smoke: 27 routes, including the forensic
  route;
- focused skill official validation and repository-wide skill validation;
- JSON Schema 2020-12 meta-validation for plan and report contracts;
- strict locked MkDocs build;
- EARS/TDD final validation: 29 requirements, 0 errors, 0 warnings;
- `git diff --check`.

T050 is not complete because its native candidate-certification clause depends
on the real draft package from T043-T046. T051 likewise remains open until the
external evidence closes those requirements. No GitHub setting, workflow
dispatch, catalog approval, release publication, or local package installation
was performed.
