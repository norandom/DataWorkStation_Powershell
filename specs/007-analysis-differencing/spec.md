# Feature Specification: General Sandbox and Binary Differencing

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-15

**Status**: Approved for implementation

**Input**: User description: "Make the clean-versus-target Windows Sandbox behavior diff available for general use, expand the static-analysis cases, retain queryable disassembly and decompilation, and add graph-based Ghidra binary diffing without falling back to raw byte or text version comparison."

> This feature extends [002-is-this-malware](../002-is-this-malware/spec.md). Its isolation,
> confirmation, hostile-evidence, bounded-ingestion, and non-verdict requirements remain normative.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compare general Sandbox behavior (Priority: P1)

As an operator, I can run a policy-matched clean control and target in Windows Sandbox and compare
their process, file, registry, handle, and available network observations without using
malware-specific command names.

**Why this priority**: Differential behavior is useful for installers, developer tools, and unknown
programs as well as malware triage.

**Independent Test**: Plan control and target cases for a repository-owned benign fixture, verify
identical policy and distinct execution roles, then compare synthetic completed evidence without
launching Windows Sandbox.

**Acceptance Scenarios**:

1. **Given** a supported executable or script, **When** a general behavior target is planned, **Then** no host or guest process starts and the reviewable Sandbox plan is returned.
2. **Given** matching completed control and target cases, **When** the general behavior comparison runs, **Then** it retains canonical evidence trees and a standard unified diff.
3. **Given** missing Sandbox or execution confirmation, **When** execution is requested, **Then** no Sandbox or target starts.

---

### User Story 2 - Compare binary structure and code (Priority: P1)

As an analyst, I can compare a baseline binary with a candidate using analyzed call graphs and
control-flow graphs, inspect matched and unmatched functions, and query retained results without
executing either binary.

**Why this priority**: Raw byte or decompiled-text comparison loses structural relationships and is
not an adequate substitute for patch or variant analysis.

**Independent Test**: Use two repository-owned synthetic binaries to validate a plan, isolation
arguments, graph-export artifacts, a queryable semantic-match database, bounded summary fields,
and explicit partial or missing-tool states.

**Acceptance Scenarios**:

1. **Given** two supported binaries, **When** binary differencing completes, **Then** each binary has an analyzed graph export and the pair has a queryable semantic-match database.
2. **Given** structurally matched functions at different addresses, **When** results are reviewed, **Then** the match retains similarity, confidence, graph counts, and both addresses.
3. **Given** unmatched or changed functions, **When** results are reviewed, **Then** added, removed, and changed functions remain distinguishable.
4. **Given** a missing graph exporter or matching engine, **When** analysis runs, **Then** the workflow reports a partial or missing-tool result rather than substituting a raw byte or text diff.

---

### User Story 3 - Query static analysis evidence (Priority: P2)

As an analyst, I can query disassembly, function metadata, instructions, graph relationships, and
best-effort decompiled code by stable binary role and address while retaining the original
graph-diff database unchanged.

**Why this priority**: SQL makes large static results practical for human and agent investigation,
but derived storage must not corrupt or redefine the primary graph match.

**Independent Test**: Import bounded synthetic exporter records into a database, run documented
queries for functions, calls, instructions, and decompiled code, and verify malformed or excessive
records fail closed.

**Acceptance Scenarios**:

1. **Given** completed static analysis, **When** the query database is opened, **Then** functions, instructions, calls, and decompiled code can be selected by binary role and address.
2. **Given** a decompiler failure for one function, **When** that function is queried, **Then** its failure state is retained without fabricated code.
3. **Given** a graph-diff result and query sidecar, **When** a matched function is queried, **Then** the match can be related to both binaries' static records by address.

---

### User Story 4 - Choose the correct static-analysis case (Priority: P2)

As an operator, I can choose bounded host inspection, isolated single-binary analysis, graph-based
binary comparison, document dissection, or dynamic Sandbox behavior from concrete documented
examples and understand the evidence and limitations of each.

**Why this priority**: A capable toolchain is unsafe and frustrating when users cannot tell which
boundary or result answers their question.

**Independent Test**: Build the documentation strictly and verify that every public command,
expected artifact, approval boundary, and representative query appears in the command reference
and static-analysis case guide.

**Acceptance Scenarios**:

1. **Given** a static-analysis goal, **When** the case guide is consulted, **Then** it identifies the narrowest applicable command and isolation boundary.
2. **Given** a binary-diff case, **When** the guide is consulted, **Then** it explains graph matching, queryable sidecars, partial results, and why raw versions are not the primary comparison.

### Edge Cases

