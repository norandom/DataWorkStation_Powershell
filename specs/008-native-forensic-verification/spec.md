# Feature Specification: Native Forensic Tool Verification

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "Add native Windows forensic tools that remain version-pinned, hash-verified, precisely cataloged for reports, and begin with a command-line EWF verifier. Forensic tools must never use WSL or Linux."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Verify an EWF evidence set (Priority: P1)

As an examiner, I can verify a segmented EWF image with one readable Windows command and receive a
clear result without mounting the image or modifying evidence.

**Why this priority**: Evidence verification is useful only when the complete input set, calculated
digests, stored digests, errors, and tool identity are attributable to the same run.

**Independent Test**: Verify repository-owned valid, corrupted, incomplete, and hashless EWF
fixtures and confirm deterministic status, segment inventory, digests, exit behavior, and no input
writes.

The story-level test uses real, repository-owned EWF segment files and an injected deterministic
native-process result so the wrapper can be tested before a package is approved. The same fixtures
MUST run against the actual packaged verifier at the cross-story release gate before adoption.

**Acceptance Scenarios**:

1. **Given** a complete supported EWF segment set with matching stored media hashes, **When** verification completes, **Then** the human report identifies the set as verified and records every segment plus the calculated media digest.
2. **Given** one missing, duplicated, reordered, changed, or corrupt segment, **When** verification runs, **Then** the result is not reported as verified and the specific integrity gap is retained.
3. **Given** a valid EWF image without a stored comparison hash, **When** verification completes, **Then** calculated digests and internal checks remain available but the result does not claim a stored-hash match.

---

### User Story 2 - Produce a defensible verification report (Priority: P1)

As an examiner or reviewer, I can retain both readable and machine-readable reports that identify
the evidence, exact tool package, dependencies, command, timestamps, output, and outcome.

**Why this priority**: A bare success message cannot establish which executable interpreted the
evidence or whether the tool changed between examination and review.

**Independent Test**: Generate reports from a fixed fixture twice and confirm that evidence and
tool facts agree, volatile run fields remain attributable, hostile output is safely represented,
and the source evidence stays unchanged.

**Acceptance Scenarios**:

1. **Given** a completed verification, **When** the report is reviewed, **Then** it contains the version, provenance, hashes, dependency identities, invocation, UTC time range, segment inventory, comparison results, raw-output identity, status, and exit code.
2. **Given** machine-readable output is requested, **When** the same run is reported, **Then** it contains the same evidence and provenance facts as the default human output.
3. **Given** tool output containing control characters or evidence-derived text, **When** a report is displayed, **Then** the content cannot inject terminal control behavior or alter report structure.

---

### User Story 3 - Install a known forensic tool package (Priority: P1)

As a workstation maintainer, I can plan, install, and test a precisely cataloged native Windows
forensic tool package without trusting a floating download or an undeclared runtime.

**Why this priority**: The verification result is only as defensible as the identity and integrity
of the parser that produced it.

**Independent Test**: Exercise installation planning and validation with matching and deliberately
mismatched package, executable, dependency, source, and provenance records without parsing real
evidence.

The isolated story test uses an immutable-shaped synthetic package. Reuse of the actual published
package on this and another workstation is a cross-story release gate after verification and report
certification are complete.

**Acceptance Scenarios**:

1. **Given** a catalog entry and matching package, **When** installation is explicitly requested, **Then** every declared artifact is verified before the package becomes callable.
2. **Given** any missing or mismatched artifact, source identity, signature, binary hash, or dependency, **When** installation or execution is attempted, **Then** the operation fails closed and identifies the mismatch.
3. **Given** a compliant installation, **When** its state is tested later, **Then** silent replacement or dependency drift is detected without changing the installation.
4. **Given** an approved release package, **When** the same tool version is installed on another workstation, **Then** the published binary is reused without rebuilding it locally.

---

### User Story 4 - Review and upgrade forensic tooling (Priority: P2)

As a maintainer, I can compare a proposed forensic-tool release with the approved catalog entry,
review changed provenance and format support, and certify it before any workstation adopts it.

**Why this priority**: Automatic upgrades would make old reports difficult to reproduce and could
silently change parser behavior.

**Independent Test**: Present a synthetic newer package and confirm that normal workstation update
reports availability without installing it, while an explicit reviewed catalog change requires the
compatibility corpus to pass.

**Acceptance Scenarios**:

