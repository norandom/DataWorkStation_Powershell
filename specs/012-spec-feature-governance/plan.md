# Implementation Plan: Spec Feature Governance

**Branch**: `main` | **Date**: 2026-08-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/012-spec-feature-governance/spec.md`

## Summary

Add an observational governance command that compares the workstation module and capability
catalogs with an explicit legacy boundary. Every non-grandfathered module and state route must
reference a complete feature directory and pass `ears-sdd validate --feature <path> --phase final`.
The same command is published for operators, invoked by pre-commit, and tested through a private
adapter so failing artifact and validator states never modify the real repository.

## Technical Context

**Language/Version**: Windows PowerShell 5.1-compatible PowerShell; PowerShell 7 validation lane

**Primary Dependencies**: Built-in PowerShell data-file, path, hashing, process, and JSON support;
installed `ears-sdd` validator

**Storage**: Versioned PowerShell data declaration and Spec Kit Markdown/TOML artifacts

**Testing**: Focused synthetic PowerShell harness, Pester 6 adapter, baseline catalog tests,
pre-commit smoke

**Target Platform**: Windows 11 Pro repository checkout; no elevation

**Project Type**: Observational repository-governance CLI

**Performance Goals**: Validate the current 47-module/30-state-route catalog and referenced
features in under 15 seconds after the validator is warm

**Constraints**: No repository writes; no workstation state changes; no active-feature pointer
change; human output first; JSON parity; Windows PowerShell 5.1 and PowerShell 7 compatibility

**Scale/Scope**: One explicit legacy snapshot, any later modules/state routes, and one or more
feature references per repository commit

## Constitution Check

- **Human/AI parity**: PASS. `scripts/Test-SpecFeatureGovernance.ps1` is the primary command; the
  hook and capability route invoke it.
- **Evidence before mutation**: PASS. Validation reads catalogs/artifacts and runs a read-only
  validator; no mutation mode exists.
- **EARS/TDD**: PASS. Fifteen EARS requirements map to focused selectors, with red synthetic tests
  preceding core/public implementation.
- **Focused desired state**: PASS. This is repository governance under the existing
  SpecDrivenDevelopment capability, not a new workstation state module.
- **Deterministic interfaces**: PASS. Human default and `-Json` share one canonical result and
  actionable nonzero failure.
- **Publication workflow**: PASS. The guard is added to pre-commit and all required lint, Tricky,
  docs, Pester, and final EARS gates remain mandatory.

Post-design review: PASS. No constitution exception or complexity waiver is required.

## Project Structure

### Documentation (this feature)

```text
specs/012-spec-feature-governance/
├── checklists/requirements.md
├── contracts/feature-governance-command.md
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
config/
├── capabilities.psd1
├── spec-feature-governance.psd1
└── workstation-modules.psd1

scripts/
├── FeatureGovernance.Core.ps1
└── Test-SpecFeatureGovernance.ps1

tests/
├── Test-SpecFeatureGovernance.ps1
├── Test-PowerShellTestingState.ps1
└── pester/SpecFeatureGovernance.Tests.ps1

docs/
├── capabilities/index.md
├── sample-outputs.md
└── spec-driven-development.md

.pre-commit-config.yaml
```

**Structure Decision**: Keep the deterministic evaluation in a private dot-sourced core with an
injected final-gate adapter. The public command owns only production catalog loading, external
validator invocation, rendering, and exit behavior. The config file owns the reviewed legacy
boundary; catalog entries own their feature references.

## Design Decisions

1. Add `FeatureSpec = 'specs/<feature>'` to every non-grandfathered module and state route.
2. Add `Modules = @('<module>')` to a governed state route so paired references can be compared.
3. Grandfather exactly the pre-governance identities in `config/spec-feature-governance.psd1`.
4. Canonicalize the sorted legacy names into a SHA-256 fingerprint and require the declaration's
   pinned fingerprint to match; any boundary change is therefore explicit in review and output.
5. Validate only referenced features. Unreferenced drafts are not publication dependencies.
6. Require normalized paths beneath `specs/`, four regular artifacts, and a successful explicit
   `ears-sdd --feature` final gate.
7. Run the public command from a local pre-commit hook with `pass_filenames: false`.

## Complexity Tracking

No constitution violations.
