# Feature Specification: Migrate Debian-MW to Podman

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-15

**Status**: Implemented and validated

**Input**: User description: "Replace the dedicated Debian-MW rootless Docker daemon with rootless,
daemonless Podman before continuing other workstation work. Preserve the supported malware-analysis
workflow without artificial runtime-specific aliases, align compatibility and cleanup decisions,
and keep dynamic execution in Windows Sandbox."

## Clarifications

### Session 2026-08-15

- Q: Should Debian-MW expose dedicated `podman-mw` or Docker-compatibility aliases? → A: No;
  preserve the malware-analysis commands and use generic `wsl-mw podman ...` for low-level access.
- Q: Should Debian-MW use a remote container endpoint or a local runtime? → A: Use Podman locally
  inside Debian-MW without SSH, a remote client, or a persistent API service.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inspect and migrate the analysis runtime safely (Priority: P1)

As a workstation operator, I can inspect the selected Debian-MW runtime and review the exact
migration impact before explicitly replacing its rootless Docker daemon with rootless Podman.

**Why this priority**: Runtime replacement changes packages and services at a security boundary and
must be observable, ordered, and recoverable.

**Independent Test**: Start from representative absent, Docker-only, Podman-ready, wrong-distro, and
partial-migration state records; verify that inspection is read-only, unsafe selections are blocked,
and an approved migration reaches a rootless daemonless-ready state without deleting legacy data.

**Acceptance Scenarios**:

1. **Given** Debian-MW currently has rootless Docker, **When** the operator runs the test or plan
   command, **Then** the output identifies both runtime states, the selected user and distribution,
   required privilege, package and service changes, retained data, and final readiness gate without
   changing the system.
2. **Given** the migration is explicitly requested, **When** Podman becomes ready as the selected
   non-root user, **Then** the old Docker user service and packages are decommissioned while its
   storage remains available for separately approved cleanup.
3. **Given** Podman provisioning or validation fails, **When** migration stops, **Then** existing
   Docker services, packages, and storage have not been decommissioned.

---

### User Story 2 - Run bounded static analysis with rootless Podman (Priority: P1)

As a malware analyst, I can plan and explicitly run the existing inert Office, PDF, and binary
parsers through rootless Podman in Debian-MW without granting the target network, device, host
namespace, engine-socket, or unrelated filesystem access.

**Why this priority**: Preserving the analysis boundary is the reason Debian-MW exists; a successful
runtime migration that weakens the gate is not acceptable.

**Independent Test**: Use repository-owned benign fixtures and synthetic unsafe runtime records to
verify that a ready rootless local Podman instance runs the complete static tool inventory, while
rootful, remote, networked, over-broad, or mismatched states fail before a parser reads the target.

**Acceptance Scenarios**:

1. **Given** the declared image and rootless local runtime are ready, **When** the operator confirms
   a static container run, **Then** exactly one target is mounted read-only, exactly one case output
   is writable, the root filesystem is read-only, privileges and resources are bounded, networking
   is disabled, and the existing evidence report is produced.
2. **Given** the runtime is rootful, remote, socket-served, mismatched, or not ready, **When** a run is
   requested, **Then** the workflow refuses before the target becomes accessible to any parser.
3. **Given** an analysis is only planned, **When** the operator reviews it, **Then** no container is
   started and no image is built, pulled, imported, or repaired.

---

### User Story 3 - Keep the human analysis interface stable (Priority: P2)

As an operator or automation author, I can continue using the malware planning, readiness, control,
run, report, and JSON interfaces without knowing which compatible rootless runtime implements them.

**Why this priority**: Runtime migration must not invalidate case handling, reports, or the
human-readable commands on which the analysis workflow and its focused skill rely.

**Independent Test**: Run the public commands in human and structured modes before and after the
migration against fixed fixtures; verify stable arguments, status meanings, evidence schemas,
nonzero gate failures, and cross-case comparison behavior.