1. **Given** a newer upstream version, **When** ordinary update or drift correction runs, **Then** the installed forensic version remains unchanged and the candidate is reported for review.
2. **Given** a proposed catalog update, **When** certification fixtures contain valid, corrupt, incomplete, and unsupported inputs, **Then** approval is blocked unless every expected result and report contract passes.
3. **Given** an old verification report, **When** it is reviewed after a tool upgrade, **Then** the exact historical tool and dependency identities remain unambiguous.
4. **Given** a necessary rebuild with unchanged upstream source, **When** a dependency, compiler, build recipe, or security correction changes, **Then** a new build revision is published without replacing the previous release asset.

### Edge Cases

- The operator supplies the first segment, a later segment, all segments, mixed-case extensions, or a path containing spaces and non-ASCII characters.
- Segment numbering has a gap, duplicate, unexpected suffix, conflicting basename, or inconsistent size.
- An input is sparse, locked, on read-only media, changes during verification, or becomes unavailable.
- The evidence contains bad chunk checksums, a mismatching stored digest, no stored digest, or several stored digest types.
- The image uses an unsupported EWF family feature, compression method, encryption mode, logical-image layout, or damaged metadata.
- The verifier exits unsuccessfully after producing partial output or reports success while wrapper-level evidence checks fail.
- The tool executable, one companion library, or the catalog changes between preflight and execution.
- A release asset, adjacent checksum file, repository catalog digest, or provenance attestation disagrees with another identity source.
- A report destination is missing, full, read-only, inside the evidence set, or already contains a report with the same run identity.
- Tool output contains invalid encoding, extremely long fields, escape sequences, or misleading success-like text.
- Verification is attempted while WSL, a Linux container runtime, or a Unix compatibility layer is the only available execution path.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: When an operator requests EWF verification, the workstation shall expose a documented human-readable native Windows command before any agent orchestration.
- REQ-002: While any forensic-tool operation is planned, installed, tested, or executed, the workstation shall exclude WSL, Linux containers, Cygwin, MSYS, MSYS2, MinGW runtimes, and Git Bash from the execution path.
- REQ-003: When EWF verification is planned, the workstation shall identify the evidence inputs, report destination, selected tool record, and all operations without reading media data or changing system state.
- REQ-004: While EWF evidence is verified, the workstation shall open every evidence segment without write access and leave its content, metadata, name, and location unchanged.
- REQ-005: When an EWF input is accepted, the workstation shall derive and retain one deterministic ordered inventory of the complete segment set.
- REQ-006: If the segment set is missing, duplicated, conflicting, or changes during verification, then the workstation shall refuse a verified outcome and identify the affected segment.
- REQ-007: When verification starts and ends, the workstation shall calculate and compare a SHA-256 digest for every physical evidence segment.
- REQ-008: When media verification runs, the workstation shall calculate an additional SHA-256 digest over the represented media data and retain every available stored-versus-calculated digest comparison.
- REQ-009: If the evidence has no supported stored comparison digest, then the workstation shall distinguish successful reading and checksum processing from a stored-hash match.
- REQ-010: If the evidence uses an uncertified format feature, then the workstation shall return an unsupported result without claiming integrity verification.
- REQ-011: When verification invokes a parser, the workstation shall retain the exact command arguments, UTC start and end times, process exit code, and cryptographic identities of its standard output and standard error.
- REQ-012: When a verification report is produced, the workstation shall include the tool version, tool-package identity, executable and dependency hashes, source provenance, evidence inventory, digest results, warnings, and final status.
- REQ-013: When machine-readable reporting is requested, the workstation shall return bounded structured output containing the same evidence, provenance, and outcome facts as the default human report.
- REQ-014: When evidence-derived or tool-derived text is rendered, the workstation shall neutralize terminal control sequences and preserve the original bytes through a separately identified bounded artifact.
- REQ-015: When a forensic tool is cataloged, the catalog shall record its version, supported formats, source identity, source hash, authenticity evidence, build provenance, package hash, executable hashes, dependency hashes, license, and review state.
- REQ-016: When a forensic-tool installation is explicitly requested, the workstation shall verify every cataloged package and file identity before exposing its commands for use.
- REQ-017: If installed forensic-tool content or provenance differs from its catalog entry, then the workstation shall refuse evidence processing and report tool-integrity failure.
- REQ-018: While ordinary workstation update or drift correction runs, the workstation shall keep each approved forensic-tool version fixed and report newer candidates without adopting them.
- REQ-019: When a forensic-tool version change is proposed, the workstation shall require explicit catalog review and successful compatibility certification before adoption.
- REQ-020: When compatibility certification runs, the workstation shall cover valid, corrupt, incomplete, hashless, unsupported, and hostile-output fixtures without using case evidence.
- REQ-021: When a historical verification report is reviewed, the report shall identify enough immutable tool, dependency, source, and evidence facts to distinguish its run from every cataloged version.
- REQ-022: While evidence verification runs, the workstation shall require no network service and initiate no network communication.
- REQ-023: If report persistence fails or would overwrite an existing report, then the workstation shall return a non-verified outcome without altering the existing report.
- REQ-024: When public forensic commands or evidence types change, the workstation shall update human documentation and capability routing before focused skill orchestration.
- REQ-025: When either supported PowerShell runtime plans, tests, or reports forensic verification, the workstation shall expose equivalent evidence and provenance facts.
- REQ-026: When a forensic-tool build is approved, the repository shall publish one immutable versioned native Windows package with its manifest, checksums, licenses, and provenance evidence as release assets.
- REQ-027: While an approved tool version and build revision remain current, the workstation shall install the pinned release package without rebuilding its binaries locally or during automation.
- REQ-028: If any source, dependency, compiler, build recipe, build option, or security correction changes, then the repository shall assign a new build revision and preserve every previously published package unchanged.
- REQ-029: When a release package is cataloged, the repository shall independently pin its release tag, asset name, size, SHA-256 digest, and provenance identity in reviewed source history.

