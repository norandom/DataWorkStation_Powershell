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
