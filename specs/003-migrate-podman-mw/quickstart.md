# Quickstart: Validate the Debian-MW Podman Migration

All commands run from the repository root. Start with observational commands.

## 1. Review module order and current state

```powershell
./Apply-Workstation.ps1 -Mode Test -Module RootlessPodman -Plan
pwsh -NoProfile -File ./scripts/Set-RootlessPodmanState.ps1 -Mode Test
pwsh -NoProfile -File ./scripts/Set-RootlessPodmanState.ps1 -Mode Test -Json
```

Before migration, drift is expected: Docker is present and Podman may be absent. Output must state
that Test changed nothing and that legacy storage is retained.

## 2. Run repository contract tests

```powershell
pwsh -NoProfile -File ./tests/Test-RootlessDockerState.ps1
pwsh -NoProfile -File ./tests/Test-MalwareAnalysis.ps1 -Section RootlessContainer
pwsh -NoProfile -File ./tests/Test-MalwareContainerAnalysis.ps1 -Section Planning
pwsh -NoProfile -File ./tests/Test-MalwareContainerAnalysis.ps1 -Section ImageContract
```

These use source and synthetic state records. They do not migrate Debian-MW or start an analysis
container.

## 3. Explicitly migrate the runtime

Review the [state contract](contracts/podman-state.md), then run:

```powershell
./Apply-Workstation.ps1 -Mode Ensure -Module RootlessPodman
```

This performs networked package changes as WSL root, initializes rootless Podman as the selected
malware user, stops and removes the old Docker runtime only after Podman validates, and retains
legacy Docker data. It does not build the parser image.

Verify directly:

```powershell
malware-container-status
wsl-mw podman info --format json
```

The state must report local rootless Podman and no active Podman API service/socket.

## 4. Explicitly build the parser image

```powershell
./Apply-Workstation.ps1 -Mode Test -Module MalwareContainerImage -Plan
pwsh -NoProfile -File ./scripts/Set-MalwareContainerImageState.ps1 -Mode Test
pwsh -NoProfile -File ./scripts/Set-MalwareContainerImageState.ps1 -Mode Ensure
```

Ensure is a separate networked large build. It must use Podman and validate all 21 declared tools.

## 5. Validate a repository-owned benign fixture

```powershell
malware-container ./path/to/repository-owned-benign-fixture
malware-container ./path/to/repository-owned-benign-fixture -Run -ConfirmContainer
```

Review the plan before Run. The case must identify Podman, remain static-only and networkless, and
produce an `undetermined` non-verdict with a terminal status for every applicable tool.

## 6. Review legacy data cleanup separately

```powershell
./Apply-Workstation.ps1 -Mode Test -Module LegacyDockerCleanup -Plan
```

Do not run Ensure unless the reported Docker paths are no longer needed. Cleanup requires the
separate command and confirmation documented in [legacy-cleanup.md](contracts/legacy-cleanup.md).
