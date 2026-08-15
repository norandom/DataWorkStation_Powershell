# Operate and diagnose the workstation

DataWorkStation PowerShell gives developers one command surface for workstation state, diagnostics,
development tools, and bounded security analysis. Start with `Plan` or `Test`. Use `Ensure`, capture,
debugger attachment, or removal only when you intend to change state.

<table>
  <tr>
    <td><img src="assets/workstation/powershell-workstation.png" alt="PowerShell workstation showing memory and managed firewall commands"></td>
    <td><img src="assets/workstation/contour-neovim.png" alt="Contour Terminal running Neovim with the configured terminal appearance"></td>
  </tr>
  <tr>
    <td>Human-readable workstation inspection from PowerShell.</td>
    <td>Contour Terminal and Neovim using the configured developer environment.</td>
  </tr>
</table>

## Choose a task

| What you need to do | Go here | Safe first action |
|---|---|---|
| Install or verify the workstation | [Install and verify](getting-started.md) | `./Apply-Workstation.ps1 -Mode Test -Plan` |
| Change one managed component | [Select modules and dependencies](workstation-modules.md) | `./Apply-Workstation.ps1 -Mode Test -Module NAME -Plan` |
| Update the complete workstation | [Review and run managed updates](workstation-update.md) | `update` |
| Understand managed and explicit state | [Choose desired state](desired-state.md) | Review the mode and privilege boundary |
| Diagnose a failure | [Choose a capability](capabilities/index.md) | Inspect current state and existing evidence |
| Keep investigation evidence together | [Keep evidence in Tricky cases](tricky.md) | `tricky new NAME -Problem '...'` |
| Assess a suspicious file | [Analyze a suspicious file](malware-analysis.md) | `is-this-malware PATH` |
| Compare a clean run or two binary graphs | [Analysis and differencing cases](analysis-differencing.md) | `sandbox-behavior-control PATH` or `binary-diff OLD NEW` |
| Extend the project test-first | [Specification-driven development](spec-driven-development.md) | Validate the current specification state |
| Look up a command | [Commands and aliases](Aliases.md) | Search by task or command name |

## Work safely

1. Define the target and expected state or behavior.
2. Inspect the dependency plan or existing EVTX, ETL, PCAPNG, dump, profile, and snapshot evidence.
3. Run the observational `Test` or inspection command.
4. Identify the exact state or evidence gap.
5. Run the smallest explicit repair or capture command that closes that gap.

This order keeps privilege, restart, capture, and destructive boundaries visible. It also avoids a
new trace when the answer already exists in retained evidence.

## Use one interface

Humans use the default readable output. Automation uses the same commands with `-Json` or
`-AsObject` where supported. Repository-local Codex skills compose those commands but do not hide a
second implementation.

`tricky` is the shared case and routing interface. Capability discovery never starts capture.
