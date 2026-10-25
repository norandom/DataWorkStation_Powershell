# Why MemoryOptimize can reclaim gigabytes of Windows RAM

`MemoryOptimize --now` can make several gigabytes of physical RAM available in seconds.
It asks Windows to trim resident memory and reclaim caches. Applications can keep their
allocations while fewer pages occupy RAM. Whether the next task becomes faster depends
on which pages it needs again.

An operator reported this result from the repository command:

```text
Snapshot UsedGiB AvailableGiB
Before     22.74         6.88
After      19.04        10.58

Available RAM change: +3.695 GiB (system-wide measurement).
```

The increase is an observation. It does not identify a leak, establish a drop in commit,
or measure a speedup. The rows are rounded; the change uses the underlying samples.
Start with that distinction, then follow the mechanism below.

## Use the command and keep the measurements separate

```powershell
MemoryOptimize                  # Show usage only
MemoryOptimize --now -WhatIf     # Preview without cleaning
mem                             # Inspect RAM and commit
MemoryOptimize --now             # Administrator/UAC; cleanup; before/after RAM; no tray
mem                             # Inspect commit separately after cleanup
MemoryOptimize --run             # Open the normal application
```

Add `-Json` to `--now` for structured RAM measurements. The wrapper samples
`Win32_OperatingSystem` before launching the executable and after it exits. `UsedGiB`
means visible physical capacity minus available physical memory, not the sum of process
heaps. Other applications keep running between samples. UAC interaction can extend that
interval, and the observed change can be negative.

The alias is in `profile/Aliases.ps1`. `Invoke-MemoryOptimization` in `profile/Tools.ps1`
launches these arguments:

```text
WinMemoryCleaner.exe /ModifiedFileCache /StandbyList /WorkingSet
```

Use the [memory-pressure workflow](workflows/memory-pressure.md) to investigate an owner
when consumption keeps growing, and the [workload policy](workload-memory.md) to configure
containment and emergency recovery.

## Allocation, residency and availability answer different questions

