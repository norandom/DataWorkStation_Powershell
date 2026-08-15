# Research: PowerShell Test Framework

## Decision 1: Pin Pester 6.1.0

**Decision**: Use the current stable Pester 6.1.0 release and import it by exact version.

**Rationale**: Pester is the standard PowerShell test framework. Version 6 adds opt-in file-level
parallel execution while retaining ordinary discovery, aggregate results, filters, and test-result
reporting. The workstation currently exposes only Pester 3.4.0, which is too old for this design.

**Alternatives considered**: Keep custom assertion scripts only; use Pester 5 plus a separate job
runner; use an unpinned latest release. These lose framework-native parallel aggregation or
determinism.

Sources: [Pester parallel execution](https://pester.dev/docs/usage/parallel),
[Pester v5 to v6 migration](https://pester.dev/docs/migrations/v5-to-v6),
[Invoke-Pester](https://pester.dev/docs/commands/Invoke-Pester)

## Decision 2: Parallelize files, not individual assertions

**Decision**: Enable `Run.Parallel` only under PowerShell 7.4+, cap it at four files by default,
and use Pester's `#pester:no-parallel` directive for exclusive files.

**Rationale**: Pester 6 parallelizes self-contained files in separate runspaces and merges their
results. File boundaries match this repository's existing focused suites. A finite limit keeps WSL,
process, and memory pressure understandable.

**Alternatives considered**: Unlimited processor-count concurrency; assertion-level jobs; running
all files in parallel regardless of side effects. These make workstation interactions harder to
reason about.

## Decision 3: Use the same release sequentially for Windows PowerShell

**Decision**: Store Pester in the per-user `Documents\WindowsPowerShell\Modules` tree, which is
visible to both supported runtimes, and invoke the compatibility lane through `powershell.exe` with
parallelism disabled.

**Rationale**: Pester documents sequential fallback for Windows PowerShell 5.1. One module tree and
one set of test adapters avoids silently validating different framework versions.

**Alternatives considered**: Separate Pester installations per runtime; dropping 5.1; treating a
PowerShell 7 parse check as compatibility. Separate versions drift and parse-only checks miss
behavior.

## Decision 4: Migrate through adapters first

**Decision**: Add `*.Tests.ps1` adapters that invoke the current section-level scripts as child
processes and assert their exit/output contract.

**Rationale**: The existing scripts contain hundreds of useful assertions and stable traceability
selectors. Adapters provide immediate framework discovery and safe file-level concurrency without
a risky wholesale assertion rewrite during the Podman migration.

**Alternatives considered**: Rewrite all assertions immediately; merely run arbitrary scripts in
parallel without Pester. The first obscures behavior changes, while the second lacks standard
discovery and aggregate framework results.

## Decision 5: Keep installation outside test execution

**Decision**: `Set-PesterState.ps1` uses exact-version PSResourceGet retrieval during explicit
Ensure; the runner only imports the declared version and fails with the repair command when absent.

**Rationale**: Network and module writes are desired-state changes, not test behavior. This follows
the repository's explicit mutation contract.

**Alternatives considered**: Bootstrap on first test; rely on the inbox module; install a global
machine module. These hide mutation, retain an obsolete framework, or require needless elevation.
