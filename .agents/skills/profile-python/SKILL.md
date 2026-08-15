---
name: profile-python
description: Profile a Python process on Windows with py-spy and produce a standalone interactive SVG flame graph. Use for Python CPU hotspots when low-overhead sampled stacks are sufficient and the workload environment should remain untouched.
---

# Profile Python

Use the isolated py-spy tool, not the workload's AMD/PyTorch interpreter.

## Workflow

1. Read `../../../docs/workflows/performance-profiling.md` and run `profile-status`.
2. Inspect an existing SVG before capturing again; add it to the Tricky case.
3. Identify the process ID, representative workload interval, child-process behavior, and bounded duration.
4. Do not start any capture without explicit operator authorization. If capture is approved, run the repository wrapper shown by `profile-python -?`, using `-ProcessId` or `-Executable`, a bounded `-Seconds`, and an explicit `-Output`. Do not guess parameters.
5. Open the SVG with `profile-view <svg>`. Interpret width as sampled stack weight, check native/idle/subprocess gaps, and preserve the exact capture command.
6. Update the Tricky report with dominant stacks, sample limitations, and the next targeted experiment.

Do not install profiling packages into the quant or AMD Python environment.
