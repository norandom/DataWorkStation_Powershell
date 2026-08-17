# Data Model: Quantitative Research Environment

## ResearchRoot

The portable container for the shared base and all independent overlays.

| Field | Meaning |
|---|---|
| `ConfiguredPath` | Portable path containing an environment-variable reference. |
| `ResolvedPath` | Absolute path resolved for the current user during execution. |
| `BaseRelativePath` | Relative path to the base project. |
| `OverlayParentRelativePath` | Relative path containing overlays. |
| `State` | `Absent`, `Partial`, `Compliant`, `Drifted`, or `Blocked`. |

Validation rules:

- The configured path is user-relative and contains no committed username.
- The resolved path stays inside the configured Source tree.
- The base and overlay parent cannot resolve through an undeclared reparse point.
- User files outside declared project/environment paths are not owned by workstation state.

## BaseResearchProject

The installable shared package containing common OpenBB and quantitative dependencies plus reusable
research code.

| Field | Meaning |
|---|---|
| `Name` | Stable package name, initially `quant-base`. |
| `ProjectPath` | Path relative to `ResearchRoot`. |
| `PythonRequirement` | Supported Python line. |
| `RequiredDependencies` | Minimum common dependency set. |
| `ProjectDeclaration` | Portable dependency and package declaration. |
| `Lock` | Exact independently reviewable base resolution. |
| `ImportProbes` | Modules that must import in a fresh process. |
| `State` | `Absent`, `Unlocked`, `Unsynchronized`, `Compliant`, or `Blocked`. |

The base lock is useful for developing and testing the base itself. An overlay does not inherit this
lock; it resolves the base declaration into its own lock.

## ProjectOverlay

An independently reproducible project extending the base.

| Field | Meaning |
|---|---|
| `Name` | Unique directory and logical project name. |
| `RelativePath` | Path below the overlay parent. |
| `BaseSource` | Relative editable path from the overlay to `BaseResearchProject`. |
| `PythonRequirement` | Runtime constraint compatible with the base. |
| `Dependencies` | Overlay-owned runtime requirements. |
| `DevelopmentDependencies` | Overlay-owned notebook and test tooling. |
| `Lock` | Overlay-specific exact resolution. |
| `EnvironmentPath` | Generated `.venv` path owned by the overlay. |
| `ImportProbes` | Base and overlay modules used for verification. |
| `NotebookEnabled` | Whether a notebook entry point is declared. |
| `State` | `Absent`, `Unlocked`, `Unsynchronized`, `Compliant`, or `Blocked`. |

Validation rules:

- Names are normalized, unique, and cannot escape the overlay parent.
- `BaseSource` is relative, resolves to the declared base, and stays within `ResearchRoot`.
- Every overlay has its own declaration and lock.
- Overlay mutation cannot change the base or another overlay declaration.
- A missing or stale lock blocks locked reconciliation.

State transitions:

```text
Absent -> Staged -> Locked -> Synchronized -> Verified -> Compliant
                \-> ResolutionFailed
Locked/Synchronized -> Drifted -> Synchronized
Any non-compliant state -> Blocked when path or safety validation fails
```

Staging occurs in a new temporary sibling and is renamed into place only after lock, sync, and probe
success. Existing non-empty destinations are never adopted implicitly.

## DependencyResolution

The exact package graph for one base or overlay project.

Fields: project-relative lock path, lock digest, Python markers, direct requirements, local source
relationships, resolved package/version/source records, checked-at time, and consistency result.

The status path checks consistency without writing. Reconciliation accepts the existing lock and
may only update generated environment state.

## NotebookRuntime

The project-local interactive runtime for a notebook-enabled overlay.

| Field | Meaning |
|---|---|
| `OverlayName` | Owning overlay. |
| `Command` | Locked project command used to launch JupyterLab. |
| `ExecutablePath` | Jupyter executable resolved inside the overlay environment. |
| `KernelExecutable` | Python executable resolved inside the overlay environment. |
| `GlobalKernelSnapshot` | User/system kernelspec paths and identities before or after a smoke test. |
| `State` | `Unavailable`, `Ready`, `Running`, or `Blocked`. |

No global kernelspec is part of desired state. Launching is an explicit foreground user action, not
an Ensure side effect.

## OpenBBExtensionState

The relationship between installed OpenBB extensions and the generated OpenBB reference inventory.

Fields: overlay, installed entry-point identities, built reference identities, declared provider
probes, auto-build-disabled observation result, refresh-required boolean, and verification state.

