# Feature Specification: Managed Workstation Update

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-15

**Status**: Implemented and validated

**Input**: User description: "Add one update command for Windows, WinGet, Scoop, WSL, Docker, the PowerShell system environment with release-aware drift correction, and managed Homebrew instances."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review one complete update plan (Priority: P1)

An operator can type one short command and see every applicable host, package-manager, WSL,
container, Homebrew, and desired-state step in compatible order before the machine changes.

**Why this priority**: A readable and non-mutating preview is required to make a broad update safe
enough for routine human and agent use.

**Independent Test**: Run the command without mutation confirmation, inspect human and structured
output, and verify the declared steps, privilege boundaries, dependencies, and omissions without
observing any updater invocation.

**Acceptance Scenarios**:

1. **Given** a managed workstation, **When** the operator runs `update`, **Then** an ordered plan covers every requested update surface and changes no system state.
2. **Given** automation needs to inspect the plan, **When** it runs `update -Json`, **Then** it receives the same stages and dependencies as bounded structured data.
3. **Given** the operator selects one or more targets, **When** the plan is rendered, **Then** only those targets and their prerequisites appear.

---

### User Story 2 - Apply host and package updates explicitly (Priority: P1)

An operator explicitly runs the plan to install applicable Windows software updates, upgrade
ordinary WinGet and Scoop applications, and update the WSL runtime while preserving pins and
retaining control over restarts.

**Why this priority**: These are the primary host update channels, and conflating them would leave
the workstation partially updated or make servicing behavior misleading.

**Independent Test**: Exercise synthetic command runners for available, empty, failed, pinned, and
restart-required results; verify that execution is impossible without `-Run`, drivers remain out of
scope, and no restart or cleanup command is emitted.

**Acceptance Scenarios**:

1. **Given** applicable Windows software updates, **When** the operator runs `update -Run`, **Then** accepted non-driver updates are installed and any restart requirement is reported without rebooting.
2. **Given** WinGet packages with available releases, **When** the WinGet stage runs, **Then** ordinary known-version unpinned packages are upgraded without overriding package pins.
3. **Given** a compliant Scoop installation, **When** the Scoop stage runs, **Then** Scoop, its declared buckets, and installed applications are updated without deleting old versions or caches.
4. **Given** an installed WSL runtime, **When** its stage runs, **Then** the runtime is updated through the supported host command without shutting down active distributions.

---

### User Story 3 - Update declared Linux and container environments (Priority: P1)

An operator updates both declared Debian distributions while keeping the developer Docker daemon
and the malware-analysis rootless Podman environment separate, and updates each declared Homebrew
instance without touching unrelated distributions.

**Why this priority**: Linux packages and container engines otherwise drift independently from the
host, while accidental boundary crossing would weaken the analysis environment.

**Independent Test**: Use a synthetic WSL inventory and command runner to verify per-distribution
package operations, managed Homebrew discovery, dependency skips, Docker/Podman reconciliation, and
the absence of commands against undeclared distributions.

**Acceptance Scenarios**:

1. **Given** distinct developer and malware-analysis Debian distributions, **When** Linux updates run, **Then** each distribution receives its own package refresh and noninteractive upgrade as root.
2. **Given** Homebrew is declared only for the developer distribution, **When** Homebrew updates run, **Then** that instance and its unpinned formulae are updated while Debian-MW and unrelated distributions are untouched.
3. **Given** Linux packages are current, **When** container reconciliation runs, **Then** developer Docker is checked through its rootful pyinfra resource and Debian-MW Podman through its rootless pyinfra resource.
4. **Given** a prerequisite Linux stage fails, **When** execution continues, **Then** dependent Homebrew or container steps are skipped with a visible reason.

---

### User Story 4 - Restore release-defined PowerShell and workstation state (Priority: P1)

After package upgrades, an operator can bring the PowerShell runtimes, shared profiles, environment
variables, and the rest of the default system definition back to the state declared by the current
checked-out release.

**Why this priority**: Upgrading installers alone can leave stale process paths, profiles, aliases,
or cross-resource drift, so the update is incomplete without a final desired-state pass.

**Independent Test**: Use a synthetic executor to verify that reconciliation is last, uses the
current repository release, invokes the default non-destructive desired-state selection, refreshes
both supported PowerShell profile targets, and reports any remaining drift.

**Acceptance Scenarios**:

1. **Given** package update stages completed, **When** reconciliation runs, **Then** the current release's default desired state is ensured in dependency order.
2. **Given** PowerShell or environment state drifted during upgrades, **When** reconciliation completes, **Then** both supported profile targets and stable environment declarations match the current release.
3. **Given** reconciliation or its verification fails, **When** the update summary is rendered, **Then** the command exits nonzero and identifies the unresolved stage without claiming the workstation is current.

### Edge Cases