### Key Entities

- **ForensicToolRecord**: Immutable approved identity, provenance, supported formats, license, review state, package, executables, and dependencies for one tool version.
- **ForensicArtifact**: One source archive, package, executable, or runtime dependency with its role, origin, size, digest, and authenticity evidence.
- **InstalledToolState**: Observed filesystem identities and command resolution compared with one approved tool record.
- **EvidenceSet**: Deterministically ordered EWF segments, preflight and completion identities, supported-format assessment, and read-only state.
- **VerificationRun**: One attributable invocation with timing, command, parser result, wrapper checks, warnings, and status.
- **VerificationReport**: Human and structured representations plus bounded raw artifacts that preserve the run's evidence and provenance facts.
- **CertificationCorpus**: Public or repository-owned non-case fixtures with expected outcomes used to approve a tool version and its report behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- SC-001: One hundred percent of forensic execution paths remain native to Windows and contain no WSL, Linux-container, or Unix-compatibility fallback.
- SC-002: One hundred percent of successful installations match every cataloged package, executable, and dependency digest before the command becomes available.
- SC-003: One hundred percent of verification reports identify every evidence segment and the exact tool package and dependency set used.
- SC-004: One hundred percent of verified outcomes have matching pre-run and post-run SHA-256 identities for all physical evidence segments.
- SC-005: Valid, corrupt, incomplete, hashless, unsupported, and hostile-output fixtures each produce their documented deterministic status and nonzero behavior where verification is not established.
- SC-006: Human and structured reports expose equivalent evidence, provenance, comparison, warning, and outcome facts for all certification fixtures.
- SC-007: Ordinary update and drift-correction operations adopt zero unreviewed forensic-tool versions.
- SC-008: Reviewers can determine the exact evidence set and toolchain used by a historical report without access to the originating workstation.
- SC-009: PowerShell 7 and Windows PowerShell 5.1 produce equivalent plan, test, and report facts for the certification corpus.
- SC-010: All repository publication gates pass without accessing case evidence or starting a Linux-backed execution path.
- SC-011: One hundred percent of workstation installations consume an immutable cataloged release package and perform zero local forensic-binary builds.
- SC-012: Rebuilding any changed input produces a distinct attributable build revision while retaining one hundred percent of historical release packages.

## Assumptions

- The first cataloged capability verifies EWF media; acquisition, mounting, export, recovery, and evidence modification are separate future features.
- Classic segmented E01 is the initial required format. Other EWF families or features remain unsupported until individually certified and recorded.
- The selected verifier is the upstream `ewfverify` capability from libewf, packaged as a native Windows build; exact build design belongs in planning.
- Stored MD5 or SHA-1 values remain evidence-format facts rather than modern trust anchors, so reports additionally retain SHA-256 identities.
- Native tool packages are attached to immutable GitHub Releases in this repository rather than committed as executable blobs in ordinary Git history.
- A package is built once for an approved upstream version and build revision, then reused by every installation; installation and ordinary update never rebuild it.
- A changed dependency, compiler, recipe, option, or security correction creates a new build revision even when the upstream tool version is unchanged.
- Release manifests and checksum files accompany the package, while the independently reviewed catalog in Git remains the bootstrap trust anchor.
- A "newer candidate" means an explicit `Candidate` record already present in the reviewed Git
  catalog. Ordinary workstation update does not query upstream projects or GitHub for forensic-tool
  versions.
- Reports are written outside the evidence set and never replace an existing report implicitly.
- Verification is an integrity observation, not a claim about lawful acquisition, chain-of-custody completeness, evidentiary meaning, or absence of malicious content.
