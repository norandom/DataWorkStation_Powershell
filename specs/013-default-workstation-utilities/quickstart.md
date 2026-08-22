# Quickstart: Validate Default Workstation Utilities

All commands below are observational unless an explicit `Ensure` example is selected by the
operator.

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module Mpv -Plan
.\Apply-Workstation.ps1 -Mode Test -Module SafeChain -Plan
pwsh -NoProfile -File .\scripts\Set-MpvState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-SafeChainState.ps1 -Mode Test
pwsh -NoProfile -File .\tests\Test-MpvState.ps1
pwsh -NoProfile -File .\tests\Test-SafeChainState.ps1
ears-sdd validate --feature specs/013-default-workstation-utilities --phase final
```

Expected results:

- Plans show focused modules and Safe-Chain's profile dependency without invoking resources.
- State tests report compliance or actionable drift and do not repair it.
- Contract tests validate package, configuration, integrity, trust, routing, and ownership.
- The final EARS validator reports complete requirement, traceability, and task coverage.

Explicit repair remains a separate operator action:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module Mpv
.\Apply-Workstation.ps1 -Mode Ensure -Module SafeChain
```
