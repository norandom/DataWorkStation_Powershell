# Feature Specification: Spec Feature Governance

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-17

**Status**: Draft

**Input**: User description: "Prevent a new workstation state capability from passing publication
when its dedicated Spec Kit specification, plan, tasks, or traceability were forgotten."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catch an unspecced state capability (Priority: P1)

As a contributor, I receive an actionable local failure when I add a workstation module or a
state-changing capability route without connecting it to a dedicated, complete feature directory.

**Why this priority**: This directly prevents the omission that occurred for Exploit Protection.

**Independent Test**: Validate synthetic catalogs containing a new module or state route with no
feature reference, an invalid reference, missing artifacts, and valid artifacts; only the complete
case passes and every failure names the declaration and missing condition.

**Acceptance Scenarios**:

1. **Given** a new non-grandfathered module or state route without a feature reference, **When**
   governance is tested, **Then** validation fails and identifies the declaration.
2. **Given** a declaration references a feature with any required artifact missing, **When**
   governance is tested, **Then** validation fails before publication.
3. **Given** a declaration references a complete feature whose final EARS gate passes, **When**
   governance is tested, **Then** the declaration is reported compliant.

---

### User Story 2 - Keep legacy scope explicit (Priority: P1)

As a maintainer, I can see which pre-existing modules and state routes are grandfathered and detect
any change to that exception boundary during review.

**Why this priority**: A vague or automatically expanding exception would let future capabilities
bypass the guard.

**Independent Test**: Compare the reviewed legacy declaration with its pinned membership identity,
then add, remove, duplicate, or rename an entry and verify that the reported identity changes or the
catalog relationship fails.

**Acceptance Scenarios**:

1. **Given** the reviewed legacy boundary, **When** governance is tested, **Then** every exception is
   unique, exists in the relevant catalog, and contributes to a stable reported fingerprint.
2. **Given** a new declaration is added to a catalog, **When** it is not already in the frozen
   legacy boundary, **Then** it must provide a dedicated feature reference rather than inheriting an
   exception.
3. **Given** the legacy membership changes deliberately, **When** the change is reviewed, **Then**
   both human and structured output make the changed fingerprint visible.

---

### User Story 3 - Run the guard before publication (Priority: P2)

As an operator or automated publisher, I can invoke one observational human command or its JSON
form, and the repository hook runs the same guard before accepting a commit.

**Why this priority**: A correct check only prevents regressions when it is part of the normal
publication path and remains directly runnable by a person.

**Independent Test**: Run human and JSON forms against the repository and a failing synthetic
fixture, verify output parity and exit behavior, and inspect the pre-commit and capability routes.

**Acceptance Scenarios**:

1. **Given** compliant catalogs and feature artifacts, **When** the human command is run, **Then** it
   reports the checked modules, routes, feature directories, legacy fingerprint, and final outcome.
2. **Given** the same state, **When** JSON is requested, **Then** it represents the same checks and
   outcome in a stable schema.
3. **Given** a governance violation is staged, **When** the publication hook runs, **Then** the hook
   fails without changing repository or workstation state.

### Edge Cases

- A feature reference uses an absolute path, parent traversal, alternate separator, or case variant.
- A feature directory contains spec and traceability files but lacks plan or tasks.
- A traceability file exists but the feature's final EARS gate fails.
- Two modules or routes refer to one legitimate shared feature.
- A module has no state-changing capability route, or a route aggregates several modules.
- A legacy entry is duplicated, absent from its catalog, or silently expanded.
- The EARS validator command is missing or returns malformed structured output.
- The working tree contains an unrelated untracked feature draft.

## Requirements *(mandatory)*

### Functional Requirements

