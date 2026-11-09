# Disk and trace cleanup

Windows and trace cleanup are plan-first. Their default commands inspect only; deletion requires `-Run`, and recovery
state has an additional confirmation switch.

## Local configuration

Machine-specific settings now live in the ignored root `config.json`:

```powershell
Copy-Item config.sample.json config.json
workstation-config
workstation-config -Json
```

The file owns the terminal font, four WSL distribution/user boundaries, trace and event-log archive
roots, Defender exclusions, and trace retention. The portable schema is
`config/local-config.schema.json`. Secret-bearing files such as `.licenses.yaml` remain separate;
they are credentials rather than workstation routing settings.

This workstation uses `E:\Traces` for new CPU profiles, ETL, packet captures, development event-log
sessions, dumps, and TTD output. Event-log archives remain separate under `E:\Logs`, so trace cleanup
cannot remove them.

## WSL disk compaction

Preview or compact a named distribution (names are case-insensitive):

```powershell
compact-wsl Debian -WhatIf
compact-wsl Debian
compact-wsl Debian-MW
```

The standalone equivalent is `pwsh -NoProfile -File .\scripts\Invoke-WslCompaction.ps1 -Distribution Debian`.
The command resolves the current user's registered WSL 2 disk, requests administrator rights through
Windows sudo, runs `fstrim /` as Linux root and `sync`, terminates only the selected distribution,
then uses `Optimize-VHD -Mode Full` after verifying the disk has detached. If WSL retains the disk
and no distributions are running, it shuts down the idle WSL VM to release it. It reports before/after
file sizes and reclaimed GiB. A stopped distribution starts briefly for trim, which can start its
normal services. Sessions and containers in that distribution stop; the distribution remains stopped
afterward. Close its work before running the command, and do not start it again during compaction.

`-WhatIf` resolves the target without starting WSL, elevating, or changing the disk. Unknown names,
WSL 1, sparse disks, missing Hyper-V tools, trim failures, and disks that remain attached fail without
attempting compaction. It does not delete Linux files, change virtual capacity, modify sparse policy,
or stop other distributions. Space recovered depends on the free blocks available inside Linux.

## Developer caches and temporary builds

Inspect or configure Windows developer storage explicitly:

```powershell
pwsh -NoProfile -File .\scripts\Set-DeveloperStorage.ps1 -Mode Test -Root D:\BuildArtifacts
pwsh -NoProfile -File .\scripts\Set-DeveloperStorage.ps1 -Mode Ensure -Root D:\BuildArtifacts -MigrateCaches
```

The resource migrates uv, npm, Cargo home, pip, Bun, Go, NuGet, Playwright and Deno caches and the default pnpm store,
keeping compatibility junctions at the original locations. It sets current-user environment variables
for those tools and Cargo build output, sets the public debugger symbol cache, and configures pnpm's global store directory. Existing
project `target` directories are not migrated. `PowerShellProfile` uses the configured
`DEVELOPER_TEMP` directory for `TEMP` and `TMP` in developer shells and child processes.
Developer jobs must run from their repository and use tool/project subdirectories beneath the
artifact root for disposable output. The repository's `AGENTS.md` forbids generated directories at
drive roots. These defaults and instructions do not sandbox unrelated programs or other repositories;
they do not change filesystem ACLs. Pass an explicit build/output directory when a tool does not
honor its cache or temporary-directory settings.
Reopen terminals and development applications after configuration. Kondo handles project build
directories; use package-manager commands such as `uv cache prune` for shared caches.

WSL distributions can be moved while stopped with `wsl --manage Debian --move D:\Debian`.
Use a new destination directory and keep the registered distribution name. `compact-wsl` resolves
the registered path, so it continues to work after relocation.

## Protect drive roots

Inspect root-only write grants with `pwsh -NoProfile -File .\scripts\Set-DriveRootWriteAccess.ps1 -Mode Test`.
Apply explicitly with `sudo pwsh -NoProfile -File .\scripts\Set-DriveRootWriteAccess.ps1 -Mode Ensure -BackupPath D:\BuildArtifacts\acl-backups\drive-roots.json`.
This removes broad root-only write grants from C: and D:, preserving inherited subdirectory rights,
SYSTEM and administrator access. Normal users cannot create new root entries; elevated administrators
can still maintain the drive. Restore the saved DACLs with the same command using `-Mode Restore`
and the exact backup path. No recursive permission reset or deny ACE is applied.

## Windows cleanup

Review the exact plan through Windows sudo. The command remains read-only without `-Run`, but
elevation is needed to inventory restore points and VSS shadow copies accurately:

```powershell
cleanup-windows
cleanup-windows -Json
```

Run the reviewed profile through Windows sudo:

```powershell
cleanup-windows -Run -ConfirmRestorePoints
```

The profile runs DISM component-store cleanup without `/ResetBase`, then runs an allowlisted Disk
Cleanup selection for Windows Update cleanup, delivery-optimization data, setup/upgrade logs,
temporary files, diagnostic archives, and Windows Error Reporting queues. It temporarily assigns a
private `StateFlags` value to every Disk Cleanup handler and restores the previous registry values
afterward, so an existing `cleanmgr` profile is not overwritten.

Microsoft defines `/sagerun` as enumerating all eligible volumes; its `/d` option is ignored in that
mode. The command therefore reports Disk Cleanup as an all-eligible-volume action. The configured
`C:` system volume applies to DISM and restore-point/shadow-copy inventory and deletion. If that
inventory cannot be completed, run mode stops before any cleanup begins.

The profile explicitly preserves Prefetch, live event logs, Direct3D shader cache, thumbnail cache,
crash dumps, minidumps, driver packages, Downloads, Recycle Bin, previous Windows installations,
and Windows ESD files. Preserving Prefetch, shaders, and thumbnails avoids predictable cache rebuilds
and the resulting post-cleanup slowdown. Event-log channels and the archives under `paths.eventLogs`
are outside the cleanup target.

Restore points use the same VSS storage as other shadow copies. The configured profile keeps the
newest C: shadow copy and deletes older copies with `vssadmin`; this is irreversible and can remove
recovery history used by System Restore or Previous Versions. For that reason `-Run` without
`-ConfirmRestorePoints` fails before any cleanup begins. The command never creates a replacement
restore point and never restarts Windows. When no older shadow copies exist, the confirmation is not
required because that destructive action is disabled in the computed plan.

## Trace cleanup

The default retention comes from `cleanup.traces.retentionDays` in `config.json`:

```powershell
cleanup-traces
cleanup-traces -Json
cleanup-traces -RetentionDays 30
cleanup-traces -Run -ConfirmCleanup
```

Only top-level items under the resolved `paths.traces` root whose newest content is older than the
cutoff are candidates. A `state.json` or `session.json` marked active is always preserved. Invalid
session metadata fails safe and is treated as active. Recent items, the trace root itself, paths
outside that root, and the separate event-log archive root are never removed. Use
`-RetentionDays 0` to plan all inactive trace items before choosing whether to run it.
