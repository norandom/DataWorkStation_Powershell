# CLI Contract: Managed Workstation Update

## Human profile command

```powershell
update [-Target <name[]>] [-Run] [-Json]
```

## Direct command

```powershell
pwsh -NoProfile -File ./scripts/Invoke-WorkstationUpdate.ps1 `
  [-Target <name[]>] [-Run] [-Json]
```

The direct script also supports Windows PowerShell 5.1.

## Targets

| Target | Meaning | Automatically included prerequisites |
|---|---|---|
| `All` | Every declared update stage | All below |
| `Windows` | Windows software/security updates | none |
| `WinGet` | Ordinary known-version unpinned applications | none |
| `Scoop` | Scoop, declared buckets, and installed apps | WinGet |
| `Wsl` | WSL runtime | WinGet |
| `Linux` | Both declared Debian package sets | Wsl |
| `Homebrew` | Declared Homebrew instances and unpinned formulae | Linux |
| `Containers` | Developer Docker and Debian-MW Podman reconciliation | Linux |
| `PowerShellEnvironment` | Current-release default desired-state Ensure and Test | WinGet, Scoop, Wsl, Linux, Homebrew, Containers |

Omitting `-Target` is equivalent to `All`. `All` cannot be combined with another target.

## Plan behavior

`update` and the direct script without `-Run` render the resolved plan. They do not call Windows
Update, WinGet upgrade, Scoop update, WSL update, APT, Homebrew, pyinfra resources, or
`Apply-Workstation Ensure`.

## Execution behavior

`update -Run` executes the resolved plan. A failed prerequisite marks dependent stages `skipped`;
independent root stages may continue. Execution never reboots Windows, shuts down WSL, prunes
containers, cleans Scoop versions/caches, includes pinned/unknown WinGet packages, updates drivers,
or discovers distributions.

The command exits nonzero when a selected stage fails or when final desired-state Test reports
drift. A pending restart is a successful terminal state with `RestartRequired=true` unless another
failure occurs.

## JSON schema

```json
{
  "SchemaVersion": 1,
  "Action": "Plan",
  "ReleaseVersion": "2.0.0",
  "SelectedTargets": ["All"],
  "Stages": [
    {
      "Name": "Windows",
      "Order": 10,
      "DependsOn": [],
      "Privilege": "WindowsAdministrator",
      "ChangesState": true,
      "RestartMayBeRequired": true,
      "Status": "planned",
      "Detail": "Install accepted Windows software updates; drivers and automatic restart excluded."
    }
  ],
  "RestartRequired": false,
  "Succeeded": true,
  "NewShellRecommended": false
}
```

Native command output is shown live only in human execution mode. JSON retains bounded normalized
stage detail rather than embedding arbitrary installer output.
