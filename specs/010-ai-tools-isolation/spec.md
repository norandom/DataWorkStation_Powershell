# Feature Specification: AI Tools and WSL Isolation

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-17

**Status**: Draft

**Input**: User description: "Add an opt-in AI-tools category with OpenCode CLI and Desktop,
official-script installations for Claude Code and Antigravity CLI, Cline and GitHub Copilot CLIs,
and a developer category with stable VS Code, Berg, the selected terminal font, and the Cline,
Jupyter, Python, and GitHub Copilot extensions. Run OpenCode in a separately verified NixOS WSL
environment, isolate it from DevOps credentials and other WSL environments, strengthen the
DevOps and Debian-MW boundaries, retain ordinary Debian as a trusted utility environment, and run
OpenCode through nono installed with `brew install nono`."

## Clarifications

### Session 2026-08-17

- Q: May the AI distribution use a separate Windows account? → A: No; isolation is limited to
  the WSL environments owned by the existing Windows user.
- Q: What daily privilege and host integration may the AI distribution retain? → A: Use a
  non-root account without sudo, Windows executable interoperability, or automatic Windows-drive
  mounts.
- Q: Which environments require the restricted WSL boundary? → A: Apply it to the AI,
  DevOps, and Debian-MW environments; keep ordinary Debian as an explicitly trusted utility and
  administration environment.
- Q: How should the AI process receive an additional process-level sandbox? → A: Install
  `nono` with Homebrew inside the AI environment and use it to launch OpenCode.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select and maintain the requested AI tools (Priority: P1)

As the workstation operator, I can opt into one focused AI-tools category, inspect what it would
install, and explicitly maintain the enabled native and WSL tools through their selected official
delivery channels.

**Why this priority**: The tools and their provenance are the visible user outcome, and the
category must remain optional because several installers execute network-delivered vendor code.

**Independent Test**: Inspect absent, compliant, stale, wrong-channel, and partially installed
state records; verify that inspection changes nothing, the plan names every enabled tool and source,
and an explicitly selected reconciliation reaches compliant state without touching disabled tools.

**Acceptance Scenarios**:

1. **Given** the AI-tools category has not been selected, **When** the complete default workstation
   state is maintained, **Then** none of its optional products is installed or removed.
2. **Given** the category is selected in test or plan mode, **When** its state is inspected, **Then**
   every enabled product, delivery channel, target environment, privilege boundary, and intended
   change is reported without modifying the workstation.
3. **Given** the operator explicitly selects reconciliation, **When** all enabled installers
   succeed, **Then** each product is available in its declared Windows or WSL environment and its
   source is reported as compliant.
4. **Given** one vendor installer fails, **When** reconciliation stops, **Then** the failure is
   actionable and no unrelated product is silently substituted through another package source.

---

### User Story 2 - Run OpenCode inside a layered AI sandbox (Priority: P1)

As an AI-tool user, I can launch OpenCode in its dedicated NixOS WSL environment through a reviewed
`nono` sandbox that grants access to the selected project but not to SSH keys, DevOps credentials,
Windows drives, other WSL filesystems, or undeclared user data.

**Why this priority**: An autonomous coding agent processes untrusted repository content and can
execute tools, so access must be structurally limited rather than left to prompt instructions.

**Independent Test**: Launch a benign probe through the same managed OpenCode entry point and prove
that it can read and write the selected disposable project, cannot read representative forbidden
paths, cannot invoke Windows executables or elevate privilege, and fails closed when `nono` or its
required kernel enforcement is unavailable.

**Acceptance Scenarios**:

1. **Given** a compliant AI distribution and reviewed sandbox profile, **When** OpenCode starts from
   a selected project, **Then** it can use only the project and explicitly declared agent runtime
   state while forbidden credential and filesystem probes fail.
2. **Given** `nono` is absent, stale, misconfigured, bypassed, or unable to apply the required
   kernel restrictions, **When** the managed OpenCode command is used, **Then** OpenCode does not
   start and the operator receives an actionable failure.
3. **Given** a child tool is invoked by OpenCode, **When** it executes, **Then** it remains inside
   the effective sandbox and receives no broader filesystem, network, or credential access than its
   reviewed policy permits.
4. **Given** an operator needs to administer the AI distribution, **When** maintenance is required,
   **Then** root access is initiated explicitly from trusted Windows rather than granted to the
   daily AI account.

