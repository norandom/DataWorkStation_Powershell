# Operate and diagnose the workstation

DataWorkStation PowerShell gives developers one command surface for workstation state, diagnostics,
development tools, and bounded security analysis. Start with `Plan` or `Test`. Use `Ensure`, capture,
debugger attachment, or removal only when you intend to change state.

## Choose a task

| What you need to do | Go here | Safe first action |
|---|---|---|
| Install or verify the workstation | [Install and verify](getting-started.md) | `./Apply-Workstation.ps1 -Mode Test -Plan` |
| Change one managed component | [Select modules and dependencies](workstation-modules.md) | `./Apply-Workstation.ps1 -Mode Test -Module NAME -Plan` |
| Understand managed and explicit state | [Choose desired state](desired-state.md) | Review the mode and privilege boundary |
| Diagnose a failure | [Choose a capability](capabilities/index.md) | Inspect current state and existing evidence |
| Keep investigation evidence together | [Keep evidence in Tricky cases](tricky.md) | `tricky new NAME -Problem '...'` |
| Assess a suspicious file | [Analyze a suspicious file](malware-analysis.md) | `is-this-malware PATH` |
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
