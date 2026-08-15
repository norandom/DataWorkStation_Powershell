# Implementation Plan: PowerShell Test Framework

**Branch**: `main` | **Date**: 2026-08-15 | **Spec**: [spec.md](spec.md)

## Summary

Adopt pinned Pester 6.1.0 as a focused per-user desired-state module, provide one
`test-powershell` command, and place the active Podman/malware section runners behind standard
`*.Tests.ps1` adapters. PowerShell 7.4+ uses Pester's bounded experimental file-level parallel
mode; Windows PowerShell 5.1 uses the same Pester release and adapters sequentially. Test execution
never installs its own prerequisite.

## Technical Context

**Language/Version**: PowerShell 7.6 and Windows PowerShell 5.1

**Primary Dependencies**: Pester 6.1.0; Microsoft.PowerShell.PSResourceGet 1.2.0 for explicit installation

**Storage**: Per-user module path under `Documents\WindowsPowerShell\Modules`; no test database

**Testing**: Pester file discovery plus existing section-level contract runners

**Target Platform**: Windows 11 Pro

**Project Type**: Workstation desired-state and command-line tooling

**Performance Goals**: At least two eligible files overlap in the modern lane; concurrency is capped at four by default

**Constraints**: Human output default; bounded JSON on request; no installation during tests; no parallel live-state mutation; retain PowerShell 5.1 compatibility

**Scale/Scope**: Three active Podman/malware suites initially, with a reusable runner for later gradual migration

## Constitution Check

*GATE: Passed before and after design.*

- Human/AI parity: `test-powershell` calls `scripts/Invoke-PowerShellTests.ps1`; no agent-only runner.
- Evidence/mutation: test execution is observational; framework Ensure is separate and explicit.
- EARS/TDD: every requirement maps to a named test selector and implementation begins with failing contracts.
- Focused state: `PowerShellTesting` is an independent module depending on `PowerShell7`.
- Deterministic interfaces: human default, `-Json` for machines, and nonzero failure behavior.
- Publication gates remain unchanged and consume the same human commands.

## Project Structure

### Documentation (this feature)

```text
specs/004-powershell-testing/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── contracts/
│   ├── test-command.md
│   └── framework-state.md
└── tasks.md
```

### Source Code (repository root)

```text
config/
├── pester.psd1
├── workstation-modules.psd1
└── capabilities.psd1
profile/Aliases.ps1
scripts/
├── Set-PesterState.ps1
└── Invoke-PowerShellTests.ps1
tests/
├── Test-PowerShellTestingState.ps1
└── pester/
    ├── RootlessPodman.Tests.ps1
    ├── MalwareAnalysis.Tests.ps1
    └── MalwareContainerAnalysis.Tests.ps1
```

**Structure Decision**: Preserve the existing section runners as traceable compatibility fixtures
and introduce thin standard Pester adapters. Later features can move assertions into native Pester
incrementally without changing the public runner.

## Verification Strategy

1. Source-contract tests fail before the config, state, runner, aliases, and adapters exist.
2. Synthetic Pester fixtures prove discovery, failure exit behavior, JSON summaries, concurrency,
   exclusive-file handling, and sequential fallback without touching workstation state.
3. The migrated adapters run the active suites under PowerShell 7 and Windows PowerShell 5.1.
4. Module Test remains observational; Ensure is run separately only after repository gates.

## Complexity Tracking

No constitution violations.
