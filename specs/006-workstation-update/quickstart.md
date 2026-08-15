# Quickstart: Managed Workstation Update

## Prerequisites

- Windows 11 Pro with the repository's current PowerShell profile loaded.
- `.wsl-env` names the distinct developer Debian and Debian-MW distribution/user pairs.
- Existing desired-state setup has installed Windows sudo, WinGet, Scoop, WSL, and the selected
  Linux/container modules that should be updated.
- Network connectivity. Close or save important applications and container workloads before Run.

## Review the complete plan

```powershell
update
update -Json
```

Expected outcome: both views contain the same ordered stages and dependency closure. Nothing is
installed, upgraded, restarted, shut down, cleaned, or pruned.

## Review a focused plan

```powershell
update -Target Homebrew,Containers
```

Expected outcome: the plan includes WSL and Linux prerequisites, then the declared developer
Homebrew instance and both existing container-state resources. It does not include Windows Update,
Scoop, or final whole-workstation reconciliation.

## Apply the complete update

```powershell
update -Run
```

Expected outcome: progress is readable stage by stage. Privileged Windows and WSL-root boundaries
are named before execution. The final summary has one terminal state for every stage and reports a
pending restart without performing it.

## Apply only package-manager updates

```powershell
update -Target WinGet,Scoop -Run
```

Expected outcome: existing WinGet pins and Scoop holds remain effective. Scoop old versions and
caches remain available because cleanup is not part of this command.

## Validate without updating the host

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./tests/Test-WorkstationUpdate.ps1
pwsh -NoProfile -File ./tests/Test-WorkstationUpdate.ps1
ears-sdd validate --phase final
```

The automated suite uses synthetic executors. It must not be replaced with a live update run in CI.
