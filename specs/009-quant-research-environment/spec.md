# Feature Specification: Quantitative Research Environment

**Feature Branch**: `[009-quant-research-environment]`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "Specify a reproducible quantitative-research environment with an OpenBB base, project-specific overlays, local notebook runtimes, and a deferred future relocation of the user Source directory to D: through a Windows directory junction."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run thesis research from one stable base (Priority: P1)

As the researcher, I can open the thesis project and start an interactive notebook with the common quantitative and OpenBB capabilities already available, without selecting or maintaining globally registered kernels.

**Why this priority**: This is the daily research workflow and the minimum useful outcome.

**Independent Test**: Inspect the environment without changing it, start the documented notebook command, and demonstrate imports from the base library and the thesis overlay while the global kernel inventory remains unchanged.

**Acceptance Scenarios**:

1. **Given** a compliant thesis project, **When** the researcher starts its documented notebook command, **Then** the notebook uses the thesis project's isolated environment.
2. **Given** the thesis environment is active, **When** a notebook imports OpenBB, the shared research library, and a thesis-only dependency, **Then** all imports succeed from the project environment.
3. **Given** no globally registered project kernels, **When** the notebook workflow is used, **Then** no global kernels are added.

---

### User Story 2 - Create an independent project overlay (Priority: P2)

As the researcher, I can create another research project that inherits the shared base capabilities, adds only its own requirements, and records an independent reproducible dependency resolution.

**Why this priority**: Separate experiments need different packages without destabilizing the thesis or multiplying unmanaged global environments.

**Independent Test**: Create a sample overlay, add one overlay-only dependency, verify that the base declaration is unchanged, and reproduce the overlay from its recorded project state.

**Acceptance Scenarios**:

1. **Given** a compliant base, **When** a new overlay is created, **Then** it references the base through a location-independent relationship within the research tree.
2. **Given** two overlays, **When** one overlay adds or updates a dependency, **Then** the other overlay and the base remain unchanged.
3. **Given** a clean machine with the declared workstation prerequisite, **When** an overlay is restored from its tracked files, **Then** its dependency set and notebook entry point are reproducible.

---

### User Story 3 - Maintain and diagnose the environment safely (Priority: P3)

As the workstation operator, I can inspect drift, preview changes, repair declared environment state, and verify imports without overwriting notebooks, research code, datasets, credentials, or undeclared project dependencies.

**Why this priority**: The environment must remain maintainable without turning workstation automation into an owner of research content.

**Independent Test**: Introduce bounded package-state drift in a disposable overlay, compare the observational report with the repair plan, apply the repair, and verify both declared state and preserved user content.

**Acceptance Scenarios**:

1. **Given** a missing or inconsistent declared dependency, **When** the operator tests the environment, **Then** the report identifies drift without changing files or installed state.
2. **Given** reviewed drift, **When** the operator explicitly requests repair, **Then** only declared environment state is reconciled.
3. **Given** a dependency conflict, **When** resolution cannot produce a consistent overlay, **Then** the operation fails with an actionable explanation and preserves the last working project state.

---

### User Story 4 - Plan a later Source-directory relocation (Priority: P4, Deferred)

As the workstation operator, I can later request a non-mutating relocation plan for moving the user Source tree to `D:\Source` while preserving its familiar path through a directory junction, and no relocation occurs until a separate explicit authorization.

**Why this priority**: The relocation is useful but is not required for the current research environment and carries a broader data-movement boundary.

**Independent Test**: Request the future relocation plan and verify that it identifies source, destination, conflicts, verification, rollback, and environment-rebuild steps while leaving both drives and the existing Source path unchanged.

**Acceptance Scenarios**:

