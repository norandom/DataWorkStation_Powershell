# Feature Specification: Brownfield Workstation Baseline

**Feature Branch**: `main` (brownfield migration)

**Created**: 2026-08-14

**Status**: In progress — brownfield characterization and staged bootstrap extension

**Input**: User description: "Gaplessly migrate the existing workstation project into Spec Kit with EARS requirements and TDD traceability."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inspect and select desired state (Priority: P1)

As an operator, I can inspect the complete workstation plan or select one focused module and see
its dependency closure, privilege, and destructive impact before any state changes.

**Why this priority**: Safe inspection is the entry point for every workstation operation.

**Independent Test**: Run a full plan and representative focused plans, then verify deterministic
ordering, dependency closure, and explicit risk metadata without observing system changes.

**Acceptance Scenarios**:

1. **Given** the declared module catalog, **When** an operator requests a full plan, **Then** every selected dependency appears before its dependant.
2. **Given** a focused module, **When** an operator requests its plan, **Then** only that module and its transitive dependencies appear.
3. **Given** an opt-in destructive module, **When** an operator runs the default selection, **Then** that module is absent.

---

### User Story 2 - Test and apply state safely (Priority: P1)

As an operator, I can test, ensure, or explicitly reinitialize declared state while retaining clear
control over elevation, removal, restart, and recovery boundaries.

**Why this priority**: Desired state is useful only when repeated application is predictable and
high-impact operations remain visible.

**Independent Test**: Exercise non-mutating tests and plans for representative privileged,
nonprivileged, optional, and destructive modules; verify that mutation requires the documented
mode and confirmations.

**Acceptance Scenarios**:

1. **Given** compliant state, **When** an operator runs Ensure twice, **Then** the second run reports no required repair.
2. **Given** a privileged module, **When** its dependency plan is evaluated, **Then** the elevation prerequisite precedes it.
3. **Given** a destructive module, **When** confirmation is absent, **Then** no removal occurs.
4. **Given** a feature change that needs a restart, **When** Ensure completes, **Then** Windows remains running and the restart remains an operator action.

---

### User Story 3 - Diagnose from existing evidence (Priority: P1)

As a developer or administrator, I can route a symptom to the appropriate human-readable command,
inspect existing evidence first, and request machine-readable results explicitly.

**Why this priority**: Evidence-first diagnosis avoids destructive or redundant collection and is
a central workstation capability.

**Independent Test**: Enumerate the capability catalog, run its human and structured discovery
forms, and verify representative memory, network, crash, event, and profiling routes.

**Acceptance Scenarios**:

1. **Given** existing evidence, **When** a matching diagnostic workflow begins, **Then** inspection commands are presented before capture commands.
2. **Given** a human invocation, **When** no structured-output switch is supplied, **Then** readable output is returned.
3. **Given** an automation invocation, **When** structured output is requested, **Then** valid machine-readable data is returned.
4. **Given** a capture, attach, debugger, or protection-changing action, **When** it is needed, **Then** the operator invokes it explicitly.

---

### User Story 4 - Use the managed developer environment (Priority: P2)

As a developer, I can rely on the declared Windows, terminal, PowerShell, WSL, package, profiling,
and specification tools with their dependencies installed in compatible order.

**Why this priority**: These tools enable daily development after the safety and diagnostic
foundation is available.

**Independent Test**: Test each focused module through its public state command and verify the
documented shell, package, graphics, WSL, and platform boundaries.

**Acceptance Scenarios**:

1. **Given** a fresh supported host, **When** the default modules are ensured, **Then** their declared prerequisites are available before use.
2. **Given** a dual-shell resource, **When** it is tested from both supported PowerShell runtimes, **Then** both invocations report equivalent compliance.
3. **Given** a Debian-local tool, **When** it is ensured, **Then** its Linux package management remains inside the selected distribution.
4. **Given** a terminal graphics mismatch, **When** the terminal gate runs, **Then** the module reports failure instead of claiming compliance.
5. **Given** a fresh host with only inbox Windows tooling, **When** the workstation bootstrap starts, **Then** the inbox stage can plan, test, and install the Core prerequisite without resolving a command that does not exist yet.
6. **Given** the Core stage is compliant, **When** later modules run, **Then** they use the declared modern shell or the explicitly required inbox shell in stage order.
7. **Given** both supported PowerShell runtimes, **When** the managed profile is loaded, **Then** the documented prompt, aliases, key bindings, and discovery surface are equivalent except for guarded runtime-specific enhancements.
8. **Given** Windows Terminal and both PowerShell runtimes, **When** terminal state is ensured, **Then** the newest installed Core profile is the default while inbox Windows PowerShell remains selectable with the same managed appearance.

