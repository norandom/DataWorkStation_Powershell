# Quickstart: Validate the Brownfield Baseline

Run these commands from the repository root. They are ordered from static and read-only checks to
host-dependent checks; no Ensure or Reinitialize command is part of this guide.

## 1. Validate EARS syntax and traceability

```powershell
.\ears-sdd.ps1 validate --project . --phase spec
.\ears-sdd.ps1 validate --project . --phase plan
.\ears-sdd.ps1 validate --project . --phase tasks
.\ears-sdd.ps1 validate --project . --phase final
```

Expected outcome: one feature, 53 requirements, and zero findings at each completed phase.

## 2. Inspect dependency plans

```powershell
.\Apply-Workstation.ps1 -Mode Test -Plan
.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
.\Apply-Workstation.ps1 -Mode Test -Module WindowsFeatures -Plan
.\Apply-Workstation.ps1 -Mode Test -Module Debloat -Plan
```

Expected outcome: dependencies precede dependants; unrelated modules are absent from focused plans;
Debloat is marked privileged and destructive.

Inspect the shell bootstrap boundary from inbox Windows PowerShell. This must work even before
`pwsh.exe` exists:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan
```

## 3. Inspect capability routing

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Invoke-Tricky.ps1 capabilities
$json = pwsh.exe -NoLogo -NoProfile -File .\scripts\Invoke-Tricky.ps1 capabilities -Json
$json | ConvertFrom-Json | Out-Null
```

Expected outcome: human discovery is readable and structured discovery parses successfully.

## 4. Verify the dual-shell Spec Kit resource

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
```

Expected outcome: both runtimes report the released package and `ears-sdd` command as compliant.

Verify the shared managed profile and Windows Terminal state:

```powershell
pwsh.exe -NoLogo -NoProfile -File .\tests\Test-WorkstationBaseline.ps1 -Section PowerShellRuntimes
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-WorkstationBaseline.ps1 -Section PowerShellRuntimes
pwsh.exe -NoLogo -NoProfile -File .\scripts\Set-WindowsTerminalState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Test -Module WindowsTerminal -Plan
```

## 5. Run publication gates

```powershell
pwsh.exe -NoLogo -NoProfile -File .\scripts\Invoke-PowerShellLint.ps1
pwsh.exe -NoLogo -NoProfile -File .\scripts\Test-RepositorySkills.ps1
uv run --group docs mkdocs build --strict
```

Expected outcome: all commands exit successfully. After the characterization task is implemented,
also run:

```powershell
pwsh.exe -NoLogo -NoProfile -File .\tests\Test-WorkstationBaseline.ps1
```

## 6. Keep host mutation explicit

Privileged, destructive, graphics, reboot-pending, package-repair, capture, attach, and protection
changes are not part of this quickstart. Use the corresponding operator documentation and review
its plan before authorizing those commands.