1. **Given** the current Source directory and no relocation authorization, **When** ordinary environment maintenance runs, **Then** neither the Source directory nor `D:\Source` is moved, renamed, linked, or deleted.
2. **Given** a future request for relocation planning, **When** plan mode runs, **Then** it reports exact paths, prerequisites, conflicts, verification steps, rollback, and the explicit command boundary without changing state.
3. **Given** a failed copy verification or a conflicting destination, **When** a future relocation is attempted, **Then** the original Source directory remains the authoritative recoverable location and no junction replaces it.

---

### User Story 5 - Use PyXLL from the shared OpenBB environment (Priority: P2)

As the researcher, I can call Python-backed quantitative functions and open interactive Plotly charts in Excel through PyXLL, while the Python package remains part of the shared OpenBB environment and the licensed add-in remains machine-local.

**Why this priority**: Excel is a primary quantitative work surface, and one shared runtime avoids a second unmanaged Python environment.

**Independent Test**: In a disposable fixture, reconcile a pre-existing PyXLL payload and local license, then verify the registered Excel add-in, selected `pythonw.exe`, plotting options, terminal license section, and redacted status without exposing the key.

**Acceptance Scenarios**:

1. **Given** the OpenBB base environment and an installed PyXLL payload, **When** explicit reconciliation runs, **Then** Excel is registered to load that payload and PyXLL uses the base environment's `pythonw.exe`.
2. **Given** a valid key in the ignored local license file, **When** PyXLL configuration is rendered, **Then** the active configuration ends with a `[LICENSE]` section containing the key and no status, log, tracked file, or error reveals it.
3. **Given** WebView2 and the declared plotting packages, **When** a PyXLL function returns a Plotly figure, **Then** HTML plotting, SVG fallback, and resizing are enabled in the Excel task pane.
4. **Given** no installed PyXLL payload, **When** ordinary workstation reconciliation runs without first-install confirmation, **Then** it stops with the documented interactive vendor command and does not imply acceptance of vendor terms.
5. **Given** the PyXLL add-in and OpenBB base environment, **When** Excel starts, **Then** the PyXLL ribbon includes its Jupyter Notebook action and opens the declared JupyterLab interface in an Excel task pane.

### Edge Cases

- The selected Python runtime or package source is unavailable.
- The base resolves successfully but an overlay introduces incompatible version constraints.
- The base project is renamed, missing, or outside the common research tree.
- A project lock is stale, corrupt, or inconsistent with its declaration.
- A notebook process or editor still holds files open during maintenance.
- A credential, local dataset, notebook, or user module exists beside managed files.
- `D:` is absent, not a local NTFS volume, has insufficient space, or already contains a `Source` directory.
- The proposed destination contains a junction, symbolic-link loop, or content not present in the source.
- A copied environment contains move-sensitive absolute paths and must be recreated after relocation.
- The copy succeeds but content verification, repository verification, or overlay restoration fails.
- Excel is running while add-in activation or configuration replacement is requested.
- The Excel, Python, and PyXLL architectures do not match.
- The local license file is missing, malformed, or contains no PyXLL key.
- WebView2 is absent, or HTML plotting is disabled in the active PyXLL configuration.

## Requirements *(mandatory)*

### Functional Requirements

