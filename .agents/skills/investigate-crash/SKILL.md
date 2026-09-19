---
name: investigate-crash
description: Investigate Windows process crashes, segfault-like access violations, silent exits, unhandled exceptions, and hangs using existing Event Logs, WER evidence, dumps, WinDbg, ETW, and optional TTD. Use when a process disappears or stops responding without enough application output.
---

# Investigate Crash

For any user application that disappeared, inspect existing early-OOM events with
`pwsh -NoProfile -File .\scripts\Get-WorkloadMemoryDiagnostics.ps1 -Action Events -Last 100 -Json`
before attaching a debugger or starting capture. Match UTC, PID and process creation time.
An observed `terminated` event explains deliberate memory-pressure recovery; a request or
pending event alone does not establish exit. See `../../../docs/workload-memory.md#early-oom-recovery-and-audit-logs`.
The guard considers user applications independently of managed jobs or runtime names, including
Java, browsers and AI hosts; absence from the layer-1 target list does not rule out guard termination.

Escalate from historical evidence to targeted capture.
An application error dialog alone is not a crash. For failed HTTP/authenticated operations with
the process still responsive, use `diagnose-http` before considering a debugger attachment.

## Workflow

1. Read `../../../docs/workflows/crash-without-error.md`.
2. Identify executable, version/build, failure time, exit behavior, reproducibility, and whether the process crashed or hung.
3. Inspect `crashes -Hours <n>` and `problems -Hours <n>`. Add existing EVTX, ETL, WER dumps, or debugger files to the Tricky case.
4. Run `tricky inspect <case> -Json`. For EVTX, use provider, event ID, exception code, faulting module, and exact time as observations.
5. Open an existing dump with `dump-open <path>`. Record exception, failing thread, stack, modules, and symbol quality; distinguish symbol failure from program failure.
6. If historical records are insufficient and the failure reproduces, propose one scoped choice:
   - `eventlog-start/stop` for missing Windows/ETW context;
   - `dump-on-crash` for the failing stack and process state;
   - `debug-run` for an interactive breakpoint plan;
   - `ttd-record` only when execution history is necessary and available.
7. Make privilege, disk-volume, privacy, and stop conditions explicit before capture.
8. Update the Tricky report with observations, hypothesis, contradictions, and next breakpoint or evidence gap.

Do not register a machine-wide postmortem debugger or enable permanent verbose logging without explicit authorization.