- Windows Update reports no applicable updates, a rejected EULA, an installation failure, or a pending restart.
- WinGet or Scoop cannot refresh a source, an application requires interaction, or a package is pinned.
- WSL is installed from a channel that requires `--web-download`, or a declared distribution is absent or already busy.
- One Debian distribution succeeds while the other fails, without allowing a later step to cross their trust boundary.
- Homebrew exists in an undeclared distribution or a release-pinned formula is outdated upstream.
- Docker package upgrades restart the developer daemon while a workload is active.
- Debian-MW package upgrades change Podman dependencies while its API services must remain disabled.
- A new PowerShell release is installed while the current terminal still has a stale process environment.
- The repository checkout is not on a tagged release or has local modifications.
- An update command returns a conventional "nothing to do" exit code that differs from a hard failure.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: The managed profile shall expose one human-readable `update` command for the complete workstation update workflow.
- REQ-002: When `update` is invoked without execution confirmation, the command shall render an ordered plan without invoking a state-changing updater.
- REQ-003: When `update -Json` is invoked, the command shall return bounded structured stages, dependencies, privilege, state-change, and restart fields equivalent to the human plan.
- REQ-004: Where one or more update targets are selected, the command shall include only those targets and their declared prerequisites.
- REQ-005: When update execution is requested, the orchestrator shall require the explicit `-Run` switch before invoking any state-changing command.
- REQ-006: When multiple update targets are selected, the orchestrator shall execute them in a deterministic dependency order.
- REQ-007: When Windows servicing runs, the update workflow shall install applicable accepted software updates while excluding driver updates.
- REQ-008: If Windows servicing requires a restart, then the update workflow shall report that requirement without restarting Windows automatically.
- REQ-009: When WinGet servicing runs, the update workflow shall upgrade known-version unpinned applications without overriding package pins or forcing previous-version removal.
- REQ-010: When Scoop servicing runs, the update workflow shall update the declared Scoop source, buckets, and installed applications without cleanup or removal.
- REQ-011: When WSL host servicing runs, the update workflow shall use the supported WSL update interface without shutting down distributions automatically.
- REQ-012: When Linux distribution servicing runs, the update workflow shall refresh and noninteractively upgrade packages in both declared distributions under their explicit root boundary.
- REQ-013: While Linux update stages execute, the update workflow shall keep developer and malware-analysis distribution identities and users separate.
- REQ-014: Where Homebrew is declared for a managed distribution, the update workflow shall update that instance and its unpinned formulae without discovering or modifying undeclared distributions.
- REQ-015: While Homebrew formulae are upgraded, the update workflow shall preserve formulae pinned by the current workstation release.
- REQ-016: When developer container reconciliation runs, the update workflow shall use the existing pyinfra-managed rootful Docker resource in the developer distribution.
- REQ-017: When malware container reconciliation runs, the update workflow shall use the existing pyinfra-managed rootless Podman resource in the malware-analysis distribution.
- REQ-018: If an update prerequisite fails, then the orchestrator shall skip its dependants and report the blocking stage while permitting independent stages to report their own results.
- REQ-019: When package and runtime updates finish, the update workflow shall ensure the current release's default non-destructive workstation state and verify remaining drift.
- REQ-020: While desired-state reconciliation runs, the update workflow shall maintain equivalent managed PowerShell profiles and stable environment declarations for Windows PowerShell 5.1 and PowerShell Core.
- REQ-021: The update workflow shall avoid automatic reboot, WSL shutdown, container pruning, Scoop cleanup, package-pin overrides, security-control weakening, and distribution discovery.
- REQ-022: When elevation is required, the update workflow shall display the exact privileged stage and use the repository's declared Windows or WSL privilege boundary.
- REQ-023: When execution completes, the update workflow shall summarize every stage as succeeded, skipped, failed, restart-required, or not-selected and return nonzero if any selected stage failed or drift remains.
- REQ-024: When the public update command changes, the repository shall update capability routing, operator documentation, sample output, and command discovery together.
- REQ-025: When the update workflow is loaded by either supported PowerShell runtime, it shall expose the same plan and target contract.

### Key Entities

- **Update target**: A selectable host, package-manager, WSL, Homebrew, container, or reconciliation surface with privilege and dependency metadata.
- **Update stage**: One deterministic action with a target, command description, mutation flag, prerequisite set, and execution status.
- **Managed Linux environment**: A declared distribution/user pair with either developer or malware-analysis trust scope.
- **Update result**: Per-stage outcome, detail, restart requirement, skip reason, and aggregate exit state.
- **Release state**: The checked-out workstation definition that owns package pins, PowerShell profile content, environment declarations, and default non-destructive modules.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One command plan represents 100 percent of the seven requested update surfaces before any mutation occurs.
- **SC-002**: Every mutating stage is unreachable without one explicit execution switch and zero stages automatically reboot, shut down WSL, prune containers, clean Scoop data, or override pins.
- **SC-003**: Both declared Debian distributions are updated independently, and zero undeclared distributions are queried or modified.
- **SC-004**: Every selected stage produces exactly one terminal outcome and any failure or remaining drift results in a nonzero command exit.
- **SC-005**: Windows PowerShell 5.1 and PowerShell Core render identical target and dependency plans from the managed profile.
- **SC-006**: A completed update leaves all current-release default desired-state tests compliant or identifies every unresolved stage and restart requirement.

## Assumptions

- `Windows` means applicable Windows software and security servicing; display, firmware, and other driver updates remain explicit vendor-managed actions.
- WinGet and Scoop update all ordinary installed applications but respect their existing pin/hold mechanisms.
- The declared developer Debian and Debian-MW distributions are the only Linux package targets.
- Homebrew currently exists only in the declared developer Debian distribution; future instances must be declared before the update workflow touches them.
- Docker means the rootful developer Docker Engine used by Dagger; Debian-MW continues to use daemonless rootless Podman.
- The current checked-out release is authoritative; this feature does not pull Git branches, replace the repository, or adopt a newer workstation release automatically.
- Applying updates may interrupt applications or container workloads, require network access and elevation, and leave a restart pending, but it never restarts the host automatically.