**Acceptance Scenarios**:

1. **Given** an existing operator command or analysis consumer, **When** it plans, checks, runs, or
   reports a case after migration, **Then** its documented public arguments and structured evidence
   remain compatible except for runtime identity fields that now report Podman.
2. **Given** an operator needs low-level diagnosis, **When** they use the generic Debian-MW command
   boundary, **Then** they can invoke Podman directly without a dedicated runtime alias.
3. **Given** an operator tries a removed Docker-MW or Compose convenience command, **When** command
   discovery and documentation are inspected, **Then** neither command is advertised or routed.

---

### User Story 4 - Rebuild and compare a declared OCI analysis image (Priority: P2)

As a maintainer, I can explicitly rebuild the pinned static-analysis image under Podman, validate
its full tool inventory, and compare control and target cases only when their runtime and image
baselines are compatible.

**Why this priority**: Docker and Podman use separate local stores; a deliberate rebuild gives the
new backend a reviewable and reproducible baseline without trusting an opaque state transfer.

**Independent Test**: Starting without a Podman image, verify that analysis remains blocked until a
separate confirmed build succeeds, all declared tools pass inventory checks, and compatible cases
diff while runtime or image mismatches are reported as incompatible.

**Acceptance Scenarios**:

1. **Given** only the legacy Docker image exists, **When** Podman readiness is tested, **Then** image
   state is reported absent and no import or build occurs automatically.
2. **Given** the operator explicitly confirms the image operation, **When** the declared build and
   inventory checks succeed, **Then** its immutable image identity and tool fingerprint become the
   required baseline for subsequent cases.
3. **Given** two cases use different runtimes, image identities, tool inventories, or isolation
   policies, **When** comparison is requested, **Then** the mismatch is reported instead of
   presenting their output as a valid differential result.

### Edge Cases

- The configured malware distribution is absent, stopped, version 1, or resolves to the developer
  distribution.
- The selected malware user is root, lacks subordinate UID/GID ranges, or cannot use its local
  container storage.
- Podman is installed but reports rootful operation, remote-client operation, a running API service,
  an unexpected storage owner, or missing security support.
- Docker Desktop integration is accidentally enabled for Debian-MW.
- Podman becomes ready but decommissioning the old Docker package or user service fails part-way.
- Legacy Docker images or containers exist but no equivalent image exists in Podman's storage.
- The declared image is stale, untagged, mutable, partially built, or has a mismatched tool
  inventory.
- Existing case manifests identify Docker as the historical runtime while new cases identify
  Podman.
- A caller supplies Docker-only flags, Compose requests, an engine socket, host namespaces,
  devices, elevated privileges, network access, or mounts outside the case boundary.
- A WSL update changes namespace, storage-driver, cgroup, or seccomp behavior needed by the gate.
- Attacker-controlled output contains malformed JSON, excessive nesting, terminal control bytes,
  path traversal, symlinks, named pipes, or oversized files.

## Requirements *(mandatory)*

### Functional Requirements