---

### User Story 5 - Discover and evolve the project (Priority: P2)

As a contributor, I can discover commands and focused skills, read representative outputs and
attack-surface documentation, specify changes in EARS form, and implement them test-first.

**Why this priority**: The repository must remain understandable and safely changeable by humans
and agents after migration.

**Independent Test**: Use command and skill discovery, build the documentation strictly, validate
the feature artifacts, and confirm that every future behavior task names its requirement and test.

**Acceptance Scenarios**:

1. **Given** a documented AI workflow, **When** a contributor reads it, **Then** a directly runnable human command is available first.
2. **Given** a normative change, **When** its tasks are generated, **Then** a failing test task precedes its implementation task.
3. **Given** a release candidate, **When** publication gates run, **Then** lint, human and structured smoke checks, and strict documentation all pass.

### Edge Cases

- A selected module depends on a module whose default selection is disabled.
- The module graph contains a missing dependency or cycle.
- Inbox Windows PowerShell is required for a Windows component that is unavailable through PowerShell 7.
- PowerShell 7 is absent from both `PATH` and its standard installation location during bootstrap.
- A module in an earlier bootstrap stage declares a dependency on a later stage.
- Windows Terminal contains unrelated profiles, key bindings, actions, or local appearance settings.
- The PowerShell 7 dynamic Terminal profile is absent until Terminal is reopened after installation.
- Elevation is unavailable, denied, or not yet configured.
- A package or release hash differs from the declared value.
- An optional Windows feature is enabled but pending a restart.
- Existing evidence is incomplete, corrupt, or from a different incident.
- A local configuration file is absent while its public sample is present.
- A destructive profile is selected without its confirmation switch.
- A diagnostic tool is missing while prior evidence remains inspectable.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: The workstation baseline shall expose every module listed in the Module Coverage Baseline.
- REQ-002: The module catalog shall declare order, default selection, dependencies, supported modes, privilege, destructiveness, and description for each module.
- REQ-003: When a module plan is requested, the planner shall return a deterministic topological order containing every transitive dependency before its dependant.
- REQ-004: When one or more focused modules are selected, the planner shall exclude unrelated modules from the resolved plan.
- REQ-005: When plan mode is requested, the workstation orchestrator shall report intended modules and risk metadata without changing workstation state.
- REQ-006: When test mode is requested, each desired-state resource shall inspect compliance without repairing or reinitializing state.
- REQ-007: When ensure mode is repeated against compliant state, each desired-state resource shall report compliance without replacing equivalent state.
- REQ-008: When reinitialize mode is requested, each supporting resource shall preserve its documented recovery evidence before rebuilding managed state.
- REQ-009: Where a module requires elevation, the resolved plan shall place the Windows sudo prerequisite before that module.
- REQ-010: If a destructive module lacks explicit operator confirmation, then the workstation orchestrator shall prevent its destructive action.
- REQ-011: Where the default module set is used, the workstation orchestrator shall exclude the opt-in debloat profile.
- REQ-012: Where a command is documented for both PowerShell runtimes, the command shall provide equivalent supported behavior in PowerShell 7 and inbox Windows PowerShell 5.1.
- REQ-013: The workstation documentation shall identify Windows 11 Pro as the supported host platform.
- REQ-014: When Windows Sandbox is selected, the feature resource shall order its Hyper-V and parent-feature dependencies before Sandbox.
- REQ-015: When a Windows feature change requires restart, the feature resource shall leave the restart as an explicit operator action.
- REQ-016: The security baseline shall keep hardening, Defender exclusions, SmartScreen, firewall, and debloat as separately selectable state boundaries.
- REQ-017: When the developer hardening profile is applied, the hardening resource shall leave User Account Control policy outside its managed scope.
- REQ-018: Where the debloat profile is selected, the debloat resource shall protect declared development, runtime, security, and access packages from removal.
- REQ-019: When debloat removal is confirmed, the debloat resource shall record its documented pre-removal inventory before changing applications or features.
- REQ-020: When Contour Terminal is ensured, the terminal resource shall remove the legacy Scoop package before installing the verified official release artifact.
- REQ-021: When Contour Terminal is tested after installation, the terminal resource shall reject compliance if the bounded graphics initialization gate fails.
- REQ-022: Where native awk and sed are selected, the text-tool resource shall expose native commands without installing Git Bash, MinGit, MSYS, MSYS2, or Cygwin.
- REQ-023: Where a Linux developer environment is selected, the Linux resources shall keep Debian automation inside Debian and the locked Helm, kubectl, Pulumi, and OpenSSH system closure inside NixOS WSL.
- REQ-024: The developer-tool resources shall keep their pinned isolated environments separate from unrelated Python environments.
- REQ-025: The managed PowerShell profile shall expose the documented aliases, key bindings, discovery commands, and Linux-style command mappings.
- REQ-026: The capability catalog shall expose every route listed in the Capability Coverage Baseline.
- REQ-027: The capability catalog shall associate each route with triggers, evidence kinds, inspection commands, and an explicit capture command.
- REQ-028: When a diagnostic workflow has matching existing evidence, the workflow shall inspect that evidence before recommending another capture.
- REQ-029: When a diagnostic action captures, attaches, kills, disables protection, or changes state, the workflow shall require an explicit human command.
- REQ-030: When Tricky output is requested without a structured-output switch, Tricky shall emit human-readable output.
- REQ-031: When Tricky output is requested with the JSON switch, Tricky shall emit valid JSON for machine consumption.
- REQ-032: The repository shall keep diagnostic, profiling, workstation, and optimization skills focused in separate packages.
- REQ-033: When a profiler is selected, the profiling workflow shall route Python, .NET, and native or system-wide workloads to their declared evidence formats.
- REQ-034: Where machine-local configuration or credentials are required, the repository shall publish a safe sample while excluding the populated local file.
- REQ-035: The operator documentation shall present human commands, representative outputs, privilege boundaries, recovery limits, and residual attack surface for managed capabilities.
- REQ-036: When a public command or routing contract changes, the repository shall update the capability catalog and its operator documentation in the same change.
- REQ-037: When a release is prepared, the publication workflow shall gate it on PowerShell lint, Tricky human and JSON smoke checks, and a strict documentation build.
- REQ-038: Where specification-driven development is selected, the workstation resource shall install a hash-verified released EARS/TDD bundle with its published Spec Kit dependency.
- REQ-039: When normative behavior is specified, the specification workflow shall map each EARS requirement to an automated test selector or a concrete manual verification.
- REQ-040: When behavior-changing tasks are generated, the task workflow shall place each failing test task before its corresponding implementation task.
- REQ-041: When SkillOpt is used, the optimization workflow shall target one explicit skill, retain gating, stage its proposal, and require explicit adoption.
- REQ-042: Where Go development is selected, the workstation resource shall maintain the official MSI-backed package, user workspace command path, built-in compatible toolchain selection, and an unset user GOROOT.
- REQ-043: When released malware hash tooling is selected, the workstation resource shall install the pinned GitHub release asset into a narrow per-user directory and reject a mismatched SHA-256 or embedded version.
- REQ-044: The workstation module catalog shall assign every module to one declared dependency stage with an explicit stage order and runtime boundary.
- REQ-045: When a module plan is requested, the planner shall order selected modules by nondecreasing dependency stage and reject a dependency from an earlier stage to a later stage.
- REQ-046: While the Core stage is not compliant, the workstation orchestrator shall use only inbox Windows PowerShell and built-in Windows commands without resolving or invoking PowerShell 7.
- REQ-047: When the Core stage becomes compliant, the workstation orchestrator shall resolve the installed PowerShell 7 executable before dispatching a module that declares the modern runtime.
- REQ-048: When the managed profile is tested, it shall load successfully in inbox Windows PowerShell 5.1 and the newest installed PowerShell Core with equivalent documented shell behavior.
- REQ-049: When Windows Terminal state is ensured, the terminal resource shall select the installed PowerShell Core profile by default while retaining inbox Windows PowerShell as a selectable profile.
- REQ-050: When shared PowerShell appearance is managed in Windows Terminal, the terminal resource shall apply the same declared appearance to both PowerShell profiles while preserving unrelated terminal settings.
- REQ-051: When Windows Terminal state is tested, the terminal resource shall report settings drift without installing a package or changing the settings file.

