# Quickstart: AI Tools and WSL Isolation

Implementation validation is observational; do not run an Ensure command until its plan has been
reviewed.

## 1. Validate the feature artifacts

```powershell
ears-sdd validate --feature specs/010-ai-tools-isolation --phase spec
ears-sdd validate --feature specs/010-ai-tools-isolation --phase plan
ears-sdd validate --feature specs/010-ai-tools-isolation --phase tasks
```

## 2. Inspect the requested state

```powershell
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan -Product OpenCode
pwsh -NoProfile -File .\scripts\Set-DeveloperEditorState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-AiNixOsWslState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1
pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1 -Json | ConvertFrom-Json
```

## 3. Run focused tests

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AiToolsIsolation.ps1 -Section All
pwsh -NoProfile -File .\tests\Test-AiToolsIsolation.ps1 -Section All
```

## 4. Review explicit mutation plans

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module DeveloperEditor
.\Apply-Workstation.ps1 -Mode Test -Module AiTools,AiNixOsWsl
pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan -Json | ConvertFrom-Json
```

The eventual Ensure run executes network-delivered vendor code and may create/restart selected WSL
distributions. It is intentionally not part of automated validation.

## 5. Publication gates

```powershell
lint-powershell
tricky list
tricky list -Json | ConvertFrom-Json
uv run --locked --group docs mkdocs build --strict --site-dir site
ears-sdd validate --feature specs/010-ai-tools-isolation --phase final
```

## Verification record

Validated on 2026-08-17:

- `ears-sdd validate --feature specs/010-ai-tools-isolation --phase final`: PASS; 1 feature,
  37 requirements, 0 errors, 0 warnings.
- Focused contracts: PASS under PowerShell 7 and Windows PowerShell 5.1; 150 assertions in each
  runtime.
- Pester: PASS under PowerShell 7 and Windows PowerShell 5.1; 224/224 tests in each runtime. The
  AI adapter contributed 38/38 passing cases in each lane.
- `lint-powershell`: PASS for 187 files.
- Tricky human and JSON smokes: PASS; JSON exposed 31 capability routes.
- `uv run --locked --group docs mkdocs build --strict --site-dir site`: PASS.
- `git diff --check`, PowerShell parser checks, catalog baselines, update contracts, and Spec Kit
  artifact gates: PASS.
- Nix evaluation was unavailable because no WSL distribution was running. Validation deliberately
  did not start one; locked sources, hashes, launcher/profile contracts, and Nix boundary text were
  validated statically.

Initial implementation validation ran no Ensure or Reinitialize command, vendor installer, WSL
installation, WSL start/termination/restart, OpenCode launch, nono execution, or malware case
transfer. A later explicitly requested `DeveloperEditor` repair exposed two false-positive checks:
the generated Berg directory was obsolete and therefore absent from VS Code inventory, and the
per-user Berkeley Mono family was missed by a registry-name-only probe. Phase 9 adds executable
regressions and requires the discovered `teehausamberg.berg@0.0.4` contribution plus embedded
per-user font metadata. No WSL, AI-agent, or malware-case state was changed during that correction.
After the dual-runtime focused regressions passed, the explicitly requested `DeveloperEditor`
Ensure revalidated stable VS Code, accepted the already installed exact Berg contribution, backed
up the settings file, and changed only the three managed settings to `Berg Theme` and
`Berkeley Mono`. The final observational editor test reported every check compliant.