- The two inputs are identical, different architectures, stripped, packed, malformed, or exceed bounds.
- One Ghidra analysis succeeds while the other fails or times out.
- Functions move addresses, split, merge, inline, or disappear between binaries.
- A graph matcher reports low confidence or ambiguous matches.
- Decompiled code is unavailable even though disassembly and graph export succeed.
- Generated SQLite, graph exports, logs, or Markdown contain hostile strings or terminal controls.
- A user supplies the same case as both sides of a behavior or binary comparison.
- A general behavior target is a document or unsupported interpreter type.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: When general Sandbox behavior is requested, the workflow shall expose a human-readable plan command that does not use malware-specific terminology.
- REQ-002: When a general behavior control and target are planned, the workflow shall preserve matching duration, network, telemetry, tool, isolation, and guest-close policies.
- REQ-003: If Sandbox or target-execution confirmation is absent, then the general behavior workflow shall refuse the corresponding launch.
- REQ-004: When a general behavior control runs, the workflow shall collect background evidence without reading or invoking the target.
- REQ-005: When compatible general behavior cases are compared, the workflow shall retain bounded canonical evidence trees and a standard unified diff.
- REQ-006: If a general behavior target is a document or unsupported executable type, then the workflow shall refuse execution and direct the operator to static analysis.
- REQ-007: When binary differencing is planned, the workflow shall accept exactly one regular baseline file and one regular candidate file and map both read-only into the dedicated static isolation boundary.
- REQ-008: When binary differencing runs, the workflow shall keep networking disabled without executing either binary or extracted content.
- REQ-009: When either binary is analyzed, the workflow shall retain its call-graph and control-flow-graph export with source hash and tool provenance.
- REQ-010: When graph exports are available for both binaries, the workflow shall use structural graph matching as the primary comparison and retain a queryable semantic-match database.
- REQ-011: When graph matching completes, the workflow shall report overall similarity and confidence plus matched, changed, added, removed, and ambiguous function counts.
- REQ-012: Where a graph matcher is unavailable, fails, or times out, the workflow shall expose the gap without substituting raw byte, version-string, or decompiled-text comparison as the primary result.
- REQ-013: When a semantic function match is retained, the workflow shall preserve both addresses, names when available, similarity, confidence, matching method, and matched graph counts.
- REQ-014: When static query data is produced, the workflow shall retain functions, instructions, basic blocks, graph edges, calls, decompilation state, and best-effort decompiled code keyed by binary role and address.
- REQ-015: When query data is related to graph matches, the workflow shall keep the original graph-match database unchanged and store derived query relationships in a separate sidecar.
- REQ-016: If static export or decompilation is partial, unsupported, failed, or timed out, then the workflow shall retain per-binary and per-function completion states without fabricating records.
- REQ-017: When static results reach the host, the workflow shall treat databases, graph exports, source-like text, logs, and summaries as hostile evidence and expose only bounded validated summaries by default.
- REQ-018: When machine-readable general behavior or binary-diff output is requested, the workflow shall return bounded JSON with the same facts as the default human output.
- REQ-019: When public differencing commands change, the workflow shall update capability routing before focused skill orchestration.
- REQ-020: When static-analysis documentation is built, the guide shall cover bounded host triage, document dissection, single-binary disassembly, best-effort decompilation, SQL queries, graph-based binary comparison, and dynamic behavior comparison.
- REQ-021: When graph-based binary comparison is documented, the guide shall distinguish structural matching, queryable code sidecars, and raw text or byte comparison limitations.
- REQ-022: When either supported PowerShell runtime plans or reports analysis, the workflow shall return equivalent evidence facts.

### Key Entities

- **BehaviorPair**: Matched control and target Sandbox cases plus comparison status and policy fingerprints.
- **BinaryDiffCase**: Baseline and candidate identities, static isolation policy, tool provenance, artifacts, completion states, and non-verdict status.
- **GraphExport**: One binary's call graph, control-flow graphs, functions, instructions, and source identity.
- **SemanticMatchDatabase**: Immutable graph matcher output containing pair-level and address-level similarity evidence.
- **StaticQuerySidecar**: Derived query database that relates per-binary static records to semantic matches without altering them.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- SC-001: One hundred percent of general behavior plans start no host or guest target process.
- SC-002: One hundred percent of unconfirmed general behavior launches are refused before Windows Sandbox starts.
- SC-003: One hundred percent of successful binary comparisons retain two graph exports and one queryable semantic-match database.
- SC-004: One hundred percent of binary-comparison reports identify the primary comparison as structural graph matching rather than raw version, byte, or decompiled-text comparison.
- SC-005: One hundred percent of partial tool and per-function outcomes remain explicit in human and JSON reports.
- SC-006: Representative function, instruction, call, decompiled-code, and changed-function queries return deterministic results for repository fixtures.
- SC-007: The new plan and report commands expose equivalent facts in PowerShell 7 and Windows PowerShell 5.1.
- SC-008: Strict documentation build and all repository publication gates pass without launching unapproved analysis.

## Assumptions

- "Binary diff" means structural comparison of two supplied binaries, normally an older baseline and newer candidate.
- Graph matching remains authoritative; code and disassembly SQL are investigative sidecars.
- The dedicated rootless `Debian-MW` static container is the preferred binary-diff backend because both inputs are parsed but never executed.
- Windows Sandbox remains the execution backend for general behavior observation.
- Tool installation or image rebuild remains a separate explicit desired-state operation.
