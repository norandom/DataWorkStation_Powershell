# Research: Brownfield Workstation Baseline

## Decision 1: Model the current repository as one baseline feature

**Decision**: Freeze the current module and capability inventories in one brownfield feature, then
use new feature directories for subsequent behavior changes.

**Rationale**: A single baseline gives every existing public surface a traceable home without
rewriting history or creating 44 disconnected migration features.

**Alternatives considered**:

- One feature per module: rejected because cross-module dependency and safety contracts would be
  duplicated and the migration could not be reviewed as one coherent baseline.
- Specifications only for future work: rejected because current behavior would remain outside the
  EARS and TDD governance boundary.

## Decision 2: Use hybrid automated and manual characterization

**Decision**: Automate static contracts and safe read-only commands; retain concrete manual
verification for privileged, destructive, hardware-dependent, reboot-dependent, and evidence
capture behavior.

**Rationale**: Claiming ordinary workstation integration tests for those behaviors would either be
false or would silently mutate the developer host. The constitution explicitly forbids that.

**Alternatives considered**:

- Mark every mapping automated: rejected because a selector alone is not execution evidence.
- Mark every mapping manual forever: rejected because catalog, documentation, routing, and task
  ordering are deterministic and safely automatable.
- Detonate all tests in Windows Sandbox immediately: deferred because Sandbox lacks persistent host
  state, licensed applications, GPU equivalence, and some Hyper-V/WSL nesting needed by the baseline.

## Decision 3: Add a plain PowerShell characterization harness

**Decision**: Use `tests/Test-WorkstationBaseline.ps1` with built-in assertions and no Pester
dependency for the initial static baseline.

**Rationale**: The repository supports PowerShell 7 and selected Windows PowerShell 5.1 workflows.
A dependency-free test entry point is readable, portable, and can be invoked directly by humans and
CI.

**Alternatives considered**:

- Pester: suitable later, but not currently pinned or installed by repository state.
- Python-only tests: rejected for the PowerShell data-file and shell-contract baseline because it
  would introduce a second parser for native PowerShell structures.

## Decision 4: Preserve current directory boundaries

**Decision**: Keep commands in `scripts/`, declarations in `config/`, profile components in
`profile/`, Linux-local state in `linux/`, and focused skills in `.agents/skills/`.

**Rationale**: The existing layout expresses privilege and execution boundaries clearly. Moving
files solely to resemble a generic Spec Kit template would add risk without user value.

**Alternatives considered**:

- Move production code into `src/`: rejected because it would break documented commands and
  obscure the distinction between desired state, diagnostics, and profile code.

## Decision 5: Treat release-pinned Spec Kit consumption as supply-chain state

**Decision**: Continue installing the published EARS/TDD wheel with a verified hash and its
published `specify-cli` dependency rather than consuming mutable Git state.

**Rationale**: Projects receive reproducible tooling while the standalone bundle can inherit
upstream Spec Kit through explicit release updates.

**Alternatives considered**:

- Git submodule: rejected for normal project consumption because it couples every checkout to
  source history and update mechanics.
- Copying templates by hand: rejected because upstream composition and release provenance would be
  lost.

## Resolved Unknowns

All planning questions are resolved. The supported host, shell boundaries, inventory size,
verification tiers, release dependencies, and publication gates are evidenced by the current
repository.
