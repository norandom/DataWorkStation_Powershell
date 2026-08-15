# Data Model: Migrate Debian-MW to Podman

## Runtime State

Represents one observation of the declared Debian-MW container boundary.

Fields:

- schema version and terminal status;
- selected distribution, WSL version, selected user, UID, home, subordinate UID/GID readiness;
- Podman package/version, executable, local/remote state, rootless state, security support;
- Podman storage driver, graph root, run root, ownership, API service/socket state;
- Docker package, executable, rootless user service, rootful service, repository, and integration
  state;
- retained legacy storage paths and their presence;
- named checks, migration phase, required privilege, and pending changes.

Validation rules:

- the distribution must equal the dedicated configured malware distribution and must differ from
  the developer distribution;
- the user must be non-root and match the configured malware user;
- compliant state requires local rootless Podman, user-owned storage, supported namespace and
  isolation facilities, and inactive/disabled API services;
- compliant state requires Docker commands, packages, services, repository routing, and Desktop
  integration to be absent from Debian-MW;
- missing Podman state and retained Docker state are drift, not a reason to delete Docker first.

State transitions:

```text
DockerOnly ──provision──> PodmanProvisioned ──validate──> PodmanReady
    ^                           │                            │
    └──── failure before gate ──┘                            └──retire Docker──> Compliant
                                                              │
                                                              └──partial failure──> RetirementDrift
```

`RetirementDrift` blocks analysis until a retry reaches `Compliant`. It does not delete legacy
storage.

## Migration Plan

Represents the read-only explanation produced before convergence.

Fields:

- before-state fingerprint;
- ordered stages and per-stage conditions;
- package additions and removals;
- service/socket changes;
- repository/key changes;
- retained and excluded paths;
- privilege and network requirements;
- rollback boundary and expected after-state.

The plan is not executable evidence and contains no unbounded command output.

## OCI Analysis Image Baseline

Represents the Podman-local image approved for static parsing.

Fields:

- declared repository/tag and base-image digest;
- immutable Podman image ID and creation time;
- build-input and tool-inventory fingerprints;
- complete expected and observed tool identities;
- selected distribution/user/runtime and readiness state.

State transitions:

```text
Absent ──explicit build──> Building ──inventory pass──> Ready
                                  └──failure──────────> Drift
Ready ──source/inventory change──────────────────────> Drift
```

Inspection never changes these states. Analysis accepts only `Ready`.

## Analysis Case

Extends the existing static case without rewriting historical evidence.

New fields for Podman cases:

- runtime name and version;
- local/rootless runtime identity;
- OCI image ID and tool-inventory fingerprint;
- isolation-policy fingerprint.

Historical Docker cases may lack the new runtime fields. They remain reportable, but comparison
with a Podman case is incompatible rather than equivalent.

## Legacy Docker State

Represents data intentionally retained after runtime retirement.

Fields:

- exact resolved storage/config paths;
- existence, owner, size, and last modification summary;
- Docker service/package absence;
- cleanup selection, destructive confirmation, and terminal status.

State transitions:

```text
Retained ──plan──> Retained ──explicit destructive Ensure──> Removed
```

Cleanup refuses unresolved, non-user-owned, symlinked, root, home, distribution-root, or otherwise
broad targets.
