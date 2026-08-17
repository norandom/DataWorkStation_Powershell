# Contract: Spec Feature Governance Command

## Human command

```powershell
pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1
pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1 -Json
```

The command takes no mutation mode and needs no elevation. Human output is the default. `-Json`
changes rendering only.

## Exit contract

- Exit `0`: catalogs, legacy boundary, references, required artifacts, pairing, and all referenced
  final EARS gates are compliant.
- Nonzero: one or more failures were rendered, the validator command was unavailable, or a final
  gate could not be attributed.

## Structured result

Schema version 1 exposes:

- `SchemaVersion`
- `Outcome`, `Compliant`
- `ModuleCount`, `StateRouteCount`
- `GovernedModules`, `GovernedStateRoutes`
- `ReferencedFeatures`
- `LegacyFingerprint`
- `Failures`

Each failure contains `Code`, `Kind`, `Identity`, `FeatureSpec`, and `Message`.

## Safety contract

The command must not:

- write or normalize repository files;
- change `.specify/feature.json` or any environment-selected feature;
- install or update Spec Kit;
- change workstation desired state;
- stage, commit, reset, or otherwise mutate Git state;
- validate unreferenced draft features.

## Declaration contract

Non-grandfathered catalog entries use:

```powershell
FeatureSpec = 'specs/NNN-feature-name'
```

A governed state route additionally declares its focused public modules:

```powershell
Modules = @('FocusedModule')
```
