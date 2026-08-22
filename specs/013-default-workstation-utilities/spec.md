# Feature Specification: Default Workstation Utilities

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-22

**Status**: Implemented brownfield feature

**Input**: User description: "Add focused default modules for GPU-accelerated mpv playback and
Safe-Chain package-manager protection—including pnpm—while keeping inspection observational and
repair explicit."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable accelerated media playback (Priority: P1)

As the workstation operator, I can use a managed mpv command with safe Radeon acceleration while
retaining personal settings outside the declared configuration block.

**Why this priority**: Media playback should use the available GPU without making the workstation
dependent on hardware decoding or overwriting unrelated preferences.

**Independent Test**: Inspect the package, command shim, managed block, hardware-decoder check, and
focused module contract without installing software or changing the user configuration.

**Acceptance Scenarios**:

1. **Given** the supported Radeon workstation, **When** mpv state is inspected, **Then** the report
   compares the official package, command, D3D11 renderer, and safe decode policy without mutation.
2. **Given** personal mpv settings outside the managed block, **When** repair is explicitly run,
   **Then** those settings remain intact.
3. **Given** hardware decoding is unavailable for media, **When** playback starts, **Then** software
   decoding remains available as the fallback.

---

### User Story 2 - Protected package-manager use (Priority: P1)

As the workstation operator, I can inspect and explicitly maintain hash-pinned Safe-Chain
protection for supported package managers on Windows and trusted Debian only.

**Why this priority**: Package installation is a supply-chain boundary and must not silently extend
into malware-analysis or restricted AI environments.

**Independent Test**: Validate release and binary hashes, installer-before-execution ordering,
shell registrations, trust-boundary selection, module dependencies, and capability routing using
the focused static contract suite.

**Acceptance Scenarios**:

1. **Given** the reviewed release declarations, **When** Safe-Chain state is tested, **Then** Windows
   and trusted Debian status is reported without downloading, installing, or registering anything.
2. **Given** an explicit repair and verified assets, **When** Safe-Chain is ensured, **Then** only
   the current Windows user and trusted developer Debian receive the declared protection.
3. **Given** a mismatched installer or binary digest, **When** repair is attempted, **Then**
   execution stops before the unverified payload is trusted.
4. **Given** pnpm is installed in a managed development shell, **When** Safe-Chain state is tested,
   **Then** the declared pnpm and pnpx interception wrappers are required without changing them.

---

### User Story 3 - Select and publish focused state safely (Priority: P2)

As a maintainer, I can select either utility independently through the workstation DSL and review
its human commands, dependency boundary, documentation, tests, and release ownership.

**Why this priority**: Default utilities remain maintainable only when their public surface and
publication evidence stay attributable.

**Independent Test**: Run focused module plans, contract tests, capability smoke tests, governance,
lint, and strict documentation build without applying workstation state.

**Acceptance Scenarios**:

1. **Given** either module name, **When** a focused plan is requested, **Then** the orchestrator
   reports only that module and its declared dependencies.
2. **Given** the capability catalog, **When** operator routes are inspected, **Then** Safe-Chain
   repair is preceded by human-readable inspection commands.
3. **Given** a publication attempt, **When** feature governance runs, **Then** both modules and the
   state-changing Safe-Chain route resolve to this complete feature.

### Edge Cases

- The mpv package or executable is missing, or the build does not expose D3D11VA.
- The mpv configuration has no managed block, a stale block, or personal lines around the block.
- Hardware decoding cannot be used for a particular codec or file.
- A Safe-Chain installer or installed binary differs from its declared digest.
- An expected PowerShell or Bash registration is missing or duplicated.
- An initialization file exists but omits a declared package-manager wrapper.
- Trusted Debian is unavailable while Windows state remains inspectable.
- A restricted AI, DevOps NixOS, or malware-analysis distribution is present.
- A caller combines an explicit module selection with a legacy skip switch.

