# Operate and diagnose the workstation

DataWorkStation PowerShell provides one command set for workstation state, diagnostics, development
tools, and bounded security analysis. Start with `Plan` or `Test`. Use `Ensure`, capture, debugger
attachment, or removal only when you intend to change state.

Linux troubleshooting tools are often easy to find because their command names and workflows are
widely known. Windows provides powerful debuggers, event logs, ETW, packet capture, dump analysis,
and Sysinternals tools, but they are spread across several interfaces and evidence formats. This
project makes them available through documented PowerShell commands. A sysadmin can run those
commands directly or delegate repetitive evidence handling to an AI while retaining control over
elevation, capture, execution, and repair.

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

This installation uses a GPD Pocket 4 as its concrete example. GPD Pocket systems are popular
portable machines for data-center administrators. The default desired state installs no GPD-only
software. Other Windows 11 Pro workstations use the same commands, and generic sensor commands
report no data when no supported provider is running.

## Choose a task

| What you need to do | Go here | Safe first action |
|---|---|---|
| Install or verify the workstation | [Install and verify](getting-started.md) | `./Apply-Workstation.ps1 -Mode Test -Plan` |
| Change one managed component | [Select modules and dependencies](workstation-modules.md) | `./Apply-Workstation.ps1 -Mode Test -Module NAME -Plan` |
| Update the complete workstation | [Review and run managed updates](workstation-update.md) | `update` |
| Use reproducible Kubernetes/IaC tools | [Reproducible NixOS WSL tools](nixos-wsl.md) | `nixos-check` |
| Investigate NixOS drift or alteration | [NixOS integrity and alteration detection](nixos-integrity.md) | `nixos-check -Json` |
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

This order shows where a command needs elevation, may require a restart, starts a capture, or can
remove data. It also avoids collecting a new trace when retained evidence already has the answer.

## Use one interface

The default output is for people. Automation uses the same commands with `-Json` or `-AsObject`
where supported. Repository-local Codex skills call those commands directly.

`tricky` is the shared case and routing interface. Capability discovery never starts capture.
