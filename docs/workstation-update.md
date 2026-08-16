# Managed workstation update

`update` provides one readable update entry point. Its plan still shows each package manager and
desired-state command.

## Review before changing anything

```powershell
update
update -Json
update -Target Homebrew,Containers
```

These commands print a static dependency plan. They do not scan, download, install, restart, clean,
prune, or reconcile anything. A focused target includes its required prerequisites. The complete
plan has eight stages:

1. accepted Windows software updates;
2. known-version unpinned WinGet applications;
3. Scoop core, declared buckets, and installed applications;
4. the WSL host runtime;
5. packages in declared developer Debian and Debian-MW;
6. declared Homebrew instances and unpinned formulae;
7. developer Docker and Debian-MW rootless Podman reconciliation;
8. current-release default desired-state Ensure and Test.

## Run the reviewed plan

```powershell
update -Run
```

This command uses the network and changes state. It names every privilege boundary and prints each
native command before running it. Windows software installation uses managed Windows sudo. APT and
the existing container pyinfra resources name WSL root explicitly. Homebrew runs as the declared
developer user.

The final stage does not fetch Git or silently adopt another release. It reads the local `VERSION`
and uses the current checkout's ordinary default `Apply-Workstation.ps1 -Mode Ensure`, followed by
Test. That restores managed PowerShell 5.1/Core profiles and stable environment variables after
package installers have changed paths or runtimes. Open a new terminal after successful
reconciliation so the new process receives the updated environment.

## Update boundaries

| Surface | Included | Excluded |
|---|---|---|
| Windows | Applicable software/security updates with already accepted EULAs | Drivers, automatic EULA acceptance, reboot |
| WinGet | `upgrade --all` for known-version unpinned apps | Unknown versions, pinned apps, forced previous-version removal |
| Scoop | Core/bucket refresh and every installed app | Cleanup of old versions or caches, package removal |
| WSL | Supported host runtime update | Automatic distribution shutdown |
| Debian | APT refresh and noninteractive distribution upgrade for the two `.wsl-env` names | Discovery or modification of other distributions |
| NixOS | Current locked generation reconciliation in the final workstation stage | Automatic `flake.lock` rewrite or unreviewed upstream upgrade |
| Homebrew | Declared instances and ordinary unpinned formulae | Undeclared instances and current-release pinned formulae |
| Containers | Existing pyinfra Docker and rootless Podman Ensure | Image/container/volume prune or trust-boundary migration |
| Workstation state | Default non-destructive Ensure and Test from the current checkout | Debloat, legacy Docker data deletion, repository replacement |

Windows servicing skips an update whose EULA has not already been accepted and reports the stage as
failed rather than accepting a license silently. Driver servicing remains separate because GPU and
other vendor drivers need hardware/version validation before replacement.

## Failure and restart behavior

Every selected stage ends as `succeeded`, `restart-required`, `failed`, or `skipped`. A failed
prerequisite blocks only its dependants; independent roots can still report their result. JSON
includes `BlockedBy`, normalized exit codes, an aggregate `RestartRequired`, and
`NewShellRecommended`.

The command never restarts Windows. Linux package upgrades can restart Linux services through their
normal package scripts, and Docker reconciliation may restart its developer daemon if the existing
resource needs repair. Save work and stop sensitive container workloads before `-Run`.

## Direct commands

The profile wrapper and direct script have the same contract:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-WorkstationUpdate.ps1
pwsh -NoProfile -File ./scripts/Invoke-WorkstationUpdate.ps1 -Run
```

Windows servicing can also be inspected independently:

```powershell
powershell.exe -NoProfile -File ./scripts/Invoke-WindowsUpdate.ps1 -Action Scan
sudo powershell.exe -NoProfile -File ./scripts/Invoke-WindowsUpdate.ps1 -Action Install
```