- **REQ-001**: The quantitative research environment shall provide one documented human-readable command for observational status and one documented human-readable command for explicit reconciliation.
- **REQ-002**: When machine-readable status is requested, the quantitative research environment shall return structured output representing the same checks as the human report.
- **REQ-003**: The base research project shall declare the supported Python runtime, OpenBB, shared quantitative dependencies, and shared research library as reproducible project state.
- **REQ-004**: The base research project shall record an exact dependency resolution that can be reviewed and restored.
- **REQ-005**: The thesis overlay shall reference the base project through a relative relationship contained within the common research tree.
- **REQ-006**: Each research overlay shall maintain its own project declaration, exact dependency resolution, and isolated runtime environment.
- **REQ-007**: When an overlay adds or updates a project-specific dependency, the environment manager shall preserve the base declaration and every other overlay declaration.
- **REQ-008**: The thesis overlay shall provide an interactive notebook entry point that uses the thesis overlay's runtime environment.
- **REQ-009**: While project notebook workflows are used, the environment manager shall leave the global user and system kernel registries unchanged.
- **REQ-010**: When declared OpenBB extensions change, the environment manager shall refresh and verify the extension inventory before reporting the overlay compliant.
- **REQ-011**: When environment status is requested, the environment manager shall verify the runtime version, base relationship, dependency resolution, notebook entry point, and representative imports without changing state.
- **REQ-012**: If dependency resolution or representative imports fail, then the environment manager shall return an actionable nonzero result without replacing the last recorded project state.
- **REQ-013**: When explicit reconciliation is requested, the environment manager shall change only declared environment files and generated runtime state.
- **REQ-014**: While reconciliation is running, the environment manager shall preserve notebooks, research source, datasets, credentials, exports, and undeclared user content.
- **REQ-015**: The quantitative research environment shall keep credentials and machine-local research data outside tracked portable configuration.
- **REQ-016**: The workstation capability catalog shall route quantitative-environment setup, status, notebook launch, overlay creation, and deferred relocation planning to documented human commands.
- **REQ-017**: While relocation has not been separately authorized, the workstation manager shall leave the current Source directory, `D:\Source`, and all directory-link state unchanged.
- **REQ-018**: When future relocation planning is requested, the workstation manager shall report the exact source and target, local-volume suitability, capacity, conflicts, active-use risks, copy method, verification gates, rollback path, and environment-rebuild steps without changing state.
- **REQ-019**: If the future relocation destination is unsuitable or copy verification fails, then the workstation manager shall stop before renaming the original Source directory or creating a directory junction.
- **REQ-020**: When future relocation is separately confirmed after successful verification, the workstation manager shall retain the original Source tree under a recoverable backup name before creating the directory junction.
- **REQ-021**: When the research tree's physical root changes, the environment manager shall recreate generated overlay environments and reverify each relative base relationship before reporting success.
- **REQ-022**: The quantitative research environment shall remain a focused capability separate from unrelated workstation, diagnostic, profiling, and forensic environment management.
- **REQ-023**: Where PyXLL integration is enabled, the base research project shall declare PyXLL and the selected interactive plotting packages as part of its exact dependency resolution.
- **REQ-024**: When PyXLL status is requested, the environment manager shall observationally verify the base-environment package, Excel/Python/PyXLL architecture compatibility, active Excel add-in registration, active configuration path, selected base `pythonw.exe`, WebView2 availability, plotting options, and license presence without changing state.
- **REQ-025**: When PyXLL reconciliation is explicitly requested and an installed payload is available, the environment manager shall activate the Excel add-in and configure it to use the OpenBB base environment.
- **REQ-026**: Where the ignored local `.licenses.yaml` contains a PyXLL key, the environment manager shall place the key only in the final `[LICENSE]` section of the active machine-local `pyxll.cfg` and never in tracked files.
- **REQ-027**: While PyXLL state is tested or reconciled, the environment manager shall not emit the license key in human output, JSON, logs, errors, process arguments, or verification evidence.
- **REQ-028**: Where interactive plotting is enabled, the active PyXLL configuration shall allow HTML plots, SVG plots, plot resizing, and a machine-local WebView2 user-data directory.
- **REQ-029**: If the license, PyXLL payload, WebView2 runtime, compatible architecture, or closed-Excel prerequisite is missing, then reconciliation shall stop with an actionable explanation before partially activating or rewriting the add-in configuration.
- **REQ-030**: When the PyXLL payload is absent, the environment manager shall require a separate explicit first-install confirmation before launching the vendor's interactive installer.
- **REQ-031**: Where PyXLL Jupyter integration is enabled, the base research project shall declare an exact `pyxll-jupyter` release and JupyterLab 4 or later in its dependency resolution.
- **REQ-032**: When PyXLL Jupyter status is requested, the environment manager shall observationally verify the installed integration package, JupyterLab runtime, PyXLL ribbon entry point, and active Jupyter configuration.
- **REQ-033**: Where PyXLL Jupyter integration is enabled, the active configuration shall select JupyterLab, load exactly one explicit copy of the package-provided ribbon while disabling its automatic ribbon injection, remove duplicate module entries and the colliding installer-example ribbon, prefer a saved workbook's directory, and use the quantitative research root as its fallback notebook directory.

