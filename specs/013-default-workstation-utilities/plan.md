# Implementation Plan: Default Workstation Utilities

**Branch**: `main` | **Date**: 2026-08-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/013-default-workstation-utilities/spec.md`

## Summary

Own two focused default workstation modules: mpv provides bounded Radeon D3D11 playback state with
safe decoder fallback, while Safe-Chain provides hash-verified package-manager protection only on
Windows and trusted Debian and enforces every declared wrapper, including pnpm/pnpx. Both retain
observational Test behavior, explicit Ensure behavior,
direct human commands, contract tests, and publication governance.

## Technical Context

**Language/Version**: PowerShell 7 with data-file declarations; WinGet configuration YAML and mpv text configuration

**Primary Dependencies**: WinGet, mpv, native hashing and archive tools, WSL, trusted Debian, managed PowerShell profiles

**Storage**: Versioned declarations plus bounded per-user configuration and shell registration files

**Testing**: Static PowerShell contract harnesses, Pester 6 adapters, workstation baseline and governance gates

**Target Platform**: Windows 11 Pro with optional trusted Debian WSL and Radeon 890M graphics

**Project Type**: Focused workstation desired-state modules

**Performance Goals**: Focused static contract tests complete in under 10 seconds; Test mode performs no network or package mutation

**Constraints**: No elevation; no automatic playback; no overwrite outside the mpv block; no restricted-distribution installation; hash verification before installer execution

**Scale/Scope**: One Windows user, one trusted developer Debian distribution, one mpv GPU profile, and two independent default modules

## Constitution Check

- **Human/AI parity**: PASS. Each resource has a direct human Test/Ensure command before routing.
- **Evidence before mutation**: PASS. Test and plan are observational; Ensure is explicit.
- **EARS/TDD**: PASS. Brownfield characterization selectors map every requirement before release.
- **Focused desired state**: PASS. mpv and Safe-Chain remain separate modules with explicit dependencies.
- **Deterministic interfaces**: PASS. Stable state records and actionable nonzero failures are tested.
- **Publication workflow**: PASS. Documentation, capability routing, lint, Tricky, Pester, and final EARS gates remain required.

Post-design review: PASS. No constitution exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/013-default-workstation-utilities/
├── checklists/requirements.md
├── contracts/state-commands.md
├── data-model.md
├── plan.md
├── quickstart.md
├── research.md
├── spec.md
├── tasks.md
└── traceability.toml
```

### Source Code (repository root)

```text
.config/mpv.winget
config/mpv.conf
config/mpv.psd1
config/safe-chain.psd1
config/workstation-modules.psd1
config/capabilities.psd1
scripts/Set-MpvState.ps1
scripts/Set-SafeChainState.ps1
tests/Test-MpvState.ps1
tests/Test-SafeChainState.ps1
tests/pester/MpvState.Tests.ps1
tests/pester/SafeChainState.Tests.ps1
docs/media-playback.md
```

**Structure Decision**: Keep package/config declarations, state resources, focused contract tests,
and operator documentation separate while sharing only the workstation orchestrator and governance
ownership feature.

## Design Decisions

1. Keep mpv and Safe-Chain as separate default modules even though one release feature owns them.
2. Merge only a marker-bounded mpv GPU block and preserve every unrelated user line.
3. Select `gpu-next`, D3D11 rendering, and `auto-safe` decoding for the declared Radeon profile.
4. Verify Safe-Chain installer and binary hashes independently on Windows and Linux.
5. Target only the current Windows user and the configured trusted Debian distribution.
6. Attach both modules and the Safe-Chain state route to this complete feature directory.
7. Treat every configured Safe-Chain command wrapper as desired state on Windows and Debian rather
   than accepting an initialization file based only on its presence.

## Complexity Tracking

No constitution violations.
