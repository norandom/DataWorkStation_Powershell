# Spec-driven development

The `SpecDrivenDevelopment` module installs
[`spec-kit-ears-tdd`](https://github.com/norandom/spec-kit-ears-tdd) `v0.1.0` from its immutable
GitHub release wheel. The resource verifies SHA-256 before installing the tool in an isolated `uv
tool` environment. The wheel pins the published `specify-cli==0.16.3` release; neither dependency
is installed from a Git branch or checkout.

No elevation or UAC is required.

The state resource and generated `ears-sdd.ps1` launcher are compatible with both PowerShell 7
and inbox Windows PowerShell 5.1. Spec Kit's selected project-script variant is Python, independent
of the calling PowerShell runtime; the generated project also carries PowerShell helper scripts.

## Test and install the tool

Use the focused human command first:

```powershell
pwsh -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Ensure
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test
```

The module form includes the managed `uv` package dependency automatically:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module SpecDrivenDevelopment -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module SpecDrivenDevelopment
```

Use `-SkipSpecDrivenDevelopment` only with the legacy full run. Do not combine skip switches with
explicit `-Module` selection.

## Adopt the policy in a project

Tool installation and project adoption are separate on purpose. Adoption writes Spec Kit commands,
templates, workflow metadata, launchers, and a project-local policy file, so run it explicitly from
the target project and review the resulting diff:

```powershell
ears-sdd init --project . --integration codex
git diff -- .agents .specify ears-sdd ears-sdd.ps1
```

The source remains in its standalone repository. A consuming project receives only the installed
Spec Kit artifacts and project-specific configuration.

Edit `.specify/ears-sdd.toml` for the project's production roots, test roots, and real test command.
Then use the human validator:

```powershell
.\ears-sdd.ps1 validate --phase spec
.\ears-sdd.ps1 validate --phase plan
.\ears-sdd.ps1 validate --phase tasks
.\ears-sdd.ps1 validate --phase final
.\ears-sdd.ps1 status --phase final
```

The same launcher works from inbox Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ears-sdd.ps1 status --phase final
```

For agent consumption, add `--json`. The installed Codex command is
`$speckit-ears-validate-validate`, and the gated workflow is `ears-sdd`.

## Boundary enforced

- Specifications use stable `REQ-NNN` identifiers and one EARS `shall` obligation per requirement.
- Every requirement maps to automated tests or a justified manual verification.
- Tests may name requirement IDs; production code may not contain IDs or copied requirement prose.
- Validation is read-only and does not silently execute the project's configured test command.

The final gate verifies that a real test command is declared. Run that command separately so test
execution remains visible and attributable.