### Key Entities

- **Workstation module**: A focused desired-state boundary with order, dependencies, modes, risk metadata, and a human-runnable command.
- **Capability route**: A symptom-oriented mapping from triggers to existing evidence inspection and an explicit capture command.
- **Evidence artifact**: An EVTX, ETL, PCAPNG, dump, profile, snapshot, or report retained for inspection and provenance.
- **Feature requirement**: A stable EARS obligation with one identifier and a verification mapping.
- **Verification mapping**: An automated selector or justified manual procedure associated with one requirement.
- **Local selection**: A populated machine-specific file derived from a safe public sample and excluded from version control.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 46 declared workstation modules appear exactly once in the baseline inventory and dependency plan validation reports no missing dependency or cycle.
- **SC-002**: All 29 declared capability routes appear exactly once in the baseline inventory with at least one inspection command and one explicit capture command.
- **SC-003**: One hundred percent of normative requirements pass the deterministic EARS syntax and traceability gates.
- **SC-004**: One hundred percent of behavior-changing tasks identify requirement coverage and place verification work before implementation work.
- **SC-005**: A contributor can locate a human command, its structured form where applicable, and its privilege boundary for every routed capability from the documentation.
- **SC-006**: The release validation suite completes with zero lint, routing-smoke, or strict-documentation errors.
- **SC-007**: One hundred percent of module dependencies point to the same or an earlier dependency stage, and a plan produced without PowerShell 7 installed reaches the Core prerequisite without command-resolution failure.
- **SC-008**: The managed profile smoke suite passes with equivalent documented behavior in both supported PowerShell runtimes.
- **SC-009**: Windows Terminal opens PowerShell Core by default, retains inbox Windows PowerShell, gives both the same managed appearance, and preserves all unrelated synthetic settings in automated tests.

