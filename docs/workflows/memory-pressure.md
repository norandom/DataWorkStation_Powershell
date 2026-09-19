# Memory pressure

Start with Windows commit and kernel memory, then decide whether the pressure belongs to an application, WSL, containers, or a kernel pool.

For prevention and the limits of each control, see
[Windows workload memory limits and optional Process Lasso](../workload-memory.md).
It explains xdist and AI test concurrency, the 8 GiB Job Object budgets, Java's current exclusion,
and why ProBalance does not prevent memory exhaustion.

```powershell
mem
memapps
memproc
wslmem
```

- `memapps` aggregates processes by application name and sorts by private bytes.
- `memproc` shows individual processes.
- `memtop` opens the interactive system view.
- `poolmon` is appropriate when paged or nonpaged pool is unexpectedly large; `pooltag TAG` resolves known pool tags.
- `memmap` opens RAMMap when file cache, standby lists, or driver allocations need a graphical breakdown.

Do not kill the first process with a large working set automatically. Private bytes, commit pressure, mapped files, WSL VM memory, and kernel pools describe different ownership.

For a case:

```powershell
tricky new memory-growth -Problem 'Commit grows until applications fail' -Target 'worker.exe'
tricky report memory-growth -Open
```

## Optional workload commit limits

Inspect or explicitly apply the Windows policy:

```powershell
pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Test
sudo pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Ensure
pwsh -NoProfile -File .\tests\Test-WorkloadMemoryLimits.ps1
sudo pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Remove
```

`config/workload-memory-limits.psd1` declares an 8 GiB private commit budget per independent
Python or `dotnet.exe` process tree, and 8 GiB per selected AI host process. Targets include Codex, Claude, OpenCode,
Antigravity CLI, Grok, Copilot and Cline. Cursor and Node/Bun-hosted Cline/Copilot are matched by
their tool path or command line; arbitrary Node, Java and browser processes are not selected.
Python and .NET descendants share their root's budget, including tools or browsers it launches.
AI hosts allow children to leave their job so existing sandbox job hierarchies continue to work.
Matched Python/.NET children receive separate tree budgets; other AI helper processes are not
covered unless they independently match the policy. An entire AI session has no shared budget.
This does not identify arbitrary self-contained .NET executables as .NET workloads.

The optional `DataWorkStationMemoryLimits` LocalSystem service examines process starts every
500 ms and assigns matches to Windows Job Objects. Python/.NET use `JOB_OBJECT_LIMIT_JOB_MEMORY`,
with children inheriting the tree budget. AI hosts use `JOB_OBJECT_LIMIT_PROCESS_MEMORY` with
silent child breakaway. Windows refuses allocations exceeding the applicable budget.
There is a detection window before assignment, and assignment errors (including incompatible
existing jobs) are reported in `%ProgramData%\DataWorkStationMemoryLimits\status.json` and `events.jsonl`.
`Test -Json` includes actual job limit readback, process IDs, heartbeat, and assignment errors.

No termination or working-set trimming is used. Applications may handle allocation failure, raise
`MemoryError`/`OutOfMemoryException`, or crash if they cannot handle it. Stopping the service does not
terminate jobs; existing limits persist. `Remove` releases tracked limits without killing applications.
Several independent 8 GiB trees can still exhaust total system commit: this is workload containment,
not a guaranteed system-wide reserve. WSL Linux processes use the separate shared WSL VM policy.
The Windows page file is unchanged. The service uses no downloaded runtime and builds with the
installed Windows .NET Framework compiler. Installation protects its binaries and policy under
Program Files; all-user status and bounded logs are under ProgramData.

Ensure also sets `PYTEST_XDIST_AUTO_NUM_WORKERS=3` at Windows machine scope. Reopen terminals
and AI applications to inherit the value. It controls pytest-xdist automatic worker selection;
an explicit `pytest -n N` or project hook can override it. Linux environments inside WSL require
their own environment configuration. Removing the service retains this environment preference.

## Process Lasso responsiveness

Process Lasso is optional and separately licensed. Our commercial deployment requires a paid
license; see [Bitsum's terms](https://bitsum.com/howfree/). Installing the `ProcessLasso` module
does not apply this responsiveness policy or install the workload memory service.

```powershell
pwsh -NoProfile -File .\scripts\Set-ProcessLassoResponsiveness.ps1 -Mode Test
sudo pwsh -NoProfile -File .\scripts\Set-ProcessLassoResponsiveness.ps1 -Mode Ensure
```

The policy retains ProBalance's normal CPU thresholds and temporary Below Normal adjustment,
protects the foreground process, permits its background children to be balanced, and excludes
services and the desktop/recovery tools. It disables SmartTrim and foreground boosting. It does
not add watchdog termination rules, hard CPU affinity, real-time priority, or power-plan overrides.
The governor runs automatically as LocalSystem with 5/15/60-second recovery delays. Ensure backs
up the INI and preserves unrelated settings. This is a responsiveness baseline, not a benchmarked
claim of optimal performance or a solution to driver crashes.