Applications use virtual addresses. Windows maintains page tables that translate them
to physical addresses. A program can retain the same pointer while Windows changes where
the page's contents reside. An accessible application address therefore does not mean
that its contents occupy a dedicated physical page at every moment.
[Microsoft: virtual address space](https://learn.microsoft.com/en-us/windows/win32/memory/virtual-address-space).

| Quantity | Question it answers | Relationship to cleanup |
|---|---|---|
| Virtual address space | Which address ranges can this process use? | Trimming does not release those ranges |
| Committed memory | How much backing has Windows promised for allocations? | Moving pages out of RAM does not cancel the promise |
| Working set | Which pageable process pages currently reside in RAM? | Trimming directly reduces residency |
| Available physical RAM | How much RAM can Windows supply without first writing its contents out? | Reclamation can increase it |
| Free RAM | How much RAM lacks useful retained contents? | Purging caches can increase it without increasing available RAM |

Commit charges the system before a physical page necessarily exists. Physical allocation
can wait until an address is touched. Decommitting or releasing an allocation is separate
from moving its contents. A cleaner cannot infer which objects an application no longer
needs from its working-set size.
[Microsoft: VirtualAlloc](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualalloc),
[VirtualFree](https://learn.microsoft.com/en-us/windows/win32/api/memoryapi/nf-memoryapi-virtualfree).

For example, a process might retain 4 GiB of private committed allocations with 3 GiB
resident. After trimming it might still retain 4 GiB while only 1 GiB remains resident.
These are illustrative numbers, not another workstation measurement. If the original
objects leaked, changing their residency leaves that leak intact.

## A trimmed page can remain in RAM

A working set contains pageable resident memory. After removal from all relevant working
sets, a clean page can remain cached on standby. A dirty page needs its changes preserved
before its physical storage can be reused. Shared pages complicate attribution: removing
one process's reference does not necessarily release the physical page.
[Microsoft: working sets](https://learn.microsoft.com/en-us/windows/win32/memory/working-set).

```text
                         resident working-set page
                            /                \
                    trim clean             trim dirty
                        /                      \
               standby list                modified list
               cached contents             changes need preservation
                        ^                      |
                        +------ writeback -----+
                        |
               purge or reuse
                        |
               physical storage reusable
```

This simplified path excludes nonpaged kernel allocations and large pages, which an
ordinary working-set trim cannot reclaim. It is not a complete description of every
Windows page state or of memory compression.

The next access determines the cost. If the contents remain in RAM, Windows can resolve
a soft page fault. If it needs the backing file or pagefile, the fault is hard and requires
I/O. Neither term means an application error. Clearing a cached copy can turn inexpensive
reuse into a storage read.
[Microsoft: working-set faults](https://learn.microsoft.com/en-us/windows/win32/memory/working-set).

Available memory includes standby, free and zeroed pages. Standby is useful cache that
Windows can repurpose; it already counts toward the available total.
[Microsoft: available-memory accounting](https://techcommunity.microsoft.com/blog/askperf/an-overview-of-troubleshooting-memory-issues---part-two/372679).

```text
Available = standby + free + zeroed
```

Moving a gigabyte from standby to free changes the distribution within that sum. It does
not itself add a gigabyte to available RAM. The reported 3.695 GiB increase is therefore
more consistent with working-set reclamation and possibly completed writeback than with
standby purging alone. That attribution is an inference: the wrapper measures the combined
effect, including concurrent activity.

## Follow the source from arguments to kernel calls

The source review used commit
[`a19f25719c9b9a58a0acea99cb8adb4737d2d318`](https://github.com/IgorMundstein/WinMemoryCleaner/tree/a19f25719c9b9a58a0acea99cb8adb4737d2d318),
checked on 2026-10-25. The links pin this explanation. They do not attest that an installed
binary was reproduced from that revision.

In [`App.xaml.cs`](https://github.com/IgorMundstein/WinMemoryCleaner/blob/a19f25719c9b9a58a0acea99cb8adb4737d2d318/src/App.xaml.cs),
recognized memory-area arguments select `StartupType.Silent`. That branch calls `Optimize`
and shuts down. The GUI branch creates the tray icon. `App.ReleaseMemory` collects garbage
and trims the cleaner's own process; it does not collect another program's heap.

[`ComputerService.cs`](https://github.com/IgorMundstein/WinMemoryCleaner/blob/a19f25719c9b9a58a0acea99cb8adb4737d2d318/src/Service/ComputerService.cs)
uses a fixed order rather than argument order:

| Order | Selected area | Source behavior |
|---|---|---|
| 1 | `WorkingSet` | Without exclusions, requests system-wide `MemoryEmptyWorkingSets`; with exclusions, enumerates eligible processes and calls `EmptyWorkingSet` |
| 2 | `StandbyList` | Requests `MemoryPurgeStandbyList` |
| 3 | `ModifiedFileCache` | Opens fixed-drive volumes, attempts device-control calls, then calls `FlushFileBuffers` |

System-wide trimming and standby purging enable `SeProfileSingleProcessPrivilege`.
The exclusion-based path enables `SeDebugPrivilege`. `ModifiedFileCache` differs from
`ModifiedPageList`; our command does not select the latter. Individual failures are caught
and logged, so process exit success does not prove that every area succeeded.

[`NativeMethods.cs`](https://github.com/IgorMundstein/WinMemoryCleaner/blob/a19f25719c9b9a58a0acea99cb8adb4737d2d318/src/Interop/NativeMethods.cs)
declares the C# P/Invoke calls into `ntdll.dll`, `psapi.dll`, `kernel32.dll` and privilege
functions in `advapi32.dll`. The cleaner requests operations; Windows owns the page tables
and physical-memory bookkeeping.

[`Constants.cs`](https://github.com/IgorMundstein/WinMemoryCleaner/blob/a19f25719c9b9a58a0acea99cb8adb4737d2d318/src/Core/Constants.cs)
defines `SystemMemoryListInformation` as 80, `MemoryEmptyWorkingSets` as 2 and
`MemoryPurgeStandbyList` as 4. These native numeric requests differ from the public Win32
`EmptyWorkingSet` API. Do not assume every native information class has the public
compatibility contract of a documented Win32 function.

`EmptyWorkingSet` asks Windows to remove as many pages as possible. Access rights still
apply; it cannot arbitrarily discard live application state.
[Microsoft: EmptyWorkingSet](https://learn.microsoft.com/en-us/windows/win32/api/psapi/nf-psapi-emptyworkingset).

`FlushFileBuffers` on a volume requests writeout for its open files and requires
administrator privileges. Writeback can remove an obstacle to reuse. It does not delete
an application's allocation. The additional device-control calls are best-effort in this
implementation; their names do not establish that they succeeded on a particular host.
[Microsoft: FlushFileBuffers](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers).

## Why Windows leaves reclaimable pages resident

Resident pages can save work later. Earlier browser tabs, previous editor files or worker
startup code may be touched again. Keeping their contents accessible avoids fault handling
and storage reads. Windows balances that opportunity against demand elsewhere; it already
trims working sets under pressure.

A forced trim changes the timing of that tradeoff. A quiet application may stay small
afterwards. An active one may rebuild its working set immediately. Microsoft documents
working sets as dependent on RAM capacity, activity and trimming policy, and describes
reference-set analysis for finding which pages work actually touches.
[Microsoft: reference sets](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpa-reference-set).

Open source makes this mechanism inspectable. The useful question is how much reclamation
lasts through the next task, and what that task pays to recover evicted contents.

## Earlyoom tries reclamation before terminating an application

The Windows guard in `scripts/memory-limits/EarlyOom.cs` is separate from Debian earlyoom.
Ordinary pressure requires both available RAM and commit headroom at or below 7%.
Commit headroom at or below 3% is independently critical. Pressure must last three seconds.
These percentages use current capacities.

```text
sustained pressure
    -> cleanup enabled and outside its cooldown?
         yes: record attempt, run headless helper, read memory again
         no:  continue without another cleanup
    -> pressure resolved? stop recovery here
    -> pressure persists? select eligible application
    -> recheck pressure and held process identity
    -> record request, terminate one eligible process
```

The service uses the same three switches as `MemoryOptimize --now`. LocalSystem launches
a protected executable directly, without loading a user profile or requesting interactive
UAC. `Ensure` stages a signature-validated installed WinMemoryCleaner in the service's
Program Files directory and records its hash for drift inspection. It does not install
the vendor's service or configure tray/startup options.

The automatic interval defaults to 15 minutes. Set it explicitly with the flag:

```powershell
sudo pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Ensure -MemoryOptimizeCooldownMinutes 15
pwsh -NoProfile -File .\scripts\Set-WorkloadMemoryLimits.ps1 -Mode Test -MemoryOptimizeCooldownMinutes 15 -Json
```

For a lasting declaration change, edit `EarlyOom.MemoryOptimizeCooldownMinutes` in
`config/workload-memory-limits.psd1`. A flag overrides that declaration for the invocation;
use the same override when checking it, or change the declaration so future Ensure runs agree.
Set `MemoryOptimizeEnabled = $false` there to disable only the reclaim step.

The guard records each attempt before launch, including failed attempts. The timestamp
survives service restarts in
`%ProgramData%\DataWorkStationMemoryLimits\memory-optimize-last-attempt.txt`.
An unreadable record suppresses cleanup and logs the reason. Future timestamps also
suppress cleanup until the interval has elapsed.

The helper gets at most ten seconds. On timeout the guard stops only its own helper, then
rechecks pressure. Missing executables and failed cleanup also reach that recheck. Invalid
telemetry or unavailable required audit logging blocks destructive action. Observe and
Disabled modes never clean memory.

This interval is separate from the 15-second intervention cooldown. It limits automatic
attempts, not manual `MemoryOptimize --now` calls. Termination exclusions do not become
exclusions from system-wide trimming; the vendor's exclusion setting governs its own
per-process path.

Reclaiming pages may leave commit exhausted. The guard reads `CommitTotal`, `CommitLimit`
and `PhysicalAvailable` through `GetPerformanceInfo`, multiplying page counts by `PageSize`.
A larger available-RAM number cannot cancel an emergency commit condition.
[Microsoft: PERFORMANCE_INFORMATION](https://learn.microsoft.com/en-us/windows/win32/api/psapi/ns-psapi-performance_information).

Inspect existing records before any new capture:

```powershell
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Events -Last 100 -Json
pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Status -Json
```

Look for `reclaim-requested`, `reclaim-completed`, `reclaim-failed`, `reclaim-timeout` or
`reclaim-skipped`, then `recovered` or a termination decision. Completion records include
before/after available RAM and commit headroom. They describe the combined attempt, not
a verified result for every upstream API call.

## Test whether cleanup helps the work you care about

Treat "this improves my workload" as a hypothesis. A repeatable increase in elapsed time
or stalls after cleanup would disprove it for that workload, despite a better RAM number.
If only the counter changes and the work does not improve, a performance claim is unsupported.

Keep input, concurrency and application state comparable. Alternate runs with and without
one explicit cleanup. Record the immediate RAM change, commit headroom and actual task
duration. Check memory again after the task. This is a proposed comparison, not a benchmark
already performed by this repository.

| Observation | Interpretation to test |
|---|---|
| Available RAM rises and remains higher through the task | Much of the displaced residency was not immediately needed |
| RAM rises, then falls while the task stalls | Rebuilding residency may have cost more than reclamation saved |
| RAM rises but commit headroom stays critical | Allocation pressure persists |
| Free RAM rises while available RAM barely changes | Standby-to-free redistribution may dominate |
| Private allocations keep growing across repeated runs | Investigate the owner and lifetime of allocations |

Use `mem`, `memapps` and `memproc` for command-level inspection. `memmap` opens RAMMap for
page categories. If counters cannot explain the behavior, inspect existing profiles before
arranging a bounded trace through the [performance workflow](workflows/performance-profiling.md).
Reading this page requires no cleanup, capture or stress-induced termination.
