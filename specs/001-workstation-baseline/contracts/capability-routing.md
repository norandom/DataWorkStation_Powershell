# Capability Routing Contract

## Discovery

Human-readable discovery:

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Invoke-Tricky.ps1 capabilities
```

Machine-readable discovery:

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Invoke-Tricky.ps1 capabilities -Json
```

Contract:

- Each capability has a stable ID, title, triggers, evidence kinds, one or more inspection commands,
  and one explicit capture command.
- Human output is the default.
- `-Json` emits parseable JSON without human table decoration.
- Inspection commands precede capture in documentation and skill workflows.
- Discovery prints capture commands but does not execute them.

## Evidence-first behavior

For EVTX, ETL, PCAPNG, dump, profile, and snapshot inputs, the matching inspection command is the
first action. A new capture is a separate human command only after existing evidence is found
insufficient or irrelevant.

## Skill boundary

Each repository-local skill routes one diagnostic or maintenance concern. Skills invoke the same
commands shown to humans and do not introduce hidden capture, elevation, debugger attachment,
process termination, protection changes, or state reinitialization.
