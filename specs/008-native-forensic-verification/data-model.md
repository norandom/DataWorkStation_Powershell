# Data Model: Native Forensic EWF Verification

## ForensicToolRecord

An immutable catalog description of one runtime package revision.

| Field | Meaning |
|---|---|
| `SchemaVersion` | Catalog schema version. |
| `ToolId` | Stable logical identifier, initially `ewfverify`. |
| `UpstreamVersion` | Upstream libewf release identity. |
| `BuildRevision` | Repository build revision such as `b1`. |
| `ReviewState` | `Candidate`, `Approved`, `Withdrawn`, or `Superseded`. Only `Approved` is installable; `Superseded` remains attributable but is blocked from new installation. |
| `SupportedFormats` | Precisely certified EWF formats, versions, and segment rules. |
| `SourceArtifacts` | Source archive, detached signature/authenticity, digest, size, and origin records. |
| `BuildIdentity` | Toolchain, converter, workflow, runner, arguments, and build commit. |
| `ReleaseIdentity` | Immutable release tag, asset name, asset size, package SHA-256, attestation identity, and repository. |
| `PackageFiles` | Allowlisted internal paths with sizes, SHA-256 digests, PE architecture, and expected imports. |
| `ParserProfile` | Output grammar identity and accepted verifier version/banner. |
| `LicenseSummary` | Package licenses and included license paths. |
| `Certification` | Corpus version, lanes, workflow run, result, reviewed candidate/build digest, approval decision identity, reviewer, and timestamp. The containing Git commit is external provenance and is not self-referenced. |

Validation rules:

- A tuple of `ToolId`, `UpstreamVersion`, and `BuildRevision` is unique.
- An approved record has no floating URL, mutable branch, or incomplete digest.
- A withdrawn record stays addressable for historical reports but cannot be installed.
- A superseded record stays addressable for historical reports but cannot be newly installed.
- The release tag and asset name cannot be reused by a different record.

## ForensicArtifact

A source, dependency, build input, package, or internal package file.

Fields: artifact ID, role, origin URL/repository, version or full commit, file name, size, SHA-256, authenticity mechanism and result, local relative path, and license identity.

## BuildIdentity

Fields: repository build commit, workflow path and run ID, runner image, target architecture, compiler version, linker version, MSBuild version, Windows SDK version, converter commit, normalized input artifact IDs, normalized build arguments, and build timestamp in UTC.

The build identity changes whenever an input or effective build procedure changes. A changed build identity requires a new `BuildRevision`.

## InstalledToolState

| Field | Meaning |
|---|---|
| `ToolRecordId` | Approved catalog identity expected locally. |
| `InstallRoot` | Versioned per-user path under `%LOCALAPPDATA%\Programs\DataWorkStation\Forensics`. |
| `ObservedFiles` | Observed allowlisted paths, sizes, and SHA-256 digests. |
| `State` | `Absent`, `Compliant`, `Drifted`, or `Unapproved`. |
| `CheckedAtUtc` | Last state evaluation time. |

State transitions:

- `Absent -> Compliant`: explicit Ensure downloads and atomically installs an approved package.
- `Compliant -> Drifted`: any expected file changes, disappears, or an unexpected file appears.
- `Drifted -> Compliant`: explicit Ensure replaces the versioned installation from the approved package.
- `* -> Unapproved`: the installed identity is not approved or has been withdrawn.
- Ordinary workstation update may test/report these states but does not build a package.

## EvidenceSegment

Fields: ordinal, normalized display name, canonical path, extension, length, pre-verification SHA-256, post-verification length and SHA-256, and `Unchanged` boolean.

Paths are local report data and are never passed through expression evaluation. Segment records are ordered and unique.

## EvidenceSet

Fields: evidence-set ID, selected input segment, certified format/profile, ordered `EvidenceSegment` list, aggregate byte count, completeness result, ambiguity result, and media digest values reported/calculated by the verifier.

## VerificationRun

Fields: run ID, start/end UTC, host and PowerShell identity, status, verified boolean, tool-record identity, catalog-file SHA-256, nullable clean catalog commit, evidence set, exact argument vector, native exit code, parser profile/result, report path, warnings, and failure detail.

The catalog-file SHA-256 is always recorded. `CatalogCommit` is present only when the exact catalog
bytes can be resolved to a clean reviewed Git commit; release archives or dirty/unresolvable
worktrees record `null` plus a warning rather than inventing a commit identity.

State transitions:

```text
planned -> tool-validated -> evidence-locked -> pre-hashed
        -> verifier-finished -> post-hashed -> report-committed
```

Any transition may terminate with a non-success status. `verified` is possible only after `report-committed`, package integrity succeeds, the parser recognizes an upstream success, a stored digest matches, and every segment remains unchanged.

## VerificationReport

A report is a new immutable-by-convention directory containing:

- `report.json`: schema-conformant machine report
- `report.txt`: readable summary with limitations and status
- `stdout.bin` and `stderr.bin`: bounded raw native output
- `ewfverify.log`: upstream log when produced
- `artifacts.json`: sizes and SHA-256 digests of the other report artifacts

Files are created in a unique staging directory and renamed atomically to the run directory. Existing report directories are never overwritten.

## CertificationCorpus

Fields: corpus version, fixture IDs, documented source byte pattern, generator identity and arguments, segment file hashes and lengths, expected media digest, expected stored-digest result, supported format/profile, expected wrapper status, and derived negative-test recipes.

The corpus contains no case evidence. Derived corrupt or hostile fixtures exist only in test-temporary storage.
