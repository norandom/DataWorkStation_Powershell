# Deferred Source Relocation Contract

## Current command surface

```powershell
pwsh -NoProfile -File .\scripts\Get-SourceRelocationPlan.ps1 `
    [-Source "$env:USERPROFILE\Source"] `
    [-Target 'D:\Source'] `
    [-Json]
```

This feature implements planning only. Human output is the default; `-Json` emits one object
conforming to [source-relocation-plan.schema.json](source-relocation-plan.schema.json).

The current command:

- resolves and inspects exact source, target, backup candidate, and volumes;
- inventories capacity, repositories, generated environments, EFS files, reparse points, and
  active-use risks without following links;
- renders copy, verification, rollback, and environment-rebuild commands as inert text;
- records `PlanOnly=true`, `ExecutionAvailable=false`, `Authorized=false`, and
  `MutationPerformed=false`;
- returns nonzero when blockers make even a future preparation unsuitable.

The current command contains no execution path for copy, move, rename, delete, junction creation,
kernel registration, environment sync, process termination, or handle closure. In particular, it
does not invoke Robocopy without `/L`, `Move-Item`, `Rename-Item`, `Remove-Item`, `mklink`, or
`New-Item -ItemType Junction`.

## Future separately specified execution

A later specification and explicit operator approval are required before adding `Prepare` or
`Commit`. That future contract must bind authorization to the exact plan fingerprint and implement
the state machine in [data-model.md](../data-model.md). It must:

1. copy without purge while the original remains authoritative;
2. require convergence, SHA-256, link, empty-directory, and repository verification;
3. invalidate approval when the source or safety inputs change;
4. require a second explicit confirmation for cutover;
5. rename the original to a readable same-parent backup before creating a junction;
6. roll back by removing only the exact expected junction and restoring the backup name;
7. recreate generated Python environments from reviewed locks;
8. retain both backup and destination until separate operator acceptance.

No current implementation or task may cross this deferred boundary.
