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

## PyXLL for Excel

PyXLL, Plotly, and Kaleido are declared in `quant-base`; PyXLL is configured to use that project's
`.venv\Scripts\pythonw.exe`. Copy `.licenses.yaml.sample` to the ignored `.licenses.yaml` and enter
the licensed key under `pyxll.key`. The value is rendered only into the final `[LICENSE]` section of
the active machine-local `pyxll.cfg`; status, JSON, logs, and tracked files never contain it.

Inspect the integration without changing Excel, the registry, or configuration:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project Base
```

Close Excel first. If no payload has previously been installed, launch the official interactive
first-install workflow explicitly:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 `
  -Mode Ensure -Project Base -ConfirmPyXllInstall
```

The operator completes vendor identity and terms prompts. Once a payload exists, ordinary
`quant-sync -Project Base` maintains activation and configuration without repeating that consent.
Interactive HTML plotting, SVG support, resizing, and a machine-local WebView2 data folder are
enabled. Microsoft WebView2 Runtime is a required precondition.

The same base also declares `pyxll-jupyter==0.7.1` and JupyterLab. Desired state verifies the
package's `pyxll` entry points but loads the packaged ribbon XML explicitly. It sets the package's
automatic ribbon injection off so the same controls cannot be registered twice. It also removes
the installer example ribbon because that XML uses the same tab ID and would rename the merged tab
to **PyXLL Example Tab**. The resulting **PyXLL** tab contains the integration's one large Jupyter
split button: its menu opens Jupyter inside Excel or in a browser, and a cell's context menu contains
**Send to Jupyter**. The managed `[JUPYTER]` section uses JupyterLab, opens saved workbooks from their
directory, and otherwise starts at the quantitative research root. Close and reopen every Excel
process after package/config changes; ribbon XML is read at add-in load.

If Excel opens only an **Open** dialog after a ribbon edit, inspect the existing PyXLL log before
capturing anything. Duplicate `PyXLLJupyterNotebook` IDs mean both automatic and explicit copies
were loaded. Close every Excel process before reconciliation. If accepted normal closes leave
headless `EXCEL.EXE` processes, review their PIDs and terminate only those confirmed instances
before running the Ensure command again. A clean startup has one Jupyter split button and no new
PyXLL warning or error.

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
