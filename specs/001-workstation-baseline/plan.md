# Implementation Plan: Brownfield Workstation Baseline

**Branch**: `main` (migration artifacts under `001-workstation-baseline`) | **Date**: 2026-08-14 | **Spec**: [spec.md](spec.md)

**Input**: Brownfield feature specification from `specs/001-workstation-baseline/spec.md`

## Summary

Characterize the existing Windows workstation repository as a stable Spec Kit baseline. Preserve
the existing focused desired-state and evidence-first architecture, freeze the current 40-module
and 25-capability inventories, and introduce deterministic EARS/TDD traceability. Static catalog,
documentation, and workflow contracts will receive repository-local automated characterization;
host-dependent, privileged, destructive, graphics, reboot, and evidence-order behavior retains
explicit manual verification until an isolated Windows test harness is available.

## Technical Context

**Language/Version**: Inbox Windows PowerShell 5.1 for bootstrap and Windows-only components;
the newest installed PowerShell 7 for post-Core orchestration and compatible resources; Python
3.12 for Spec Kit helpers and the EARS validator

**Primary Dependencies**: WinGet Configuration, Windows sudo, uv, `specify-cli==0.16.3`,
`spec-kit-ears-tdd==0.1.0`, PSScriptAnalyzer 1.25.0, MkDocs Material, and Debian WSL for Linux-local
automation

**Storage**: Versioned PowerShell data files, WinGet YAML, Markdown, TOML, HJSON, and generated
diagnostic evidence outside the source tree

**Testing**: PSScriptAnalyzer; Pester 6 parallel and Windows PowerShell compatibility lanes;
deterministic EARS/TDD gates; repository-local PowerShell characterization tests; Tricky human/JSON
smoke tests; strict MkDocs build; bounded manual host verification for privileged or
hardware-dependent state

**Target Platform**: Windows 11 Pro, with PowerShell 7 and inbox Windows PowerShell 5.1 where
declared; Debian under WSL 2 for Linux-local resources

**Project Type**: Desired-state and diagnostic command-line workstation project

**Performance Goals**: Static baseline validation completes within 30 seconds on a normal
developer checkout; module planning and capability discovery remain interactive

**Constraints**: No silent elevation, capture, destructive action, protection change, policy
reinitialization, or reboot; no machine-local secrets or licenses in version control; no
requirement prose or identifiers in production roots

**Scale/Scope**: 40 desired-state modules, 25 routed capabilities, 51 baseline requirements,
separate focused skills, and one Windows workstation per operator

## Constitution Check

*GATE: Passed before Phase 0 and rechecked after Phase 1.*

| Principle | Design response | Gate |
|---|---|---|
| I. Human/AI Command Parity | `quickstart.md` and contracts lead with directly runnable commands; skills remain orchestration only. | PASS |
| II. Evidence Before Capture or Mutation | Existing evidence inspection, plan/test modes, privilege, and destructive boundaries are explicit requirements. | PASS |
| III. EARS Traceability and Test-First Change | Every normative obligation has one EARS ID and trace entry; tasks place characterization or failing tests before remediation. | PASS |
| IV. Focused Desired State and Dependency Safety | The existing module catalog and topological planner remain the architecture under test. | PASS |
| V. Deterministic Operator Interfaces | Human output remains default, JSON is explicit, and dual-shell contracts are documented. | PASS |
| Platform and Safety Constraints | Windows 11 Pro, local-file exclusions, separate attack-surface documentation, and SkillOpt restrictions are in scope. | PASS |
| Publication Workflow | Lint, Tricky human/JSON smoke, EARS validation, and strict docs are explicit gates. | PASS |