- **REQ-001**: The repository shall provide one directly runnable observational feature-governance command with human output by default.
- **REQ-002**: When structured feature-governance status is requested, the command shall return the same checks and outcome as the human report in a stable schema.
- **REQ-003**: Where a workstation module is not present in the reviewed legacy boundary, the governance command shall require that module to declare a dedicated feature reference.
- **REQ-004**: Where a capability route exposes one or more state commands and is not present in the reviewed legacy boundary, the governance command shall require that route to declare a dedicated feature reference.
- **REQ-005**: When a dedicated feature reference is resolved, the governance command shall accept only a normalized repository-relative child of the `specs` directory.
- **REQ-006**: While a dedicated feature is validated, the governance command shall require `spec.md`, `plan.md`, `tasks.md`, and `traceability.toml` as regular files.
- **REQ-007**: When required feature artifacts exist, the governance command shall require the referenced feature to pass its final EARS validation gate.
- **REQ-008**: If a declaration, feature reference, artifact, or final gate is invalid, then the governance command shall return an actionable nonzero result naming the failed boundary.
- **REQ-009**: Where a module and capability route describe the same focused public state boundary, the governance command shall require their dedicated feature references to agree.
- **REQ-010**: The governance declaration shall enumerate the grandfathered module and state-route identities explicitly without automatically incorporating later catalog additions.
- **REQ-011**: When the reviewed legacy membership changes, the governance command shall expose its deterministic fingerprint in both human and structured output.
- **REQ-012**: While feature governance is tested, the command shall avoid writing files, changing workstation state, installing tools, or changing the active Spec Kit feature selection.
- **REQ-013**: Where repository commits are checked locally, the publication hook shall invoke the same human-readable feature-governance command.
- **REQ-014**: When the governance interface is introduced or changed, the project shall update capability routing, operator documentation, and representative human and structured output together.
- **REQ-015**: While unrelated working-tree files exist, feature-governance validation shall leave those files unchanged and exclude unreferenced feature drafts from its decision.

### Key Entities

- **Governed module**: A workstation module identity, optional dedicated feature reference, and
  membership or non-membership in the reviewed legacy boundary.
- **Governed state route**: A capability identity with state commands, optional dedicated feature
  reference, and membership or non-membership in the reviewed legacy boundary.
- **Dedicated feature reference**: A normalized repository-relative feature directory containing
  the four publication artifacts and a passing final EARS result.
- **Legacy boundary**: Explicit module and state-route identity lists plus their deterministic
  membership fingerprint.
- **Governance result**: Stable outcome, checked declaration counts, referenced features, legacy
  fingerprint, and actionable failures.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred percent of synthetic new modules and state routes without valid dedicated
  feature references fail before publication.
- **SC-002**: One hundred percent of referenced features missing any required artifact or failing
  final validation are rejected with the responsible declaration and condition named.
- **SC-003**: The compliant repository passes through both human and structured commands with zero
  file or workstation changes.
- **SC-004**: Human and structured results report identical checked counts, referenced features,
  legacy fingerprint, failures, and outcome.
- **SC-005**: The local commit hook rejects every injected governance violation exercised by the
  focused test suite.
- **SC-006**: One hundred percent of normative requirements pass EARS validation and have automated
  traceability before implementation begins.

## Assumptions

- The current pre-feature module and state-route identities may be grandfathered explicitly; this
  feature does not retroactively create dedicated specifications for every historical resource.
- `ExploitProtection` and `windows-exploit-protection` are not grandfathered because feature 011 is
  already complete and becomes the first governed pair.
- A future feature may legitimately own multiple modules or routes, but a paired module and route
  for the same public boundary must name the same feature.
- The existing `ears-sdd validate --feature <directory> --phase final` command is the authoritative
  deep artifact and traceability validator.
- The guard inspects only catalog-referenced features, so unrelated drafts such as feature 010 do
  not block commits until a module or state route declares them.

## EARS requirements

Every normative requirement above uses a stable `REQ-NNN` identifier, exactly one `shall`
obligation, and an EARS form. Implementation and file-layout detail belongs in the plan.