---

### User Story 3 - Preserve WSL credential boundaries (Priority: P1)

As the DevOps user, I can keep private keys and infrastructure credentials inside the private
DevOps filesystem while AI and malware-analysis workloads remain unable to use Windows
interoperability, shared mounts, or elevated Linux access to cross into that environment.

**Why this priority**: Separate WSL virtual disks do not form a sufficient boundary when a source
distribution can invoke Windows to enter another distribution as root.

**Independent Test**: Inspect all four declared distributions and verify the trust matrix,
configuration, users, mounts, shared paths, credential locations, and prohibited access probes
without reading secret contents or changing running state.

**Acceptance Scenarios**:

1. **Given** compliant AI and Debian-MW distributions, **When** their daily users attempt to launch
   Windows programs, mount Windows drives, elevate privilege, or read DevOps paths, **Then** every
   attempt fails at the declared boundary.
2. **Given** a compliant DevOps distribution, **When** credential state is inspected, **Then** keys
   reside only on its private Linux filesystem with restrictive ownership and permissions and no
   shared credential link or agent socket is present.
3. **Given** ordinary Debian is retained for trusted utility work, **When** its role is inspected,
   **Then** its broader integration is explicit and it is excluded from AI-agent and hostile-input
   workloads.

---

### User Story 4 - Stage hostile files safely in Debian-MW (Priority: P2)

As a malware analyst, I can transfer a case into Debian-MW's private filesystem, verify its
identity, run the existing rootless static-analysis workflow, and transfer results out without
giving the analysis account general access to Windows drives or other WSL environments.

**Why this priority**: Debian-MW already restricts containers, but direct host mounts and WSL
interop would leave a broader escape path after a parser or container compromise.

**Independent Test**: Use a benign fixture to exercise the Windows-to-private-filesystem staging,
hash verification, existing rootless analysis, and result export while confirming the absence of
automatic or shared mounts.

**Acceptance Scenarios**:

1. **Given** an approved case on Windows, **When** it is staged for static analysis, **Then** its
   copied input is placed in a dedicated private case directory and its identity is verified before
   parsing.
2. **Given** a staged case, **When** the existing rootless analysis runs, **Then** the analysis uses
   only the bounded case paths and retains its existing no-network, no-engine-socket, and
   non-execution rules.
3. **Given** a completed case, **When** results are exported, **Then** the transfer preserves the
   evidence record and does not expose unrelated Windows or WSL paths to the analysis user.

---

### User Story 5 - Maintain the Windows developer editor (Priority: P2)

As a developer, I can use stable Visual Studio Code with Berg, the locally selected Berkeley Mono
font or portable Fira fallback, and the Cline, Jupyter, Python, and GitHub Copilot extensions from
the focused developer category.

**Why this priority**: The editor and extensions provide the native Windows interface for the new
tools but do not need to weaken the isolated WSL execution boundary.

**Independent Test**: Inspect a portable configuration without the private font selection and a
local configuration with it, then verify the stable editor, Berg, exact extension inventory, and
effective font selection while preserving unrelated editor settings and extensions.

**Acceptance Scenarios**:

1. **Given** the developer category is selected, **When** its state is reconciled, **Then** stable
   Visual Studio Code, Berg, and every declared extension are available.
2. **Given** a valid local Berkeley Mono preference, **When** editor settings are maintained, **Then**
   that family is selected without committing private font material or machine-local paths.
3. **Given** no valid local font preference, **When** the portable configuration is maintained,
   **Then** Fira is selected and unrelated editor preferences remain unchanged.

### Edge Cases

- A vendor changes an installer URL, package identifier, release layout, or command name.
- A remote installation script downloads successfully but fails validation or exits part-way.
- OpenCode Desktop and CLI are available natively on Windows while the restricted CLI remains available in AI WSL.
- The AI distribution exists under the wrong name, is WSL 1, has the wrong default user, or shares
  an identity with DevOps, Debian, or Debian-MW.
- The AI user belongs to an administrative group, has a sudo rule, owns a setuid helper, or can
  modify the boundary configuration.
- WSL interoperability is disabled but a Windows drive, `/mnt/wsl`, another distribution, an agent
  socket, or a credential directory is still reachable through a declared or stale mount.
- `nono` is installed but its WSL2 feature check reports degraded or unavailable required
  filesystem enforcement.
