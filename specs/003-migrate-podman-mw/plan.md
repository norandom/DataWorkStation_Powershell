# Implementation Plan: Migrate Debian-MW to Podman

**Branch**: `003-migrate-podman-mw` | **Date**: 2026-08-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-migrate-podman-mw/spec.md`

## Summary

Replace the long-running rootless Docker daemon in the dedicated Debian-MW WSL distribution with
Debian's local rootless Podman runtime. Preserve the high-level malware-analysis and evidence
contracts, rebuild the declared OCI parser image explicitly in Podman's separate store, and remove
runtime-specific PowerShell aliases. The migration is staged: observational inspection, Podman
provisioning, rootless/local/no-socket validation, then Docker package and service retirement.
Legacy Docker data is retained until a separate destructive module is explicitly confirmed.

## Technical Context

**Language/Version**: PowerShell 7 with documented Windows PowerShell 5.1 compatibility; Python
3.13 for pyinfra and existing bounded parser/evidence helpers

**Primary Dependencies**: WSL 2, Debian 13, distribution-maintained Podman 5.x, uidmap,
fuse-overlayfs, passt, pyinfra 3.9.2, existing OCI image source and malware-analysis commands

**Storage**: Rootless Podman storage below the selected Linux user's home; existing ignored Windows
case evidence; retained legacy Docker storage below the same Linux user's home

**Testing**: Repository PowerShell assertion scripts in PowerShell 7 and 5.1, Ruff through
`lint-python`, `lint-powershell`, Tricky human/JSON smoke tests, EARS validator, strict MkDocs build,
and explicitly approved benign OCI fixture runs

**Target Platform**: Windows 11 Pro host with WSL 2 and dedicated Debian-MW Debian 13 distribution

**Project Type**: Desired-state PowerShell CLI with pyinfra-managed Linux resources and bounded
static-analysis container tooling

**Performance Goals**: Test and plan commands finish without network access or image operations;
runtime startup remains on-demand; bounded analysis retains the existing 600-second case limit

**Constraints**: No SSH transport, Windows remote client, Podman machine, persistent Podman API
service/socket, Compose provider, Docker compatibility alias, automatic image pull/build/import,
suspicious-file execution, or implicit deletion of legacy data

**Scale/Scope**: One declared Debian-MW distribution and user, one rootless OCI store, one pinned
static-parser image with 21 declared tools, and the existing control/target case model

## Constitution Check

*GATE: Passed before research and re-checked after design.*

- **Human/AI Command Parity — PASS**: `Set-RootlessPodmanState.ps1`, `malware-container-status`,
  `malware-container`, and `wsl-mw podman ...` are direct operator commands. Capability routing is
  updated with the command surface.
- **Evidence Before Capture or Mutation — PASS**: Runtime and image `Test` modes inspect existing
  state first. `Ensure` is explicit; image build remains separate; legacy-data removal is isolated
  in an opt-in destructive module with confirmation.
- **EARS Traceability and Test-First Change — PASS**: All 28 requirements pass the spec gate and map
  to existing test files. Task generation must place failing test edits before implementation edits.
- **Focused Desired State and Dependency Safety — PASS**: `RootlessPodman` owns runtime migration,
  `MalwareContainerImage` depends on it, and `LegacyDockerCleanup` is a separate destructive module.
- **Deterministic Operator Interfaces — PASS**: Default output remains human-readable, `-Json`
  remains explicit, failures are nonzero, and both documented PowerShell runtimes are validated.
- **Platform constraints — PASS**: The design adds no Git Bash, MinGit, MSYS, MSYS2, Cygwin,
  privileged parser runtime, protection bypass, or unreviewed external state.

Post-design review reaches the same result. Contracts preserve the supported high-level interface,
the data model distinguishes historical Docker cases from new Podman cases, and the quickstart
keeps every privileged, networked, or destructive action explicit.

## Project Structure

### Documentation (this feature)

```text
specs/003-migrate-podman-mw/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── checklists/
│   └── requirements.md
├── contracts/
│   ├── container-analysis.md
│   ├── legacy-cleanup.md
│   └── podman-state.md
└── tasks.md
```

### Source Code (repository root)

```text
config/
├── capabilities.psd1
├── malware-container.psd1
├── rootless-podman.psd1
└── workstation-modules.psd1

linux/
├── rootless_podman.py
├── retire_rootless_docker.py
└── malware-analysis/
    ├── Dockerfile
    ├── entrypoint.py
    ├── evidence_ingest.py
    └── tool-inventory.json

profile/
└── Aliases.ps1

