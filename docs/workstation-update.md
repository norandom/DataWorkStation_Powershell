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

## Check release pins

```powershell
update -Check
update -Check -Json
```

Unlike the static plan, `-Check` makes read-only HTTPS requests to the official GitHub Releases API.
It reads current versions directly from their owning configuration files through
`config/software-updates.psd1`, so the update catalog does not contain a second copy of a version.
It currently covers the GitHub-backed Contour, Autopsy, NixOS-WSL, OpenCode, CodeQL, capa, Ghidra,
malware_hashes, Quarto, Sleuth Kit, Spec Kit EARS/TDD, and Fira Code releases. Repeated declarations
such as OpenCode and NixOS-WSL are grouped and reported as `inconsistent-pin` when they disagree.

The detector reports `current`, `update-available`, `ahead`, `inconsistent-pin`, or `error`. When
GitHub exposes a SHA-256 asset digest, it is included as review evidence. The command never edits a
version, URL, hash, signature, MSI identity, installed-tree digest, container inventory, or forensic
certification record. A version remains the release selector; the other values remain integrity
locks that must be reviewed and refreshed for that release. `-Check` and `-Run` are mutually
exclusive.

For deterministic GitHub layouts, installers call `Resolve-PinnedSoftwareReleaseAsset` from
`scripts/SoftwareRelease.Core.ps1`. The catalog owns the repository, tag template, and asset-name
template, while the owning package configuration keeps the current version and integrity lock.
This removes version copies from download URLs for Contour, NixOS-WSL, OpenCode Desktop, CodeQL,
capa, malware_hashes, Quarto, and Fira Code. Assets whose names or packaging are not predictable,
such as dated Ghidra archives or the current Spec Kit migration, remain explicit review cases.

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
| Debian | APT refresh and noninteractive distribution upgrade for the two `config.json` Debian names | Discovery or modification of other distributions |
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
pwsh -NoProfile -File ./scripts/Invoke-WorkstationUpdate.ps1 -Check
pwsh -NoProfile -File ./scripts/Invoke-WorkstationUpdate.ps1 -Run
```

Windows servicing can also be inspected independently:

```powershell
powershell.exe -NoProfile -File ./scripts/Invoke-WindowsUpdate.ps1 -Action Scan
sudo powershell.exe -NoProfile -File ./scripts/Invoke-WindowsUpdate.ps1 -Action Install
```