## Assumptions

- The existing repository on `main` is the brownfield implementation being characterized; migration does not imply that its historical changes were originally test-first.
- Windows 11 Pro is the only supported host baseline for this feature.
- State-dependent and privileged behavior may retain justified manual verification until a safe isolated automated harness exists.
- The module and capability inventories below are frozen migration snapshots; later changes update both the source catalog and this baseline through a new specification change.
- Generated evidence, credentials, licenses, populated local selectors, and workstation-specific paths remain outside version control.

## Module Coverage Baseline

| Module | Primary requirement coverage |
|---|---|
| Sudo | REQ-009 |
| Git | REQ-002, REQ-007 |
| PowerShell7 | REQ-002, REQ-012 |
| PowerShellTesting | REQ-002, REQ-012 |
| Go | REQ-002, REQ-007, REQ-042 |
| Packages | REQ-002, REQ-007 |
| NativeTextTools | REQ-022 |
| Caffeine | REQ-002, REQ-007, REQ-025 |
| Scoop | REQ-002, REQ-007 |
| TerminalFonts | REQ-002, REQ-007 |
| ContourTerminal | REQ-020, REQ-021 |
| WindowsTerminal | REQ-044, REQ-049, REQ-050, REQ-051 |
| WindowsFeatures | REQ-014, REQ-015 |
| Hardening | REQ-016, REQ-017 |
| LinuxHomebrew | REQ-023 |
| LinuxAutomation | REQ-023 |
| NixOsWsl | REQ-023, REQ-034, REQ-035 |
| SharedSshConfig | REQ-023, REQ-025, REQ-034 |
| DeveloperDocker | REQ-023 |
| RootlessPodman | REQ-023, REQ-029 |
| DeveloperTools | REQ-023, REQ-024 |
| SpecDrivenDevelopment | REQ-038, REQ-039, REQ-040 |
| MalwareHashes | REQ-002, REQ-007, REQ-043 |
| QuantResearchEnvironment | REQ-002, REQ-007, REQ-012 |
| MalwareAnalysisTools | REQ-026, REQ-029 |
| SleuthKitCli | REQ-002, REQ-007, REQ-026 |
| Autopsy | REQ-002, REQ-007, REQ-016, REQ-026, REQ-029 |
| NativeForensicTools | REQ-002, REQ-007 |
| MalwareContainerImage | REQ-023, REQ-026, REQ-029 |
| LegacyDockerCleanup | REQ-010, REQ-023 |
| ProfilingTools | REQ-033 |
| SkillOpt | REQ-041 |
| PowerShellProfile | REQ-012, REQ-025, REQ-048 |
| MsvcBuildTools | REQ-001, REQ-002 |
| CMake | REQ-001, REQ-002 |
| RustToolchain | REQ-001, REQ-002 |
| JavaToolchain | REQ-001, REQ-002 |
| NativeDevelopment | REQ-001, REQ-002, REQ-012 |
| FocusFollowsMouse | REQ-001, REQ-006 |
| DefenderExclusions | REQ-016 |
| SmartScreen | REQ-016 |
| WslMemory | REQ-001, REQ-006 |
| Pagefile | REQ-001, REQ-006 |
| EventLogs | REQ-016, REQ-028 |
| Firewall | REQ-016, REQ-029 |
| Debloat | REQ-010, REQ-011, REQ-018, REQ-019 |

