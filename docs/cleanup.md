# Disk and trace cleanup

Cleanup is plan-first. The default commands inspect only; deletion requires `-Run`, and recovery
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
