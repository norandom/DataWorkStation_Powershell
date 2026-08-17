# Quickstart: Validate Spec Feature Governance

All commands are observational.

## 1. Validate design artifacts

```powershell
ears-sdd validate --feature specs/012-spec-feature-governance --phase spec
ears-sdd validate --feature specs/012-spec-feature-governance --phase plan
ears-sdd validate --feature specs/012-spec-feature-governance --phase tasks
```

## 2. Run the human guard

```powershell
pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1
```

Expected: compliant outcome, catalog counts, governed module/route identities, referenced feature
paths, their final-gate status, and the matching legacy fingerprint.

## 3. Run the structured guard

```powershell
pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1 -Json | ConvertFrom-Json
```

Expected: schema version 1 with the same checks and outcome as the human report.

## 4. Run focused tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-SpecFeatureGovernance.ps1 -Section All
pwsh -NoProfile -File .\tests\Test-SpecFeatureGovernance.ps1 -Section All
```

## 5. Run publication gates

```powershell
pre-commit run spec-feature-governance --all-files
lint-powershell
tricky list
tricky list -Json | ConvertFrom-Json
uv run --locked --group docs mkdocs build --strict --site-dir site
ears-sdd validate --feature specs/012-spec-feature-governance --phase final
```

## Verification record

Recorded 2026-08-17:

- Final EARS gate: PASS; 1 feature, 15 requirements, 0 errors, 0 warnings.
- Focused suite: PASS under Windows PowerShell 5.1 and PowerShell 7; 15 selectors and 32
  assertions in each runtime.
- Pester adapter: PASS under Core and Desktop compatibility lanes; 15 tests in each runtime.
- Public human and JSON commands: PASS; 47 modules, 30 state routes, one governed module/route
  pair, matching legacy fingerprint, and feature 011 final gate PASS.
- Baseline Capabilities and Governance plus the Pester adapter registry: PASS.
- Full PowerShell lint: PASS for 182 tracked files; focused lint: PASS for 7 changed/new files.
- Tricky human and JSON smokes, strict MkDocs build, focused pre-commit hook, and
  `git diff --check`: PASS.
- No workstation state, repository file, active feature pointer, or unrelated feature draft was
  changed by the governance command or its tests.