## Requirements *(mandatory)*

### Functional Requirements

- **REQ-001**: The workstation shall expose mpv through a separately selectable, non-privileged default module using the reviewed official package channel.
- **REQ-002**: When mpv state is tested, the resource shall compare package, command, managed configuration, renderer, and decoder capability without changing workstation state.
- **REQ-003**: When mpv state is explicitly ensured, the resource shall reconcile only the bounded managed configuration block while preserving unrelated user settings.
- **REQ-004**: Where the supported Radeon graphics adapter is selected, the mpv policy shall use the modern renderer and Direct3D 11 graphics path.
- **REQ-005**: While hardware decoding is requested, the mpv policy shall retain automatic software fallback for unsupported or failed decoding paths.
- **REQ-006**: The workstation shall expose Safe-Chain through a separately selectable default module after the managed PowerShell profile dependency.
- **REQ-007**: Before a Safe-Chain installer is executed or an installed binary is accepted, the resource shall verify the corresponding declared cryptographic digest.
- **REQ-008**: While Safe-Chain trust boundaries are evaluated, the resource shall include the current Windows user and trusted developer Debian while excluding restricted AI, DevOps NixOS, and malware-analysis environments.
- **REQ-009**: When Safe-Chain state is tested, the resource shall report Windows, trusted Debian, binary, shell-registration, and declared command-wrapper compliance including pnpm/pnpx without downloading, installing, or registering software.
- **REQ-010**: If Safe-Chain repair cannot produce the declared binary and shell-registration state, then the resource shall return a nonzero failure without claiming compliance.
- **REQ-011**: When either utility is selected through the workstation orchestrator, the catalog shall expose stable order, dependencies, modes, privilege, destructiveness, and default selection.
- **REQ-012**: When either utility interface changes, the project shall update human commands, capability routing where applicable, operator documentation, focused tests, and release notes together.
- **REQ-013**: When automated validation runs, the project shall prove both focused module contracts and publication ownership without installing packages or changing user configuration.

### Key Entities

- **mpv state**: Package identity, executable command, managed configuration block, graphics path,
  decoder capability, and compliance result.
- **Safe-Chain release**: Versioned Windows and Linux installers and binaries with declared digests.
- **Safe-Chain target**: A supported user environment, installed binary, shell registration, and
  compliance result, and declared package-manager wrappers.
- **Focused module declaration**: Module name, default selection, dependency, runtime, privilege,
  destructiveness, order, and feature ownership.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred percent of focused mpv tests preserve settings outside the managed block
  and verify the declared Direct3D 11 and safe-fallback policy.
- **SC-002**: One hundred percent of altered Safe-Chain installer and binary fixtures are rejected
  before trust or execution.
- **SC-003**: Test and plan validation for both modules causes zero package installations, shell
  registrations, user-configuration writes, or privilege prompts.
- **SC-004**: Every declared Safe-Chain target belongs to the trusted Windows or developer Debian
  boundary, with zero restricted-environment targets.
- **SC-005**: Focused utility, governance, lint, Tricky, full PowerShell, and strict documentation
  gates pass before the release tag is published.
- **SC-006**: One hundred percent of declared pnpm and pnpx wrapper checks pass in both managed
  development shells, and Test performs zero registration changes.

## Assumptions

- The supported workstation graphics adapter is the declared Radeon 890M; other adapters can use
  mpv defaults until a separate reviewed profile is added.
- `auto-safe` may choose software decoding and this is a successful safety fallback.
- Safe-Chain upstream support determines which npm and Python commands receive interception.
- Windows and trusted Debian remain separate installations with independently verified assets.
- The implementation predates this ownership specification, so existing tests serve as reviewed
  brownfield characterization and regression evidence.

## EARS requirements

Every normative requirement above has a stable `REQ-NNN` identifier, exactly one `shall`
obligation, and an EARS form. Implementation details remain in the plan and contracts.