## Capability Coverage Baseline

| Capability route | Primary requirement coverage |
|---|---|
| memory-pressure | REQ-026, REQ-028, REQ-033 |
| network-path | REQ-026, REQ-028, REQ-029 |
| crash-analysis | REQ-026, REQ-028, REQ-029 |
| native-performance | REQ-026, REQ-033 |
| python-performance | REQ-026, REQ-033 |
| dotnet-performance | REQ-026, REQ-033 |
| event-history | REQ-026, REQ-028 |
| security-state | REQ-026, REQ-029 |
| malware-triage | REQ-026, REQ-028, REQ-029, REQ-043 |
| autopsy-forensic-analysis | REQ-016, REQ-026, REQ-028, REQ-029 |
| forensic-evidence-verification | REQ-026, REQ-028, REQ-029 |
| workstation-help | REQ-025, REQ-026 |
| repository-quality | REQ-026 |
| powershell-testing | REQ-012, REQ-026 |
| powershell-environment | REQ-025, REQ-044, REQ-048, REQ-049, REQ-050, REQ-051 |
| idle-sleep-inhibition | REQ-025, REQ-026 |
| workstation-modules | REQ-001, REQ-003, REQ-004 |
| linux-developer-packages | REQ-023, REQ-026 |
| go-development | REQ-026, REQ-042 |
| native-development | REQ-002, REQ-012, REQ-026 |
| spec-driven-development | REQ-038, REQ-039, REQ-040 |
| terminal-fonts | REQ-026 |
| native-text-tools | REQ-022, REQ-026 |
| contour-terminal | REQ-020, REQ-021, REQ-026 |
| windows-hardening | REQ-016, REQ-017, REQ-026 |
| windows-debloat | REQ-010, REQ-018, REQ-019, REQ-026 |
| windows-virtualization | REQ-014, REQ-015, REQ-026 |
| desktop-focus | REQ-026 |
| quant-research-environment | REQ-012, REQ-025, REQ-026 |

## EARS requirements

Every normative requirement in this specification uses a stable `REQ-NNN` identifier, exactly one
`shall` obligation, and one of the ubiquitous, event-driven, state-driven, optional-feature, or
unwanted-behavior forms. Design choices and file paths remain in `plan.md`.
