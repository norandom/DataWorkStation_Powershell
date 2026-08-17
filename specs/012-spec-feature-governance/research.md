# Research: Spec Feature Governance

## Brownfield and red-test record

Before production implementation, `tests/Test-SpecFeatureGovernance.ps1 -Section All` failed with
`Focused Spec feature governance core is missing`. No governance production command existed, and
the run did not access workstation state or modify the repository. This is the expected test-first
baseline for the feature.

## Decision: Validate an explicit feature rather than the active feature pointer

`ears-sdd validate` supports `--feature <feature-directory>` together with `--phase final` and
`--json`. The governance command will use those arguments for every referenced feature. It will not
read or update `.specify/feature.json`.

**Rationale**: Publication must be independent of whichever feature a contributor most recently
selected locally.

**Alternatives considered**: Temporarily changing the active pointer was rejected because Test must
be observational. Reimplementing the complete EARS validator was rejected because it would create
two policy engines.

## Decision: Freeze legacy identities explicitly

The existing 46 modules other than `ExploitProtection` and the existing 29 state routes other than
`windows-exploit-protection` will be listed in a reviewed data declaration. Sorted membership is
hashed with SHA-256 and reported.

**Rationale**: Existing resources cannot all receive retroactive dedicated features in this change,
but an automatically derived exception would silently include every future resource.

**Alternatives considered**: Grandfathering by date, catalog order, or name pattern was rejected
because each can expand implicitly. Requiring immediate specs for every historical module was
rejected as unrelated migration scope.

## Decision: Govern both module and state-route catalogs

Non-grandfathered modules and capability routes with `StateCommands` each require `FeatureSpec`.
Governed routes also declare their focused `Modules`, and paired references must match.

**Rationale**: Checking only modules would miss a new state command routed outside the orchestrator;
checking only capability routes would miss an unrouteable module.

**Alternatives considered**: Inferring route/module pairing from command strings was rejected as
fragile. Making every historical route declare modules was rejected as unnecessary migration.

## Decision: Use a private adapter for final validation

Synthetic tests inject final-gate results into `FeatureGovernance.Core.ps1`; the public wrapper binds
the adapter to the installed `ears-sdd` command.

**Rationale**: Tests need deterministic pass, fail, missing-command, and malformed-output cases
without editing real features or depending on the installed validator.

**Alternatives considered**: Temporary real feature directories alone cannot cover process failure
cleanly and make tests slower. A public bypass parameter was rejected because it weakens the
operator contract.

## Decision: Run the guard as its own pre-commit hook

The hook calls the documented public command without filenames and runs whenever catalogs, feature
artifacts, the governance declaration, command, tests, or hook configuration change.

**Rationale**: It keeps the exact prevention mechanism visible and independently runnable.

**Alternatives considered**: Hiding the check inside PowerShell lint was rejected because artifact
governance is not lint and untracked/new non-PowerShell artifacts would be obscured.
