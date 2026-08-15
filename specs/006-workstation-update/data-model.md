# Data Model: Managed Workstation Update

## UpdateTarget

- `Name`: Stable public selector.
- `Title`: Human-readable stage title.
- `Order`: Deterministic tie-breaker.
- `DependsOn`: Other target names that must succeed first.
- `Privilege`: `CurrentUser`, `WindowsAdministrator`, or `WslRoot`.
- `ChangesState`: Whether execution mutates host or guest state.
- `RestartMayBeRequired`: Whether the stage can leave a pending restart.
- `Executor`: Internal action identifier; never arbitrary user-supplied code.

Validation rules:

- Names are unique and `All` is a selector rather than an executable target.
- Dependencies exist and do not point forward across an invalid boundary or form cycles.
- Order is unique and stable.
- Every executor belongs to the reviewed internal allowlist.

## ManagedLinuxTarget

- `Role`: `Developer` or `MalwareAnalysis`.
- `DistributionVariable`: Required `.wsl-env` distribution key.
- `UserVariable`: Required `.wsl-env` user key.
- `PackageManager`: Debian APT.
- `Homebrew`: Optional declared prefix and executable.
- `ContainerResource`: Existing Docker or Podman state script.

Validation rules:

- Developer and malware distributions differ.
- Homebrew is touched only where explicitly declared.
- Container resource matches the trust role.

## UpdateStageResult

- `Name`: Target name.
- `Status`: `planned`, `succeeded`, `skipped`, `failed`, `restart-required`, or `not-selected`.
- `Detail`: Bounded actionable human detail.
- `ExitCode`: Native or normalized result where applicable.
- `BlockedBy`: Failed prerequisite names.
- `RestartRequired`: Boolean.
- `StartedAt` / `FinishedAt`: Optional execution timestamps.

State transitions:

```text
not-selected -> terminal
planned -> succeeded | restart-required | failed
planned -> skipped (only when a prerequisite failed)
```

Every selected stage reaches exactly one terminal execution status.

## WorkstationUpdateResult

- `SchemaVersion`: Public result schema, initially `1`.
- `Action`: `Plan` or `Run`.
- `ReleaseVersion`: Trimmed `VERSION` value from the current checkout.
- `SelectedTargets`: Requested selectors after validation.
- `Stages`: Ordered `UpdateStageResult` collection.
- `RestartRequired`: Aggregate Boolean.
- `Succeeded`: False when any selected stage failed or final drift remains.
- `NewShellRecommended`: True after PowerShell/package/profile reconciliation.

The result contains no credentials, environment-file contents, package-manager caches, or
unbounded native output.
