# Quickstart: PowerShell Test Framework

Inspect the dependency and execution plan without changing state:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan
.\scripts\Set-PesterState.ps1 -Mode Test
```

After reviewing the per-user networked module installation, repair explicitly:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module PowerShellTesting
```

Run the modern lane:

```powershell
test-powershell
test-powershell -Json
```

Run the compatibility lane:

```powershell
test-powershell -Compatibility
```

Expected outcomes:

- Pester 6.1.0 is imported by exact version.
- Eligible files run concurrently with an effective throttle no greater than four.
- Exclusive files remain sequential.
- Windows PowerShell uses the sequential compatibility lane.
- A test failure produces one aggregate result and a nonzero exit code.
- Running tests never installs or upgrades the framework.
