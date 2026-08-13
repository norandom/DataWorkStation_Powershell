---
name: diagnose-memory
description: Diagnose Windows memory pressure, rising commit, process private bytes, working sets, WSL or Docker memory, file cache, and paged/nonpaged kernel pools. Use when RAM fills, allocation fails, or the user needs evidence for what can safely be terminated.
---

# Diagnose Memory

Separate ownership classes before recommending termination.

## Workflow

1. Read `../../../docs/workflows/memory-pressure.md`.
2. Inspect `mem`, `memapps`, and `memproc`; use `wslmem` when WSL or Docker is relevant.
3. Compare physical availability, committed bytes/limit, application private bytes, working sets, WSL VM usage, paged pool, and nonpaged pool. Do not add unlike categories as if they were independent.
4. Use `memtop` for an interactive view. Use `memmap` for cache/standby/mapped-file ownership. Use `poolmon` and `pooltag <tag>` for kernel pool growth.
5. Attach exported snapshots or existing ETL to a Tricky case and inspect before recording a profile.
6. If growth over time is the gap, recommend periodic snapshots or the smallest relevant WPR capture with a clear duration. Avoid an unbounded trace.
7. Recommend `killapp <name>` only after identifying the full process group, expected service impact, recoverability, and evidence that termination addresses current pressure.
8. Update the Tricky report with the ownership breakdown and a safe next action.

Never equate a large working set with a leak by itself.