State transitions:

```text
Current -> ExtensionChanged -> RefreshRequired -> Built -> FreshProcessVerified -> Current
                                    \-> BuildFailed
Built -> VerificationFailed
```

Status never invokes the `Built` transition. Explicit reconciliation owns build and fresh-process
verification.

## EnvironmentStatus

One human/JSON parity result for the configured research environment.

Fields: schema version, mode, timestamp, resolved root, overall state, mutation-performed boolean,
base result, overlay results, global kernel inventory, blockers, warnings, and suggested human
commands.

Overall state is `compliant` only when the base and all declared overlays are locked, synchronized,
relationship-valid, probe-valid, and extension-current. Missing optional user overlays are not
inventoried unless declared.

## PyXllIntegrationState

The machine-local bridge from Excel to the base OpenBB environment.

| Field | Meaning |
|---|---|
| `Enabled` | Whether PyXLL integration is declared. |
| `PackageVersion` | Exact PyXLL version required by the base lock. |
| `PayloadPath` | Existing machine-local folder containing `pyxll.xll`. |
| `AddInRegistered` | Whether current-user Excel options load that exact XLL. |
| `PythonExecutable` | Expected base `.venv\Scripts\pythonw.exe`. |
| `ConfigurationPath` | Active machine-local `pyxll.cfg`. |
| `WebView2Available` | Whether the runtime needed for interactive HTML plots is present. |
| `PlottingOptions` | Expected HTML, SVG, resizing, and WebView2 data-folder settings. |
| `JupyterIntegration` | Exact integration package, JupyterLab runtime, ribbon entry point, and active `[JUPYTER]` policy. |
| `LicensePresent` | Redacted boolean only. |
| `State` | `Unavailable`, `Drifted`, `ReadyForActivation`, `Compliant`, or `Blocked`. |

The license value is deliberately not part of this entity. It is transient input from the ignored
`LocalLicenseStore`; it may be compared and rendered but cannot be serialized into status.

The Jupyter kernel runs inside Excel's PyXLL interpreter. It therefore shares the OpenBB base
environment and is not a separately selectable kernel or global kernelspec.

State transitions:

```text
Unavailable -> InteractiveInstallConfirmed -> PayloadInstalled -> ReadyForActivation
ReadyForActivation -> AddInActivated -> Configured -> Compliant
Any state -> Blocked when Excel is open or architecture/prerequisites are incompatible
```

## RelocationPlan

A read-only assessment for a future Source move.

| Field | Meaning |
|---|---|
| `SourcePath` / `TargetPath` | Exact resolved endpoints. |
| `BackupPath` | Collision-free same-parent recovery name. |
| `SourceVolume` / `TargetVolume` | Drive type, filesystem, health, capacity, and free-space facts. |
| `ReparsePoints` | Link path, type, target, disposition, and blocker. |
| `EncryptedFiles` | EFS items requiring a separate procedure. |
| `GeneratedEnvironments` | Exact environments eligible for copy exclusion and recreation. |
| `Repositories` | Relative repository path, head, status digest, and planned integrity check. |
| `ActiveUseRisks` | Processes or incomplete visibility that prevent Commit. |
| `CopyPreview` | Non-purging copy command and outside-tree log path. |
| `VerificationSteps` | Convergence, content, link, and repository gates. |
| `RollbackSteps` | Exact junction-only removal and backup-rename recovery actions. |
| `PlanFingerprint` | Digest binding all safety-critical inputs. |
| `Blockers` / `Warnings` | Conditions that prevent or qualify later authorization. |

Plan always records `Authorized=false` and `MutationPerformed=false`.

## RelocationTransaction

A future explicitly authorized transaction bound to one fresh `RelocationPlan`.

Fields: transaction ID, plan fingerprint, source/target/backup, preparation timestamp, copy log,
source and target manifest digests, repository results, approval stage, operator confirmations,
cutover actions, environment rebuild results, final state, and rollback result.

State transitions:

```text
Observed -> Blocked | ReadyToPrepare
ReadyToPrepare -> Copying -> CopyFailed | CopiedUnverified
CopiedUnverified -> Verified -> VerificationStale | ReadyToCommit
ReadyToCommit -> BackupRenamed -> JunctionCreated -> Rebuilding
Rebuilding -> Operational | RolledBack
```

There is no transition from `Observed` or `Blocked` directly to rename or junction creation. Any
source change, unresolved link, active-use risk, copy mismatch, repository failure, or stale plan
returns the transaction to a non-commit state.