scripts/
├── Invoke-MalwareContainerAnalysis.ps1
├── Remove-LegacyDockerMwState.ps1
├── Set-MalwareContainerImageState.ps1
├── Set-RootlessPodmanState.ps1
└── Test-MalwareContainerIsolation.ps1

tests/
├── Test-MalwareAnalysis.ps1
├── Test-MalwareContainerAnalysis.ps1
├── Test-PythonLint.ps1
└── Test-RootlessDockerState.ps1
```

**Structure Decision**: Preserve the repository's existing desired-state layout. Replace the Docker
runtime resource with a focused Podman resource, retain the existing rootless-state regression test
file during the migration so plan-time traceability resolves, and update the existing analysis and
image resources in place. The legacy cleanup is separate because its deletion semantics differ from
runtime convergence.

## Migration Sequence

1. Inspect distribution/user selection, current packages and services, Podman state, Docker state,
   storage roots, and legacy-data presence without invoking an absent runtime or changing state.
2. Bootstrap the already-declared local pyinfra environment only during `Ensure` when required.
3. Install Debian Podman and rootless prerequisites, establish subordinate IDs and local storage,
   and explicitly keep Podman service/socket units disabled.
4. Validate local non-remote rootless operation, non-root ownership, storage location, security
   support, and absence of an active Podman API service.
5. Only after step 4 passes, stop and disable the rootless Docker user service; remove its service
   unit, packages, repository, and key while retaining user Docker storage.
6. Re-run the full state gate. A partial retirement remains drift and is safe to retry.
7. Keep parser image state absent until the operator separately ensures the image; build it from the
   reviewed source in Podman's store and verify its immutable identity and tool fingerprint.
8. Delete legacy Docker data only through the separately selected destructive cleanup module.

## Requirement-to-design translation

| Requirements | Design decision | Verification |
|---|---|---|
| REQ-001, REQ-025 | A focused state object reports selection, both runtime states, services, storage, impact, modes, privilege, and readiness; DSL planning exposes dependency order. | `tests/Test-RootlessDockerState.ps1#Inspection`, `#ModuleContract` |
| REQ-002–REQ-005 | Debian packages provide local rootless Podman; readiness requires non-root local mode and inactive/disabled API units. | `tests/Test-RootlessDockerState.ps1#PodmanState` |
| REQ-006 | Debian-MW readiness rejects remaining Docker command routing and any active Docker/Podman service endpoint. Developer Debian is not touched. | `tests/Test-RootlessDockerState.ps1#Boundary` |
| REQ-007–REQ-012 | Existing plan/run code emits and invokes Podman arguments only after the generic isolation gate validates runtime JSON and exact mounts/flags. | `tests/Test-MalwareContainerAnalysis.ps1#Planning`, `tests/Test-MalwareAnalysis.ps1#RootlessContainer` |
| REQ-013–REQ-015 | Image inspection and explicit local build switch to Podman; the separate store starts absent and is never imported or implicitly repaired. | `tests/Test-MalwareContainerAnalysis.ps1#ImageContract` |
| REQ-016–REQ-018 | High-level commands and JSON remain; generic `wsl-mw podman` is documented; Docker-MW, Podman-MW, and Compose aliases are absent. | `tests/Test-MalwareAnalysis.ps1#Interfaces`, `tests/Test-RootlessDockerState.ps1#CommandSurface` |
| REQ-019–REQ-020 | A two-stage ensure validates Podman before a second retirement deploy; failure before that gate leaves Docker packages/services available. | `tests/Test-RootlessDockerState.ps1#MigrationOrder` |
| REQ-021 | Legacy storage cleanup is a non-default destructive module with resolved-path checks and explicit confirmation. | `tests/Test-RootlessDockerState.ps1#LegacyCleanup` |
| REQ-022–REQ-024 | New manifests record runtime identity; old manifests remain readable; comparisons include runtime identity; bounded Python ingestion remains unchanged. | `tests/Test-MalwareContainerAnalysis.ps1#Differential`, `#EvidenceBoundary` |
| REQ-026–REQ-027 | Capability catalog, module docs, aliases, examples, cross-spec links, dual-runtime tests, Python lint, PowerShell lint, smoke tests, and strict docs change together. | `tests/Test-RootlessDockerState.ps1#Documentation`, publication gates |
| REQ-028 | Container execution remains inert static parsing; Windows Sandbox contracts and detonation commands are unchanged. | `tests/Test-MalwareAnalysis.ps1#SandboxSafety`, `tests/Test-MalwareContainerAnalysis.ps1#Runner` |

## Complexity Tracking

No constitution violations require justification.
