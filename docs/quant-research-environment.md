# Quantitative research environment

The optional `QuantResearchEnvironment` module manages the runtime boundary around the portable
`%USERPROFILE%\Source\quant-research` repository. It does not own doctoral source, notebooks,
datasets, exports, credentials, or provider keys.

## Project layout

`quant-base` is an installable uv library project with OpenBB and common quantitative packages.
Every direct child under `projects` is a separate uv project with its own `pyproject.toml`,
`uv.lock`, and generated `.venv`. An overlay uses a relative editable source:

```toml
[project]
dependencies = ["quant-base"]

[tool.uv.sources]
quant-base = { path = "../../quant-base", editable = true }
```

This is deliberately not a uv workspace. Each overlay resolves independently; uv's shared cache
still avoids repeated downloads.

## Inspect and reconcile

Status is observational and returns nonzero for drift:

```powershell
quant-status
quant-status -Project thesis -Json
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project All
```

It runs `uv lock --check`, `uv sync --check`, and frozen/no-sync import probes. Python bytecode and
OpenBB auto-build are disabled for probes. OpenBB entry points are compared with generated
reference metadata; status never invokes `openbb-build`.

After reviewing drift, reconcile exactly from the existing lock:

```powershell
quant-sync -Project thesis
quant-rebuild -Project thesis
```

`quant-sync` uses `uv sync --locked` and refreshes OpenBB assets only when stale. `quant-rebuild`
replaces only `.venv`, retains the prior environment until the replacement validates, and restores
it on failure. Neither command adds/removes dependencies or rewrites `pyproject.toml` or `uv.lock`.

## Create an overlay

Planning is the default:

```powershell
quant-overlay -Name event-study -Dependency polars
quant-overlay -Name event-study -Dependency polars -Json
```

Create only after review:

```powershell
quant-overlay -Name event-study -Dependency polars -Run
```

Creation uses a temporary sibling, creates an independent lock/environment, validates imports,
and performs one final rename. Existing destinations are refused. Failed staging is removed without
changing the base or another overlay.

## Start JupyterLab

```powershell
quant-notebook -Project thesis
quant-notebook -Project thesis -JupyterArguments '--no-browser'
```

The direct equivalent is:

```powershell
pwsh -NoProfile -File .\scripts\Start-QuantResearchNotebook.ps1 `
  -Project thesis -JupyterArguments '--no-browser'
```

Jupyter runs through `uv run --locked --no-sync` in the selected overlay. The workflow snapshots
the user and system kernel directories and never runs a kernelspec installation command.

## Credentials and research content

Keep OpenBB provider keys in the provider's supported user credential store or ignored local
environment, never in `config/quant-research.psd1`. The workstation module does not manage
notebooks, source modules, CSV/Parquet data, exports, outputs, `.env*`, or similarly named secret
material. Declare dependency changes with uv inside the owning research project and review its lock.

## Deferred Source relocation

Only a read-only readiness report exists:

```powershell
source-relocation-plan -Target 'D:\Source'
source-relocation-plan -Target 'D:\Source' -Json
```

The report inventories volume suitability, capacity, conflicts, reparse points, encrypted files,
repositories, generated environments, active-use risks, and future verification/rollback steps. It
always reports `planOnly=true`, `executionAvailable=false`, `authorized=false`, and
`mutationPerformed=false`. Any Robocopy preview includes `/L`.

There is no relocation executor. This feature cannot copy Source, rename it, delete it, create a
junction, close handles, or terminate processes. A future separately approved specification must
verify a copy, require fresh confirmation, retain the original under a readable backup name, and
only then create and validate the junction. Until that happens, `C:\Users\mariu\Source` remains
authoritative.
