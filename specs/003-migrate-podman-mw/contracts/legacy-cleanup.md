# Legacy Debian-MW Docker Cleanup Contract

## Inspection

```powershell
./Apply-Workstation.ps1 -Mode Test -Module LegacyDockerCleanup -Plan
pwsh -NoProfile -File ./scripts/Remove-LegacyDockerMwState.ps1 -Mode Test
pwsh -NoProfile -File ./scripts/Remove-LegacyDockerMwState.ps1 -Mode Test -Json
```

Inspection resolves and reports only the declared legacy paths, ownership, presence, and size. It
does not delete anything. A retained result is expected until cleanup is deliberately selected.

## Destructive cleanup

```powershell
./Apply-Workstation.ps1 -Mode Ensure -Module LegacyDockerCleanup -ConfirmDestructive
```

Cleanup is non-default and depends on compliant RootlessPodman state. It refuses unresolved paths,
symlinks, unexpected ownership, `/`, the distribution root, a user home itself, Podman storage, and
anything outside the exact declared Docker subpaths. It removes only retained legacy Docker data and
reports the resolved deleted paths. WSL distribution removal is never part of this module.
