# Windows workload memory limits and optional Process Lasso

Inspect the declared controls before changing the workstation:

```powershell
mem
pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-ProcessLassoState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Test -Module ProcessLasso -Plan
```

Use `-Json` on the state commands for automation. The memory service and Process Lasso are
independent, optional installations. Neither is needed to use the worker-count environment
variable. Installing Process Lasso does not install our memory service or apply our separate
responsiveness settings.

## Why Windows 11 needs an explicit workload budget

An ordinary desktop application does not automatically receive a small, isolated memory budget
that protects the rest of the workstation. User-mode programs can collectively consume the
available system commit. When commit approaches its limit, allocations can fail across unrelated
applications, and paging pressure can make the desktop difficult to use. A larger page file
increases commit capacity; it does not contain a runaway workload. See Microsoft's
[explanation of system commit and page files](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/introduction-to-the-page-file).

Windows does provide a kernel-enforced containment mechanism:
[Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
Our optional service assigns selected workloads to jobs with explicit commit limits. It is more
accurate to say that there is **no automatic per-workload OOM fence for ordinary desktop apps**
than that Windows has no memory-limiting mechanism. The service still leaves a detection window,
does not cover every executable, and cannot reserve enough memory for all other applications.

## What each control actually limits

| Control | Declared behavior | Boundary |
|---|---|---|
| `PYTEST_XDIST_AUTO_NUM_WORKERS=3` | Three workers for xdist automatic selection | A concurrency preference, not a byte limit; explicit `-n N` or a project hook can override it |
| Workload memory service | 8 GiB private commit per independent Python or `dotnet.exe` tree | Descendants share the root budget when assignment succeeds; multiple independent roots have separate budgets |
| Selected AI host limits | 8 GiB per matched host process | Sandbox children may break away; this is not one budget for an entire AI session |
| Process Lasso ProBalance | Temporarily adjusts CPU priorities under contention | Helps desktop responsiveness; does not enforce the 8 GiB memory budgets |
| Process Lasso Watchdog | Optional operator-defined threshold actions | Reactive rules, not an allocation-time memory fence; no watchdog rules are installed by this repo |
| Java heap options | No override declared here | Java is excluded from the memory-service target list; no managed 8 GiB Java cap exists |

The policy is in `config/workload-memory-limits.psd1`. Its **8 GiB means 8,589,934,592 bytes**,
not 8 GB decimal and not a working-set target. The service uses Windows
[process or job commit limits](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_extended_limit_information).
It denies allocations beyond the applicable budget rather than killing the process itself;
the application can still fail or crash when it cannot allocate memory.

Python's limit here comes from this service, not a Python memory environment variable.
`PYTEST_XDIST_AUTO_NUM_WORKERS` only reduces the default worker count. For Java, a project could
choose `java -Xmx8g ...`, but `-Xmx` limits the Java heap, not total JVM process memory or its
children. Native allocations, thread stacks and other JVM memory require additional headroom.
This repository does not currently set `JAVA_TOOL_OPTIONS`, `JDK_JAVA_OPTIONS` or `_JAVA_OPTIONS`
to impose that heap limit. See the [Java launcher reference](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html).

## xdist and AI tools launching tests

Each xdist worker is a separate process, with its own imports, fixtures and application data.
A CPU-sized worker count can multiply memory demand before the first useful test result.
Several AI tasks launching separate test runs multiply it again.

For an explicit bounded run, use:

```powershell
uv run pytest -n 3
# For a memory-heavy reproduction, run without xdist workers:
uv run pytest -n 0
```

The machine-level environment setting applies to newly started Windows processes. Restart
terminals, IDEs and AI applications after changing it so their children inherit the setting.
It affects `-n auto` and `-n logical`; an explicit `-n 16` bypasses that preference. A project
`pytest_xdist_auto_num_workers` hook takes precedence. WSL and remote execution need their own
configuration. These rules are documented by [pytest-xdist](https://pytest-xdist.readthedocs.io/en/latest/distribution.html).

For an ordinary local pytest controller successfully assigned to a tree job, its workers share
the **same 8 GiB total**, rather than each getting 8 GiB. Three independent pytest controllers
can nevertheless have three budgets, totaling 24 GiB before AI hosts and other applications.
AI sandboxes can introduce additional job boundaries; check assignment errors instead of assuming
the complete descendant tree is covered.

AI workflows should choose an explicit worker count, avoid overlapping memory-heavy suites,
inspect commit with `mem`, and use the service's `Test -Json` to verify actual coverage. A passing
configuration check is not a guarantee against system-wide OOM. Existing service status and
assignment errors are recorded under `%ProgramData%\DataWorkStationMemoryLimits`.

## Optional Process Lasso and its commercial license

For this workstation's commercial use, **purchase and activate a paid Process Lasso license**.
Bitsum requires purchase within 30 days of commercial deployment. ProBalance is also available
in the free edition, while continued use of trial-only features such as Watchdog, CPU Limiter
and instance-count limits requires Pro. See [Bitsum's current licensing and feature table](https://bitsum.com/howfree/).

`ProcessLasso` has `Default = $false` and is excluded from default and `-Module All` runs:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module ProcessLasso -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module ProcessLasso
```

Installation is machine-wide and may require elevation. License purchase and activation are
operator-managed; no key is stored in this repository. Package compliance verifies installed
files and explicitly leaves license status unchecked.

Lasso adds ongoing CPU scheduling control even when a tool ignores a worker-count preference,
and its governor can apply rules without leaving the GUI open. Its
[ProBalance and process automation](https://bitsum.com/apps/process-lasso/docs/) complement the
memory service. They do not replace it. Our separately applied responsiveness policy protects
the foreground process and desktop/recovery tools, permits background child balancing, and
disables SmartTrim, foreground boosting and cache/standby-list clearing. It installs no watchdog
termination rule, hard CPU affinity or power-plan override.

Inspect and apply that policy only after configuring the vendor governor as a LocalSystem service:

```powershell
pwsh -NoProfile -File .\scripts\Set-ProcessLassoResponsiveness.ps1 -Mode Test
sudo pwsh -NoProfile -File .\scripts\Set-ProcessLassoResponsiveness.ps1 -Mode Ensure
```

`Ensure` backs up the INI, preserves unrelated settings, and restarts the governor. For the
independent memory-service install/remove commands, precise target selection, detection gaps,
and surviving job limits, see [Memory pressure](workflows/memory-pressure.md#optional-workload-commit-limits).

### ProBalance and Processor Group Extender

Keep [ProBalance](https://bitsum.com/apps/process-lasso/docs/algorithms/probalance/) for temporary
background priority adjustments under CPU contention. Its restraint/restoration logs help separate
CPU scheduling effects from memory-pressure interventions. Foreground boosting and Efficiency Mode
are not needed for our baseline.

[Processor Group Extender](https://bitsum.com/apps/process-lasso/docs/algorithms/group-extender/)
is intended for applications confined to one processor group on large systems. Bitsum says it is
unnecessary on Windows 11, which spans groups by default. A machine with 24 logical processors
does not need this feature. Neither algorithm performs early-OOM recovery.

## Early-OOM recovery and audit logs

The Windows companion to [earlyoom](https://github.com/rfjakob/earlyoom) is implemented inside our
existing memory-limit service. PowerShell provides the human commands; a small compiled service
performs the repeated sampling and action. It runs independently of Process Lasso. Lasso's
[Watchdog](https://bitsum.com/apps/process-lasso/docs/rules/watchdog/) provides per-process usage
thresholds, not the combined system-pressure decision used here.

There are two layers. **Layer 1** controls selected workloads: our 8 GiB Job Object limits and
xdist concurrency setting, plus optional Process Lasso rules and CPU responsiveness controls.
**Layer 2** watches total system pressure and considers all ordinary user applications, including
Java, browsers, AI hosts and previously unknown executables. It does not depend on layer 1's
executable list or Job Object membership. This catches aggregate exhaustion from parallel agents
even when each individual process stays below its own limit.

Inspect current capacities and the calculated thresholds before applying the policy:

```powershell
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Plan
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Status -Json
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Candidates
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Events -Last 100
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Events -SinceUtc '2026-09-19T00:00:00Z' -Json
```

`Plan`, `Status`, `Candidates` and `Events` are read-only. `Candidates` uses the installed executable
and policy to list eligible processes by private bytes and count exclusion reasons. Use `sudo`
for elevated visibility; an ordinary invocation cannot inspect every process the service can see.
It previews eligibility even without current pressure and never requests termination access.
Edit the `EarlyOom` block in
`config/workload-memory-limits.psd1`, then explicitly apply it:

```powershell
sudo pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Ensure
pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Test
```

`Ensure` rebuilds and restarts the service. The declared mode is **Enforce**, which can forcibly
terminate eligible applications and lose their in-progress work. Choose **Observe** in the declaration
to record `would-terminate` decisions without stopping anything, or **Disabled** to retain only
the allocation limits. These modes take effect after `Ensure`.

The default decision uses:

| Parameter | Default | Meaning |
|---|---|---|
| Available physical memory | 10% | Includes immediately reusable memory, not just empty pages |
| Commit headroom | 10% | Both this and the physical-memory threshold must be crossed |
| Emergency commit headroom | 3% | Independent trigger even if physical RAM is still available |
| Sustained pressure | 3 seconds | Pressure must persist before selecting a process |
| Cooldown | 15 seconds | At most one attempted intervention per interval |
| Candidate minimum | 256 MiB private bytes | Skip small processes unlikely to provide useful recovery |

The service samples at the configured 500 ms loop interval plus processing time. It reads physical
capacity, available RAM, current commit limit/usage and page-file allocation/usage from Windows.
Threshold bytes are recomputed from current capacity; RAM/page-file changes need no fixed-size
rule rewrite. It does **not** resize the page file. Missing page-file statistics are represented
as unknown; the authoritative decision uses
[current commit headroom](https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-performance_information).
This is a Windows adaptation, not a literal comparison against Linux free swap.

Under sustained pressure it enumerates all processes and chooses the largest eligible private-byte
consumer. Mandatory exclusions protect the guard itself, system PIDs, session-zero services,
critical processes, Windows-directory images, Windows service/window accounts and processes whose
identity or memory cannot be queried. `EarlyOom.ExcludedExecutables` adds exact, case-insensitive
names for the desktop shell, Task Manager, terminals, PowerShell and Process Lasso. There is no
inclusion list. An excluded shell does not exempt its child applications. Other applications,
including foreground apps and AI hosts, may be stopped. These exclusions deliberately leave
Windows and recovery tools outside the recovery scope.

A held process handle and creation-time check prevent acting on a reused PID. The service rechecks
pressure and all candidate exclusions immediately before acting and refuses an action if the
pre-action audit record cannot be written.

One application process is terminated at a time, not its entire tree. The recovery action is
forced termination with exit code `0xE0000001`.
Remaining workers or AI retries can allocate again. Use `pytest --max-worker-restart=0 -n 3` when
automatic worker replacement would defeat recovery. There is no guaranteed OOM protection if
pressure grows faster than the polling loop or no eligible candidate exists.

The service writes `earlyoom.jsonl` under `%ProgramData%\DataWorkStationMemoryLimits`, with one
previous file retained after rotation at approximately 4 MiB. It records periodic health samples,
pressure transitions, `would-terminate`, `no-candidate`, pre-action requests, termination outcome
and recovery. Records include UTC, mode, thresholds, RAM/commit/page-file readings and candidate
PID, creation time, executable name, private bytes, session and selection scope. Older records
instead include managed-job identity from the former worker-only policy. The guard does not log
command lines, environment values or process contents.

`terminated` means the process exit was observed; `termination-pending` means the asynchronous
request has not yet been observed to finish. Match PID **and creation time**, not PID alone.
`status.json` includes the latest guard state; a fault or stale heartbeat is a coverage gap.
The event command reads a bounded tail across both log files and reports malformed/incomplete
records rather than silently treating them as no activity. Copy relevant evidence to a Tricky
case before rotation removes it. Memory/crash skills inspect these existing records before new
capture, and distinguish deliberate recovery from allocation denial or an ordinary crash.
