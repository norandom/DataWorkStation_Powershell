# Data Model: Spec Feature Governance

## GovernedModule

- `Name`: unique module identity from `config/workstation-modules.psd1`.
- `FeatureSpec`: optional repository-relative feature directory.
- `Grandfathered`: derived membership in the reviewed legacy module list.
- Valid when grandfathered, or when `FeatureSpec` resolves to a valid DedicatedFeature.

## GovernedStateRoute

- `Id`: unique capability identity from `config/capabilities.psd1`.
- `StateCommands`: one or more explicit mutation commands.
- `Modules`: focused module identities owned by a governed route.
- `FeatureSpec`: optional repository-relative feature directory.
- `Grandfathered`: derived membership in the reviewed legacy state-route list.
- Valid when grandfathered, or when its feature is valid and paired module references agree.

## DedicatedFeature

- `RelativePath`: normalized `specs/<feature>` child path.
- `RequiredArtifacts`: `spec.md`, `plan.md`, `tasks.md`, `traceability.toml`.
- `FinalGate`: passed/failed result from explicit-feature EARS validation.
- Multiple governed declarations may reference the same instance.

## LegacyBoundary

- `CapturedUtc`: provenance of the reviewed exception set.
- `Modules`: unique, explicit historical module names.
- `StateCapabilities`: unique, explicit historical state-route IDs.
- `ExpectedSha256`: pinned digest of the canonical sorted membership representation.
- `ActualSha256`: recomputed digest reported on every run.
- Valid only when identities are unique, exist in their catalogs, and the digests match.

## GovernanceResult

- `SchemaVersion`: stable output contract version.
- `Outcome`: `compliant` or `failed`.
- `ModuleCount`, `StateRouteCount`: checked catalog populations.
- `GovernedModules`, `GovernedStateRoutes`: non-grandfathered identities.
- `ReferencedFeatures`: distinct normalized feature paths and final-gate state.
- `LegacyFingerprint`: expected and actual SHA-256 plus validity.
- `Failures`: actionable code, declaration kind/identity, feature, and message.
- `Compliant`: derived from zero failures.

## State Transitions

The command has no mutation lifecycle. One evaluation moves from declarations to a canonical result:

`load → validate legacy boundary → resolve nonlegacy references → validate artifacts → run final gates → render`.

Any failure is retained in the result; the public command exits nonzero after rendering it.
