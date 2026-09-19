---
name: diagnose-memory
description: Diagnose Windows memory pressure, rising commit, process private bytes, working sets, WSL or Docker memory, file cache, and paged/nonpaged kernel pools. Use when RAM fills, allocation fails, or the user needs evidence for what can safely be terminated.
---

# Diagnose Memory

Separate ownership classes before recommending termination.

## Workflow

1. Read `../../../docs/workflows/memory-pressure.md`.
2. Inspect `mem`, `memapps`, and `memproc`; use `wslmem` when WSL or Docker is relevant.
   For any application disappearance or suspected OOM, inspect existing guard evidence first:
   `pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Status -Json`
   and `pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Events -Last 100 -SinceUtc <ISO-UTC> -Json`.
   Read `../../../docs/workload-memory.md#early-oom-recovery-and-audit-logs` for the policy and event meanings.
   Correlate UTC, PID plus creation time, memory readings, mode and outcome with the failing test run.
   `would-terminate` is observation only; `terminate-requested` and `termination-pending` do not prove exit;
   `terminated` records an observed exit. Missing, stale, rotated or malformed evidence is a coverage gap.
   Separate an 8 GiB allocation denial from global-pressure termination and ordinary CPU contention.
   Layer 2 is exclusion-based across user applications; it is independent of layer 1's executable list
   and job membership. Java, browsers and AI hosts can be victims. Preview current eligibility with
   `pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Candidates -Json`;
   this uses the installed policy and does not establish historical eligibility or current pressure.
   Do not disable limits or expand termination targets as a diagnostic shortcut.
3. Compare physical availability, committed bytes/limit, application private bytes, working sets, WSL VM usage, paged pool, and nonpaged pool. Do not add unlike categories as if they were independent.
4. Use `memtop` for an interactive view. Use `memmap` for cache/standby/mapped-file ownership. Use `poolmon` and `pooltag <tag>` for kernel pool growth.
5. Attach exported snapshots or existing ETL to a Tricky case and inspect before recording a profile.
6. If growth over time is the gap, recommend periodic snapshots or the smallest relevant WPR capture with a clear duration. Avoid an unbounded trace.
7. Recommend `killapp <name>` only after identifying the full process group, expected service impact, recoverability, and evidence that termination addresses current pressure.
8. Update the Tricky report with the ownership breakdown and a safe next action.

Never equate a large working set with a leak by itself.
