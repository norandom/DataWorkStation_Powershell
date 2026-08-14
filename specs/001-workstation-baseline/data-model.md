# Data Model: Brownfield Workstation Baseline

## WorkstationModule

Represents one focused desired-state boundary.

| Field | Type | Rules |
|---|---|---|
| `Name` | unique string | Matches one orchestrator dispatch case. |
| `Order` | integer | Stable tie-breaker after dependency ordering. |
| `Default` | boolean | Selects normal full-run roots; dependencies may still pull a false root into a plan. |
| `DependsOn` | string list | Every name resolves to another module; graph remains acyclic. |
| `SupportedModes` | enum list | Subset of Test, Ensure, Reinitialize. |
| `Privileged` | boolean | Indicates an explicit elevated execution boundary. |
| `Destructive` | boolean | Indicates opt-in state loss or difficult rollback. |
| `Description` | string | Human-readable purpose. |

### State transitions

```text
unknown/drifted --Test--> reported only
unknown/drifted --Ensure--> compliant or actionable failure
compliant       --Ensure--> compliant without replacement
any state       --Reinitialize--> backup if required, then rebuilt state
```

## ModulePlan

An ordered dependency closure for selected root modules.

| Field | Type | Rules |
|---|---|---|
| `Mode` | enum | Test, Ensure, or Reinitialize. |
| `SelectedRoots` | string list | User selection or default roots. |
| `Modules` | ordered WorkstationModule list | Contains transitive closure exactly once. |
| `HasPrivilege` | boolean | Derived from included modules. |
| `HasDestructiveWork` | boolean | Derived from included modules. |

## CapabilityRoute

Maps a user symptom or goal to inspectable evidence and an explicit capture path.

| Field | Type | Rules |
|---|---|---|
| `Id` | unique kebab-case string | Stable routing identity. |
| `Title` | string | Human-readable capability name. |
| `Triggers` | nonempty string list | Search and discovery terms. |
| `EvidenceKinds` | nonempty enum list | Existing artifacts the route can inspect. |
| `InspectCommands` | nonempty string list | Human-readable, non-capture commands shown first. |
| `CaptureCommand` | string | Explicit operator action; never executed by discovery. |

## EvidenceArtifact

Represents retained diagnostic input such as EVTX, ETL, PCAPNG, dump, profile, or snapshot.

| Field | Type | Rules |
|---|---|---|
| `Path` | local path | Exists before inspection. |
| `Kind` | enum | Determines the compatible inspection command. |
| `CreatedAt` | timestamp | Preserves incident chronology. |
| `Hash` | optional digest | Used where provenance requires it. |
| `Case` | optional identifier | Links evidence to a Tricky case. |

## RequirementTrace

Associates one EARS requirement with evidence.

| Field | Type | Rules |
|---|---|---|
| `RequirementId` | `REQ-NNN` | Unique within the feature. |
| `Verification` | enum | Automated or manual. |
| `Tests` | selector list | Required for automated verification. |
| `Rationale` | string | Required for manual verification and names the bounded procedure. |

## Relationships

- A `ModulePlan` contains many `WorkstationModule` entries.
- A `WorkstationModule` depends on zero or more other `WorkstationModule` entries.
- A `CapabilityRoute` inspects zero or more existing `EvidenceArtifact` instances and exposes one
  explicit capture command.
- A `RequirementTrace` belongs to exactly one EARS requirement and points to its verification
  evidence.