### Key Entities

- **Research Root**: The portable parent directory containing the base project and all research overlays; initially located under the user's existing Source directory.
- **Base Research Project**: The shared OpenBB and quantitative dependency contract plus reusable research code.
- **Project Overlay**: An independently locked research project that references the base and adds project-specific requirements.
- **Dependency Resolution**: The exact, reviewable package graph used to reproduce a base or overlay environment.
- **Notebook Entry Point**: The documented project-local action that starts interactive research without registering a global kernel.
- **Environment Status**: Observed compliance results for runtime, dependency, relationship, extension, notebook, and import checks.
- **Relocation Plan**: A deferred, non-mutating description of the future Source move, validation gates, recovery path, and directory junction.
- **PyXLL Integration State**: The relationship among the base environment, installed PyXLL payload, Excel add-in registration, active configuration, WebView2 runtime, and plotting prerequisites.
- **Local License Store**: An ignored machine-local YAML file whose PyXLL value may be read for reconciliation but is never part of portable or reported state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A researcher can start a working thesis notebook from the documented command in under two minutes after the environment is synchronized.
- **SC-002**: One hundred percent of declared representative base and thesis imports pass after a successful reconciliation.
- **SC-003**: Creating and restoring a new overlay requires no changes to the base or existing overlays and completes in under ten minutes on the supported workstation with normal network access.
- **SC-004**: Repeated observational status checks produce zero managed or user-file changes.
- **SC-005**: Project notebook use creates zero global user or system kernel registrations.
- **SC-006**: A failed dependency resolution preserves one hundred percent of the previously recorded project declarations and user research content.
- **SC-007**: A future relocation plan identifies all required safety gates and produces zero filesystem changes before explicit relocation authorization.
- **SC-008**: After any later approved relocation, all tracked repositories and overlay dependency relationships pass verification before the familiar Source path is declared operational.
- **SC-009**: One hundred percent of PyXLL status and reconciliation outputs contain zero license-key characters or values.
- **SC-010**: After successful PyXLL reconciliation, Excel's active add-in, configured Python executable, and all four interactive-plot prerequisites pass verification.
- **SC-011**: Repeated PyXLL observational checks produce zero registry, configuration, environment, or user-file changes.
- **SC-012**: After reconciliation and an Excel restart, the PyXLL ribbon exposes one working Jupyter Notebook action backed by JupyterLab 4 or later from the OpenBB environment.

## Assumptions

- The initial research root is `C:\Users\mariu\Source\quant-research`; moving it is not part of the current rollout.
- The currently created base and thesis projects are brownfield state and will be characterized before any behavior-changing implementation.
- The workstation already provides the selected environment manager and a supported Python 3.12 runtime.
- OpenBB is the common financial-data base; individual provider credentials remain user-owned and untracked.
- Research datasets, notebook outputs, exports, secrets, and doctoral source material are outside workstation desired-state ownership.
- Overlays with irreconcilable dependency constraints remain separate projects rather than being forced into one environment.
- The future relocation target is intended to be a local NTFS volume at `D:\Source`; network shares and removable media are excluded.
- The future directory junction preserves `C:\Users\mariu\Source` as the familiar logical path, but its creation requires a separate explicit relocation operation.
- The original Source tree is retained under a recoverable backup name until post-relocation verification is accepted by the operator.
- The licensed PyXLL payload and active configuration are machine-local generated state; the package declaration and non-secret desired settings are portable.
- The operator owns vendor identity, license entitlement, and first-install consent; automation does not invent or commit any of them.
