# Feature Specification: PowerShell Test Framework

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-15

**Status**: Implemented

**Input**: User description: "Adopt Pester as the necessary PowerShell test framework, support parallel test-file execution, and preserve Windows PowerShell compatibility."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run the PowerShell suite with one command (Priority: P1)

A developer runs one documented command and receives an aggregated result for every discoverable
PowerShell test instead of manually coordinating independent assertion scripts.

**Why this priority**: A single reliable entry point is the foundation for local and CI testing.

**Independent Test**: Run the command against passing and deliberately failing synthetic tests;
verify complete discovery, readable output, and a reliable process exit code.

**Acceptance Scenarios**:

1. **Given** multiple discoverable test files, **When** the developer runs the default command, **Then** every selected test file is represented in one human-readable result.
2. **Given** one failing test, **When** the suite finishes, **Then** the command reports the failing test and returns a nonzero exit code.
3. **Given** a machine consumer, **When** structured output is requested, **Then** it receives a bounded summary with counts, duration, execution lane, and failures.

---

### User Story 2 - Use safe parallel execution (Priority: P1)

A developer on the modern PowerShell runtime can shorten the suite by executing independent test
files concurrently without allowing exclusive or state-changing tests to overlap.

**Why this priority**: The user explicitly needs a test framework that can run tests in parallel,
but workstation tests must retain visible safety boundaries.

**Independent Test**: Run synthetic independent files and one exclusive file with a small
concurrency limit; verify overlap only among eligible files and serial treatment of the exclusive
file.

**Acceptance Scenarios**:

1. **Given** eligible independent test files, **When** the modern-runtime lane runs, **Then** it executes files concurrently up to the configured bound.
2. **Given** a test marked exclusive, **When** the parallel lane runs, **Then** that file does not overlap another test file.
3. **Given** an unsupported parallel environment, **When** the command runs, **Then** it uses a sequential lane and explains the fallback.

---

### User Story 3 - Preserve compatibility validation (Priority: P2)

A developer can run the same discoverable contracts under inbox Windows PowerShell to detect
syntax and behavior regressions while the faster modern-runtime lane remains the default.

**Why this priority**: Repository commands that declare Windows PowerShell 5.1 support still need a
real compatibility gate.

**Independent Test**: Run the compatibility lane and verify sequential execution through the inbox
runtime, shared test discovery, aggregated results, and nonzero failure behavior.

**Acceptance Scenarios**:

1. **Given** the compatibility option, **When** the suite runs, **Then** the same compatible test contracts execute sequentially under Windows PowerShell.
2. **Given** a modern-runtime-only test, **When** the compatibility lane discovers it, **Then** the test is explicitly excluded or skipped rather than failing discovery ambiguously.

---

### User Story 4 - Maintain the framework as desired state (Priority: P2)

A workstation operator can inspect or repair the exact supported framework version separately from
running tests.

**Why this priority**: Test execution must not silently install or upgrade its own prerequisite.

**Independent Test**: Test absent, obsolete, correct, and newer-version inventories; verify that
inspection is observational and repair selects exactly the declared version.

**Acceptance Scenarios**:

1. **Given** an absent or wrong framework version, **When** state is tested, **Then** drift and the exact repair impact are reported without installation.
2. **Given** explicit repair, **When** the state is applied, **Then** both supported PowerShell runtimes resolve the exact declared version.

### Edge Cases

- A test process hangs or exceeds its declared timeout.
- Test output contains terminal control characters or excessive failure text.
- The requested concurrency exceeds a safe configured maximum.
- The modern and compatibility runtimes discover different test sets.
- The framework repository is unavailable during explicit repair.
- A test that can mutate live workstation state is accidentally eligible for parallel execution.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: When the PowerShell test command runs, the repository shall discover and execute every selected standard test file through one framework invocation.
- REQ-002: The PowerShell test command shall render human-readable output by default.
- REQ-003: When structured output is requested, the PowerShell test command shall return a bounded machine-readable summary of counts, duration, lane, and failures.
- REQ-004: If any selected test fails or cannot be discovered, then the PowerShell test command shall return a nonzero process exit code.
- REQ-005: While the modern-runtime lane is selected, the PowerShell test command shall execute eligible test files concurrently up to a declared finite limit.
- REQ-006: Where a test requires exclusive, live-state, or state-changing access, the PowerShell test command shall execute that test outside the concurrent batch.
- REQ-007: If parallel execution is unsupported, then the PowerShell test command shall run sequentially and report the fallback.
- REQ-008: When compatibility validation is selected, the PowerShell test command shall execute compatible tests sequentially under inbox Windows PowerShell.
- REQ-009: Where a test is incompatible with the selected runtime, the test suite shall identify the exclusion or skip explicitly.
- REQ-010: When test framework state is inspected, the workstation DSL shall report the selected version and drift without installing or upgrading software.
- REQ-011: When test framework state is explicitly ensured, the workstation DSL shall install exactly the declared release for both supported PowerShell module paths without requiring elevation.
- REQ-012: The PowerShell test command shall refuse to install, upgrade, or repair its framework dependency during a test run.
- REQ-013: When the active Podman and malware contract suites are migrated, the repository shall preserve their existing section-level traceability and observable assertions.
- REQ-014: The repository shall expose the human test command through its command reference and capability catalog.

### Key Entities

- **Test lane**: Runtime, concurrency mode, finite limit, compatibility scope, and fallback reason.
- **Test file**: Discoverable path, eligibility for concurrency, runtime compatibility, and logical selectors.
- **Test result**: Aggregate state, counts, duration, failures, skipped tests, and process outcome.
- **Framework state**: Declared version, resolved module paths, detected versions, and pending repair.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One documented command discovers 100% of the migrated Podman and malware contract files and returns one aggregate result.
- **SC-002**: With at least two eligible synthetic files, the modern lane demonstrates concurrent file execution without exceeding its declared limit.
- **SC-003**: 100% of exclusive tests are observed outside the concurrent batch.
- **SC-004**: A deliberately failing test produces a nonzero exit code and identifies its file and test name in both human and structured output.
- **SC-005**: The compatibility lane executes 100% of tests declared compatible with Windows PowerShell and explicitly accounts for every excluded test.
- **SC-006**: Inspection performs zero package or module changes, while explicit repair makes both supported runtimes resolve one declared framework version.

## Assumptions

- File-level parallelism is sufficient; individual tests within one file do not need concurrent execution.
- The existing section-based assertion scripts remain useful compatibility fixtures during gradual migration.
- Live integration, package installation, WSL mutation, and other exclusive tests remain sequential.
- PowerShell 7 is the default developer runtime and Windows PowerShell 5.1 is a compatibility lane.
- CI workflow changes beyond consuming the same human command are out of scope for this increment.