No constitution exception or complexity waiver is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-workstation-baseline/
├── checklists/requirements.md
├── contracts/
│   ├── capability-routing.md
│   ├── workstation-cli.md
│   └── windows-terminal.md
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
Apply-Workstation.ps1              # module selection, planning, and dispatch
config/
├── workstation-modules.psd1       # desired-state dependency catalog
├── windows-terminal.psd1          # default profile and shared appearance
├── capabilities.psd1              # diagnostic and discovery routing catalog
└── *.psd1                          # focused resource declarations
scripts/
├── Set-*State.ps1                 # focused desired-state resources
├── Set-WindowsTerminalState.ps1   # merge-preserving Terminal state
├── Get-*.ps1                      # evidence inspection
├── Invoke-*.ps1                   # explicit capture, profiling, and tooling
└── Test-RepositorySkills.ps1      # skill package validation
profile/
├── Shell.ps1
├── Config.ps1
├── Tools.ps1
└── Aliases.ps1
linux/
└── developer_tools.py             # Debian-local pyinfra state
tests/
├── Test-WorkstationBaseline.ps1   # dependency-free characterization harness
└── pester/WorkstationBaseline.Tests.ps1 # standard suite adapter
docs/                              # operator documentation and samples
.agents/skills/                    # focused human-command orchestration
.specify/                          # Spec Kit policy, templates, and integrations
```

**Structure Decision**: Retain the current command-oriented repository structure. Add only a
`tests/` characterization boundary and feature-local Spec Kit artifacts; do not move existing
production commands merely to resemble an application template.

## Verification Strategy

### Tier A: Automated static characterization

`tests/Test-WorkstationBaseline.ps1` will verify catalog schemas, unique identifiers, dependency
resolution, focused selection, risk flags, complete module/capability baseline membership, safe
sample/local-file pairs, skill separation, absence of managed UAC controls, documented Windows 11
Pro support, and TDD task ordering. It will run without elevation or workstation mutation.

### Tier B: Automated command smoke tests

Existing human commands will cover planning, capability discovery, Tricky human/JSON parsing,
repository-skill validation, EARS gates, PowerShell lint, and strict documentation. Dual-shell
smoke checks will cover commands explicitly documented for both runtimes. A child Windows
PowerShell process whose PATH excludes PowerShell 7 proves bootstrap planning does not resolve Core
early. Synthetic Terminal settings prove merge preservation without touching user state.

### Tier C: Bounded manual or isolated-host verification

Privilege, destructive removal, reboot-pending Windows features, Contour graphics initialization,
package repair, firewall replacement, evidence acquisition, debugger attachment, and WSL-local
package state remain manual. Each mapping states a concrete procedure because executing them in a
normal source validation run would violate safety boundaries. A future Windows Sandbox or disposable
VM harness can replace these entries without changing requirement intent.

## Requirement-to-design Translation

| Requirement | Design location | Verification tier |
|---|---|---|
| REQ-001 | Module catalog plus frozen module table | A |
| REQ-002 | `config/workstation-modules.psd1` schema | A |
| REQ-003 | topological planner in `Apply-Workstation.ps1` | A and B |
| REQ-004 | focused selection in `Apply-Workstation.ps1` | A and B |
| REQ-005 | `-Plan` dispatch boundary | A and B |
| REQ-006 | focused resource `Test` modes | B and C |
| REQ-007 | focused resource idempotence | C |
| REQ-008 | resource-specific backup/recovery behavior | C |
| REQ-009 | Sudo dependency edges | A and B |
| REQ-010 | destructive confirmation guards | A and C |
| REQ-011 | default selection and Debloat flag | A and B |
| REQ-012 | dual-shell launch contracts | B |
| REQ-013 | README and getting-started prerequisite | A |
| REQ-014 | Windows feature dependency graph | A and B |
| REQ-015 | Windows feature restart boundary | A and C |
| REQ-016 | separate security modules and commands | A and B |
| REQ-017 | hardening catalog exclusion for UAC | A |
| REQ-018 | protected debloat inventory | A and C |
| REQ-019 | debloat snapshot sequencing | A and C |
| REQ-020 | Contour Scoop-to-MSI transition | A and C |
| REQ-021 | bounded Contour graphics gate | B and C |
| REQ-022 | native text-tool declaration and exclusions | A and B |
| REQ-023 | Debian WSL selection and Linux-local state | B and C |
| REQ-024 | isolated developer-tool environments | A and C |
| REQ-025 | managed profile and discovery surface | A and B |
| REQ-026 | capability catalog plus frozen route table | A and B |
| REQ-027 | capability route schema | A |
| REQ-028 | focused diagnostic skill instructions | A and C |
| REQ-029 | explicit diagnostic capture commands | A and C |
| REQ-030 | Tricky default formatting | B |
| REQ-031 | Tricky JSON parsing | B |
| REQ-032 | repository skill directory boundaries | A and B |
| REQ-033 | profiler routing and status | A, B, and C |
| REQ-034 | public samples and ignored local selections | A |
| REQ-035 | MkDocs operator content | A and B |
| REQ-036 | capability/documentation change coupling | A and review |
| REQ-037 | publication gate command set | B |
| REQ-038 | released Spec Kit EARS/TDD desired state | B and C |
| REQ-039 | deterministic traceability validation | B |
| REQ-040 | task-order validation | A and B |
| REQ-042 | focused Go package, environment, and built-in toolchain state | B and C |
| REQ-043 | pinned malware_hashes release state and narrow command directory | B and C |
| REQ-041 | SkillOpt safe configuration and mock workflow | A and B |
| REQ-044 | declared dependency stages and runtime boundary per module | A and B |
| REQ-045 | stage-aware plan validation and ordering | A and B |
| REQ-046 | inbox-only bootstrap with PowerShell 7 absent from PATH | B |
| REQ-047 | lazy PowerShell 7 resolution after the Core prerequisite succeeds | A and B |
| REQ-048 | equivalent managed profile smoke in both shells | B |
| REQ-049 | merge-preserving Windows Terminal default-profile state | A and B |
| REQ-050 | shared PowerShell appearance with unrelated settings retained | A and B |
| REQ-051 | observational Windows Terminal Test mode | A and B |

## Complexity Tracking

No constitution violations or additional architectural layers are introduced.

## Post-Design Constitution Recheck

Phase 1 retains human commands as the public boundary, uses test-first characterization tasks,
keeps machine-dependent operations manual and explicit, and adds no omnibus skill or silent state
path. All constitution gates remain PASS.