- **REQ-001**: When the Debian-MW container state is tested, the workstation resource shall report the selected distribution, selected user, Docker state, Podman state, rootless state, service state, storage locations, migration impact, and terminal readiness without changing system state.
- **REQ-002**: Where Debian-MW static container analysis is selected, the workstation resource shall maintain a locally executing Podman runtime for the declared non-root analysis user.
- **REQ-003**: If the configured malware distribution or user violates the dedicated-environment boundary, then the workstation resource shall refuse migration and analysis before making the target accessible.
- **REQ-004**: While Debian-MW is ready for static analysis, the readiness gate shall verify that Podman reports rootless local operation for the selected non-root user.
- **REQ-005**: While Debian-MW is ready for static analysis, the workstation resource shall keep Podman's API service and socket disabled.
- **REQ-006**: While Debian-MW is ready for static analysis, the workstation resource shall exclude the distribution from Docker Desktop integration and developer-engine routing.
- **REQ-007**: When an analysis container is planned, the analysis workflow shall target Podman exclusively inside the configured Debian-MW distribution as the configured malware user.
- **REQ-008**: If runtime identity, rootless state, image identity, tool inventory, isolation policy, or case paths fail validation, then the analysis workflow shall refuse before any parser reads the target.
- **REQ-009**: When a static analysis container is run, the analysis workflow shall provide a read-only root, no network, dropped capabilities, no-new-privileges, explicit non-root identity, bounded processes, memory, CPU, temporary storage, and wall-clock duration.
- **REQ-010**: When a target case is run, the analysis workflow shall expose exactly one regular target file read-only and exactly one newly created case output location writable.
- **REQ-011**: If a caller requests an engine socket, host namespace, host device, privileged mode, network access, unsupported mount, Compose operation, or unapproved runtime argument, then the analysis workflow shall reject the run before starting a container.
- **REQ-012**: When analysis is planned or run, the analysis workflow shall avoid installing tools, importing runtime state, building images, pulling images, or repairing the environment.
- **REQ-013**: When the Podman analysis image is tested, the image resource shall verify immutable image identity, complete declared tool inventory, inventory fingerprint, and freshness without changing image state.
- **REQ-014**: When the Podman analysis image is explicitly ensured, the image resource shall build the declared OCI image locally and fail unless every baseline tool passes its inventory check.
- **REQ-015**: If only a legacy Docker image exists, then the image resource shall report the Podman image absent without importing Docker storage or treating the legacy image as ready.
- **REQ-016**: The malware-analysis interface shall preserve its documented planning, readiness, control, run, report, comparison, confirmation, human-output, structured-output, and exit-status contracts across the runtime migration.
- **REQ-017**: When a low-level runtime command is required, the operator documentation shall use the generic Debian-MW boundary followed by the native Podman command.
- **REQ-018**: The workstation command surface shall omit dedicated `podman-mw`, `docker-mw`, and malware-environment Compose aliases.
- **REQ-019**: When migration is explicitly ensured and Podman readiness succeeds, the workstation resource shall decommission the Debian-MW Docker user services and packages without deleting legacy Docker storage.
- **REQ-020**: If Podman provisioning or readiness fails, then the workstation resource shall leave the existing Debian-MW Docker services, packages, and storage available for recovery.
- **REQ-021**: Where legacy Docker storage cleanup is selected, the workstation resource shall show its resolved scope and require separate destructive confirmation before deletion.
- **REQ-022**: When a historical Docker case is read, the evidence workflow shall preserve its recorded runtime identity without rewriting it as a Podman case.
- **REQ-023**: If compared cases differ in runtime, image identity, tool inventory, or isolation policy, then the evidence workflow shall mark them incompatible for differential conclusions.
- **REQ-024**: When attacker-controlled parser output is ingested, the evidence workflow shall apply the existing bounded schema, encoding, depth, count, size, path, terminal-control, and file-type validation before displaying or correlating it.
- **REQ-025**: When the migration module is planned, the workstation DSL shall show its dependencies, privilege, destructive cleanup boundary, supported modes, and stable order before execution.
- **REQ-026**: When the Podman runtime or public commands change, the project shall update capability routing, module selection, operator documentation, sample output, and affected malware specification cross-references together.
- **REQ-027**: When migration validation runs, the project shall verify the state and public command contracts in every documented PowerShell runtime and lint the Debian automation before declaring the feature complete.
- **REQ-028**: While static analysis uses Podman, Windows Sandbox shall remain the only supported backend for executing a suspicious Windows file.

### Key Entities

- **Runtime state**: The selected Debian-MW distribution and user, installed engines, rootless and
  remote status, service/socket status, storage ownership, security support, and readiness result.
- **Migration plan**: The observational before-state, ordered intended changes, privilege boundary,
  retained data, cleanup exclusion, failure status, and expected after-state.
