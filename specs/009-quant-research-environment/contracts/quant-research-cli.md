# Quantitative Research Command Contract

## Desired-state command

```powershell
pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 `
    -Mode <Test|Ensure|Reinitialize> `
    [-Project <All|Base|name>] `
    [-ConfirmPyXllInstall] `
    [-Json]
```

`Test` is observational. It resolves the configured root, checks declarations and locks, performs
dry-run/environment consistency checks, compares OpenBB extension metadata without building, runs
frozen/no-sync probes with bytecode and OpenBB auto-build disabled, and inventories global kernels.

`Ensure` is explicit and may create missing declared projects or exact-sync generated environments
from reviewed locks. It may run `openbb-build` only when the installed and built extension
inventories differ. It never starts Jupyter, creates an overlay not already declared, changes a
reviewed lock, or performs relocation.

`Reinitialize` replaces only a selected generated `.venv`. It renames the old environment to a
bounded backup, creates and verifies the replacement at the final path, restores the backup on
failure, and removes no backup until success. It refuses a busy or ambiguously resolved path.

For the base project, all modes also evaluate declared PyXLL state. `Test` is registry/config/file
observational. `Ensure` and `Reinitialize` may activate an existing payload and reconcile the
machine-local config only after all license, architecture, WebView2, and closed-Excel preconditions
pass. If no payload exists, ordinary reconciliation stops and prints the direct first-install
command. Only `-ConfirmPyXllInstall` may launch that vendor-owned interactive workflow; it never
supplies identity or accepts terms on the operator's behalf.

Human output is the default. `-Json` emits exactly one object conforming to
[quant-research-status.schema.json](quant-research-status.schema.json) and performs the same checks.

Exit behavior:

| Condition | Exit |
|---|---:|
| Test reports compliant | 0 |
| Test reports drift or a blocker | nonzero |
| Ensure/Reinitialize reaches compliant | 0 |
| Resolution, sync, build, probe, path, or safety failure | nonzero |

## Overlay creation command

```powershell
pwsh -NoProfile -File .\scripts\New-QuantResearchOverlay.ps1 `
    -Name <name> `
    [-Dependency <package> ...] `
    [-Run] `
    [-Json]
```

Without `-Run`, the command returns a plan and changes nothing. `-Run` stages a new independent
overlay in a temporary sibling, adds the relative base dependency, creates its own lock and
environment, runs probes, and renames the complete staging directory into place. It refuses an
existing destination and never edits the base or another overlay.

The JSON plan/result records `SchemaVersion`, `Name`, `Destination`, `BaseSource`, requested
dependencies, planned commands, `MutationPerformed`, state, warnings, and blockers.

## Notebook command

```powershell
pwsh -NoProfile -File .\scripts\Start-QuantResearchNotebook.ps1 `
    [-Project thesis] `
    [-JupyterArguments <jupyter arguments>]
```

The command validates the selected overlay, snapshots user/system kernelspec directories, then
launches the locked, already-synchronized project JupyterLab in the foreground with no global
kernelspec installation. It forwards `-JupyterArguments` as an array and never invokes a shell-built
command string.

## Profile commands

The managed profile exposes thin wrappers over the same scripts:

| Command | Direct-command equivalent |
|---|---|
| `quant-status [-Project name] [-Json]` | desired-state `Test` |
| `quant-sync [-Project name] [-Json]` | desired-state `Ensure` |
| `quant-rebuild [-Project name] [-Json]` | desired-state `Reinitialize` |
| `quant-overlay -Name name [...]` | overlay plan/create command |
| `quant-notebook [-Project name]` | notebook command |
| `source-relocation-plan [-Target D:\Source] [-Json]` | relocation plan command |

Wrappers contain no alternate implementation logic.