- The upstream `nono` profile changes namespace, identity, permissions, or network policy.
- A sandboxed child command requests a broader working directory, local-network endpoint, raw
  credential, container socket, or privilege than the parent profile permits.
- An agent project contains symlinks, junction-like paths, nested mounts, sockets, or paths that
  escape the selected project root.
- DevOps keys have correct modes but are symlinked to Windows, shared through an agent socket, or
  copied into project configuration.
- Debian-MW input staging is interrupted, hashes disagree, a case path already exists, or result
  export encounters an untrusted file type or path traversal.
- Ordinary Debian is accidentally selected for AI execution, untrusted parsing, or secret storage.
- A local Berkeley Mono preference names a font that is not installed.
- An editor extension is withdrawn, renamed, incompatible, or replaced by an unexpected publisher.

## Requirements *(mandatory)*

### Functional Requirements

- **REQ-001**: Where the AI-tools category or a focused product subset is selected, the workstation manager shall maintain only the selected products explicitly marked enabled in its reviewed declaration.
- **REQ-002**: While the AI-tools category is not selected, the workstation manager shall leave its optional products and configuration unchanged.
- **REQ-003**: When AI-tool state is tested or planned, the workstation manager shall report each product, target environment, selected delivery channel, observed state, privilege boundary, and intended action without changing state.
- **REQ-004**: When machine-readable AI-tool status is requested, the workstation manager shall return structured results representing the same checks and decisions as the default human report.
- **REQ-005**: Where OpenCode is enabled, the workstation manager shall provide its Desktop application and ordinary CLI on Windows and retain a separately invoked CLI inside the dedicated AI NixOS WSL environment.
- **REQ-006**: Where Claude Code is enabled, the workstation manager shall use the official PowerShell installer invoked by `irm https://claude.ai/install.ps1 | iex` and omit its former WinGet declaration.
- **REQ-007**: Where Antigravity is enabled, the workstation manager shall install only its CLI through `irm https://antigravity.google/cli/install.ps1 | iex` without adding a desktop application.
- **REQ-008**: Where the Cline CLI is enabled, the workstation manager shall install it through the declared global npm command `npm i -g cline`.
- **REQ-009**: Where the GitHub Copilot CLI is enabled, the workstation manager shall maintain the official supported CLI in its declared native environment.
- **REQ-010**: Where the developer category is selected, the workstation manager shall maintain stable Visual Studio Code, `jx22/berg`, and the Cline, Jupyter, Python, and GitHub Copilot extensions.
- **REQ-011**: Where a valid local Berkeley Mono preference exists, the editor configuration shall select it without tracking the font files or machine-local preference.
- **REQ-012**: Where no valid local font preference exists, the editor configuration shall select the declared portable Fira family.
- **REQ-013**: When editor configuration is reconciled, the workstation manager shall preserve unrelated user settings, extensions, profiles, and workspace configuration.
- **REQ-014**: Where the AI environment is provisioned, the workstation manager shall maintain a dedicated NixOS WSL 2 distribution whose name and daily user differ from every other declared WSL environment and from root.
- **REQ-015**: When AI-environment integrity is tested, the workstation manager shall verify its active generation, evaluated declaration, deployed source manifest, command provenance, and complete managed store content without changing state.
- **REQ-016**: Where the AI environment is enabled, the workstation manager shall install `nono` inside that environment through the declared Homebrew command `brew install nono`.
- **REQ-017**: When the managed OpenCode entry point is used, the workstation manager shall launch it through a reviewed `nono` profile that grants project-scoped access and inherits restrictions to child processes.
- **REQ-018**: If `nono` or the required WSL2 kernel enforcement is absent, degraded, unverified, or unable to apply the reviewed profile, then the managed OpenCode entry point shall fail before starting the agent.
- **REQ-019**: While OpenCode runs through the managed sandbox, the `nono` policy shall deny filesystem access outside the selected project and explicitly reviewed agent runtime paths.
- **REQ-020**: While OpenCode runs through the managed sandbox, the `nono` policy shall deny raw SSH, DevOps, cloud, Windows-host, other-WSL, container-socket, and undeclared credential access.
- **REQ-021**: While OpenCode or a delegated tool uses network access, the `nono` policy shall limit that access to the reviewed agent and tool rules rather than unrestricted local-network reachability.
- **REQ-022**: When a managed `nono` profile or upstream profile identity changes, the workstation manager shall report the policy difference and require explicit reconciliation before using the changed profile.
- **REQ-023**: While the AI daily account exists, the workstation manager shall keep it outside sudo-capable groups and rules and prevent it from modifying the WSL boundary configuration.
- **REQ-024**: While the AI distribution is compliant, the workstation manager shall keep Windows executable interoperability and Windows-path injection disabled.
- **REQ-025**: While the AI distribution is compliant, the workstation manager shall keep automatic Windows-drive mounts, shared WSL mounts, filesystem-table host mounts, other-distribution mounts, and shared agent sockets absent.
- **REQ-026**: While the DevOps distribution contains key material, the workstation manager shall keep Windows executable interoperability, Windows-path injection, and automatic Windows-drive mounts disabled.
- **REQ-027**: When DevOps credential state is tested, the workstation manager shall verify private-filesystem placement, ownership, restrictive permissions, and absence of Windows links, cross-distribution links, raw exports, and shared agent sockets without reading secret contents.
- **REQ-028**: While Debian-MW is used for hostile static parsing, the workstation manager shall keep its analysis user non-root and without sudo, Windows executable interoperability, Windows-path injection, automatic Windows-drive mounts, shared WSL mounts, shared SSH state, or persistent container API access.
- **REQ-029**: When a Windows case is transferred to Debian-MW, the analysis workflow shall stage it into a newly bounded private Linux case directory and verify its identity before parsing.
- **REQ-030**: When Debian-MW results are transferred to Windows, the analysis workflow shall preserve evidence identity and validate exported paths and file types without granting the analysis user general host-filesystem access.
- **REQ-031**: Where ordinary Debian remains the trusted utility environment, the workstation documentation shall identify its broader Windows integration and prohibit AI-agent execution, hostile-input parsing, and DevOps key storage there.
- **REQ-032**: When WSL boundary status is requested, the workstation manager shall report the role, trust level, daily user privilege, interop, automount, shared-path, credential, sandbox, and residual host-access state for every declared distribution.
- **REQ-033**: If a selected distribution, user, mount, credential path, sandbox state, or trust role violates the declaration, then the workstation manager shall return an actionable nonzero result without silently weakening or repairing the boundary in test mode.
- **REQ-034**: When AI tools or sandbox packages are updated, the workstation manager shall preserve the declared delivery channels and revalidate tool provenance, WSL integrity, sandbox enforcement, and profile policy before reporting compliance.
- **REQ-035**: When this feature changes a command or desired-state interface, the project shall update the module catalog, capability routing, operator documentation, and human and structured examples together.
- **REQ-036**: The AI-tools and WSL-isolation capability shall remain focused and separate from malware execution, forensic acquisition, Windows security-policy, and unrelated developer-environment modules.
- **REQ-037**: While portable configuration is tracked, the project shall exclude credentials, tokens, private keys, private fonts, machine paths, locally generated sandbox state, and case evidence.
- **REQ-038**: The workstation manager shall declare exact source identities and SHA-256 values for every managed Cream Blue theme and OpenUltraCode release payload.
- **REQ-039**: When OpenCode extension reconciliation is explicitly requested, the workstation manager shall install every declared Cream Blue theme and select `cream-blue-cobalt` through the global TUI configuration.
- **REQ-040**: While an existing global OpenCode configuration or unrelated extension asset is present, the workstation manager shall preserve it through bounded semantic merges and timestamped backups of replaced managed files.
- **REQ-041**: When OpenUltraCode state is reconciled, the workstation manager shall verify the pinned release archive and complete extracted inventory before publishing its commands, agents, skill, and release-local plugin.
- **REQ-042**: When OpenCode extension state is requested in plan or test mode, the workstation manager shall report theme, release, asset, and plugin compliance without network or filesystem mutation.