- **OCI analysis image baseline**: The declared image reference, immutable image identity, source
  fingerprint, complete tool inventory, inventory fingerprint, creation time, and readiness status.
- **Analysis case**: The existing static case record plus immutable runtime name/version, image
  identity, tool inventory, isolation fingerprint, role, timestamps, status, and retained evidence.
- **Legacy Docker state**: Packages, user services, images, containers, volumes, and storage path
  retained after migration until a separate cleanup is reviewed and confirmed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred percent of approved Debian-MW static-analysis runs use the selected
  non-root local Podman runtime, and zero use Docker, a remote endpoint, or a persistent API socket.
- **SC-002**: One hundred percent of rootful, remote, mismatched, networked, over-privileged, or
  out-of-bound test cases are rejected before any parser receives the target.
- **SC-003**: All existing public malware planning, readiness, control, report, comparison, human,
  structured, and exit-status compatibility tests pass after migration.
- **SC-004**: Repository-owned Office, PDF, and binary fixtures produce terminal results for every
  declared applicable tool under the rebuilt baseline, with zero silently omitted tools.
- **SC-005**: Test and plan operations cause zero package, service, image, container, storage, or
  evidence mutations.
- **SC-006**: A failed Podman migration causes zero decommissioning changes to the existing Docker
  runtime and zero deletion of legacy Docker data.
- **SC-007**: Command discovery and published documentation contain zero dedicated Podman-MW,
  Docker-MW, or malware Compose aliases after the breaking migration.
- **SC-008**: One hundred percent of this feature's normative requirements pass EARS syntax and are
  mapped to automated verification before implementation is declared complete.

## Local Validation

- On 2026-08-15, Debian-MW reported local rootless Podman 5.4.2 with overlay storage, seccomp,
  disabled Podman API units, no Docker command, packages, services, or repository, and retained
  legacy Docker user data.
- The explicitly approved local image build produced immutable image
  `7006a1c44104261d21eab7a9cc5a45952b0c0cd42100e3f5805964699a442746`; both its complete tool
  inventory fingerprint and reviewed build-input fingerprint matched the repository.
- Repository-owned RTF, PDF, and non-executable binary fixtures ran with networking disabled and
  `Execution=parsed-not-executed`. Every applicable tool produced an explicit state; PDF and binary
  cases completed, while RTF honestly remained partial because OOXML inventory is not applicable
  to its non-ZIP structure. All verdicts remained `undetermined`, and ignored local evidence was
  retained outside version control.
- The destructive legacy-data module was reviewed only in Plan and Test modes. Docker user data at
  `/home/mc/.local/share/docker` and `/home/mc/.docker` remains intact.

## Assumptions

- Debian-MW remains a clean, dedicated WSL 2 distribution used only for inert static analysis; it is
  not a general development environment.
- The distribution-maintained Podman package is the supported source for Debian-MW; a separate
  Podman machine, Windows remote client, SSH transport, Docker-compatible API service, and Compose
  provider are outside this feature.
- The existing rootless Docker image store is not portable state for this migration. The declared
  image is rebuilt from its reviewed source after Podman is ready.
- Legacy Docker storage is retained by default because deleting images, containers, or volumes is a
  distinct destructive action.
- Ordinary Windows Docker, Docker Desktop WSL integration for the developer Debian distribution,
  and Dagger migration are intentionally deferred to a separate feature.
- Existing Windows Sandbox dynamic-analysis behavior, network policy, and guest telemetry remain
  unchanged.
- This feature supersedes the Docker-specific Debian-MW runtime assumptions in feature 002 without
  weakening its static-analysis isolation, evidence, or non-verdict requirements.

## EARS requirements

Every normative requirement in this specification uses a stable `REQ-NNN` identifier, exactly one
`shall` obligation, and one of the ubiquitous, event-driven, state-driven, optional-feature, or
unwanted-behavior forms. Design choices and file paths remain in `plan.md`.
