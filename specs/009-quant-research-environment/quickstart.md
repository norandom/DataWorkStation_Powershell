# Quickstart: Quantitative Research Environment

This is the intended operator workflow after feature implementation. Commands are PowerShell 7 examples. The initial research root remains `C:\Users\mariu\Source\quant-research`.

## Prerequisites

- Apply the workstation `Packages` and `PowerShellProfile` dependencies first.
- Keep `quant-base` and all overlays inside one portable `quant-research` tree.
- Track each `pyproject.toml` and `uv.lock`; do not track `.venv`, credentials, datasets, notebook outputs, or exports.
- Run commands from outside an active notebook process when reconciling or rebuilding its environment.

## Inspect without changing state

Preview workstation routing:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module QuantResearchEnvironment -Plan
.\Apply-Workstation.ps1 -Mode Test -Module QuantResearchEnvironment -Plan -Json
```

Run the direct human and machine-readable status commands:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project All
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project All -Json
```

These checks must not synchronize packages, refresh OpenBB assets, write bytecode, alter project files, or register a kernel. A drift result is actionable and nonzero.

## Reconcile reviewed locked state

After reviewing status output, explicitly synchronize one overlay:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Ensure -Project thesis
```

Use `Reinitialize` only when the generated `.venv` must be replaced. It preserves the prior environment until the replacement validates and never treats research content as generated state.

## Enable the licensed Excel integration

Copy `.licenses.yaml.sample` to the ignored `.licenses.yaml` and enter the local PyXLL key there.
Do not add the file to Git. Review PyXLL state first:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project Base
```

The first payload download is an explicit interactive vendor step:

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 `
    -Mode Ensure -Project Base -ConfirmPyXllInstall
```

Close Excel before running it. Subsequent `Ensure` runs maintain the registered add-in and active
configuration without repeating first-install consent. The configuration selects the OpenBB base
environment and enables interactive HTML plots, SVG fallback, resizing, and a local WebView2 data
folder. Status and logs never contain the key.

## Create an independent overlay

Preview first:

```powershell
quant-overlay -Name event-study -Dependency polars -Plan
quant-overlay -Name event-study -Dependency polars -Plan -Json
```

Create after review:

```powershell
quant-overlay -Name event-study -Dependency polars -Run
```

The new overlay receives its own `pyproject.toml`, `uv.lock`, and `.venv`, with a relative editable dependency on `../../quant-base`. The command refuses an existing destination and does not modify the base or another overlay.

## Start the thesis notebook

```powershell
quant-notebook -Project thesis -JupyterArguments '--no-browser'
```

This launches JupyterLab through the thesis lock and `.venv`. It does not install a user or system kernelspec.

## Inspect the deferred relocation plan

The relocation command is intentionally observational:

```powershell
source-relocation-plan -Target 'D:\Source'
source-relocation-plan -Target 'D:\Source' -Json
```

The JSON result must state:

```json
{
  "planOnly": true,
  "executionAvailable": false,
  "authorized": false,
  "mutationPerformed": false
}
```

Do not interpret a ready plan as permission to copy, rename, delete, or create a junction. Device-link execution belongs to a separate future specification and explicit authorization.

## Implementation acceptance

```powershell
pwsh -NoProfile -File .\tests\Test-QuantResearchEnvironment.ps1 -Section All
Invoke-Pester .\tests\pester\QuantResearchEnvironment.Tests.ps1
ears-sdd validate --phase implementation
lint-powershell
uv run --group docs mkdocs build --strict
```

Also run direct and `tricky ... -Json` smoke tests for environment status and relocation planning, and confirm their human/JSON checks remain equivalent.
