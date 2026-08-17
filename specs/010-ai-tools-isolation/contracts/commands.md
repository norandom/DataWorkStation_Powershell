# Command Contracts: AI Tools and WSL Isolation

## Desired-state commands

```powershell
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test -Json
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Ensure

pwsh -NoProfile -File .\scripts\Set-DeveloperEditorState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-AiNixOsWslState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1 -Json
```

Test and Plan are observational. Ensure may download and execute the declared vendor installers,
install/update packages, create or restart only the selected WSL distribution, and merge owned
editor settings. It never unregisters a distribution or silently substitutes a source.

Human output lists product/distribution, target, source or trust role, status, and pending action.
JSON uses schema version 1 and represents the same checks. Drift exits 1; altered integrity or a
failed secure launch prerequisite exits 2 where the command distinguishes it.

## Managed OpenCode launch

```powershell
pwsh -NoProfile -File .\scripts\Invoke-OpenCodeSandbox.ps1 -Project /home/ai/projects/project
```

The Windows command selects a private AI-WSL project; the guest launcher
validates the immutable policy and enforcement, then runs OpenCode through `nono`. It never falls
back to unsandboxed OpenCode. `-Json` is status-only and does not launch an interactive agent.

## Debian-MW case transfer

```powershell
pwsh -NoProfile -File .\scripts\Import-MalwareCase.ps1 -Source D:\Cases\input -CaseId case-20260817
pwsh -NoProfile -File .\scripts\Export-MalwareCase.ps1 -CaseId case-20260817 -Destination D:\Cases\output
```

Both commands are explicit state changes. They validate bounded paths and entry types, use streamed
archives rather than guest Windows mounts, calculate evidence identities, and emit a human receipt
or equivalent schema-version-1 JSON. Existing case/output targets are not overwritten.

## Orchestrator modules

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module DeveloperEditor
.\Apply-Workstation.ps1 -Mode Test -Module AiTools,AiNixOsWsl
.\Apply-Workstation.ps1 -Mode Ensure -Module AiTools,AiNixOsWsl
```

`AiTools` and `AiNixOsWsl` remain absent from `All` unless explicitly selected.