### Key Entities

- **AI-tools declaration**: The enabled products, exact delivery channels, target Windows or WSL
  environment, expected command, and optional-category selection.
- **AI WSL environment**: The dedicated NixOS distribution, non-root daily user, immutable system
  declaration, integrity evidence, private project storage, and WSL boundary state.
- **Sandbox profile**: The reviewed `nono` identity and policy governing project paths, runtime
  paths, delegated tools, network destinations, credentials, and fail-closed prerequisites.
- **WSL trust record**: The declared role and observed user privilege, interoperability, mounts,
  shared paths, credential exposure, and residual host control for AI, DevOps, Debian, and
  Debian-MW.
- **DevOps credential boundary**: Private Linux key and configuration paths, owners, permissions,
  links, sockets, and non-secret compliance metadata.
- **Debian-MW case staging record**: Source identity, private destination, verification result,
  bounded analysis paths, result identity, and export validation.
- **Developer editor state**: Stable editor identity, Berg state, declared extensions, local font
  preference validity, portable fallback, and preserved user-owned settings.
- **OpenCode extension state**: Pinned theme identities, selected TUI theme, verified OpenUltraCode
  release inventory, published assets, plugin registration, and preserved global configuration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred percent of AI-tool test and plan operations produce zero package,
  profile, WSL, mount, user, editor, or credential changes.
- **SC-002**: One hundred percent of enabled AI products report the requested target environment
  and delivery channel after successful reconciliation, with zero silent package-source
  substitutions.
- **SC-003**: Every managed OpenCode launch uses a verified `nono` policy, and all launches fail
  before agent startup when required sandbox enforcement is unavailable.
- **SC-004**: A sandbox verification probe can read and write its selected disposable project while
  one hundred percent of representative SSH, DevOps, Windows-drive, other-WSL, container-socket,
  and out-of-project probes are denied.
- **SC-005**: AI and Debian-MW daily users have zero sudo-capable memberships or rules, zero
  automatic Windows-drive mounts, and zero ability to launch Windows executables.
- **SC-006**: DevOps credential inspection finds zero keys or agent sockets on Windows, shared WSL
  paths, other distributions, or tracked configuration, while all private key paths pass ownership
  and permission checks.
- **SC-007**: One hundred percent of staged Debian-MW fixtures retain matching input identities,
  run through the existing bounded rootless static workflow, and export only validated case
  results.
- **SC-008**: Ordinary Debian is the only WSL environment documented with trusted utility-level
  Windows integration, and zero declared AI or hostile-analysis commands route to it.
- **SC-009**: Stable Visual Studio Code reports all four declared extensions, Berg, and exactly one
  valid effective font choice while preserving all unrelated sampled settings and extensions.
- **SC-010**: One hundred percent of normative requirements pass EARS validation and receive a
  verification mapping before implementation planning is approved.
- **SC-011**: Every declared OpenCode theme and OpenUltraCode asset reports compliant after one
  reconciliation and a second reconciliation makes zero managed-content changes.

## Assumptions

- The existing Windows user and Windows host remain trusted administration boundaries; this feature
  does not claim protection from the Windows user, host administrator, WSL kernel compromise, or
  physical host compromise.
- Ordinary Debian remains a trusted utility and administration environment because its Windows
  integration can be used to administer other distributions; untrusted agents and hostile files
  are excluded from it.
- `nono` provides process-level defense in depth inside the AI distribution and does not replace
  the separate distribution, non-root account, disabled interoperability, or mount boundaries.
- OpenCode Desktop and the ordinary CLI run on Windows, while the explicitly managed sandbox entry
  point runs a separate CLI inside the dedicated AI NixOS WSL environment.
- Network access remains necessary for selected AI providers and delegated developer tools, but
  local-network and credential access are denied unless a reviewed policy explicitly grants them.
- Homebrew is permitted inside the AI environment solely as a separately verified package boundary
  for declared tools such as `nono`; it is not part of the immutable Nix store.
- Trusted Windows initiates explicit root maintenance for the restricted distributions; their
  daily users do not receive sudo merely for workstation reconciliation.
- DevOps key material remains on the DevOps distribution's private Linux filesystem and is never
  copied into an AI project, Windows profile, shared mount, or portable repository configuration.
- Debian-MW continues to use its existing rootless, daemonless, static-only Podman workflow; dynamic
  Windows execution remains confined to the separately governed Windows Sandbox workflow.
- The current terminal-font local preference mechanism remains the source for Berkeley Mono, with
  Fira as the public portable fallback.
- Installer versions, immutable identities, and any required licenses or terms will be researched
  during planning before implementation is authorized.

## EARS requirements

Every normative requirement in this specification uses a stable `REQ-NNN` identifier, exactly one
`shall` obligation, and one of the ubiquitous, event-driven, state-driven, optional-feature, or
unwanted-behavior forms. Product names and delivery commands are user-selected constraints;
implementation structure and file paths remain planning decisions.
