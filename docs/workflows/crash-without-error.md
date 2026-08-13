# Crash without an error

Use existing Windows records before attaching a debugger:

```powershell
crashes -Hours 24
problems -Hours 24
```

For a reproducible executable, create a scoped development session. It temporarily increases relevant logging, captures ETW and Windows Error Reporting evidence, then returns logging to the balanced baseline:

```powershell
eventlog-start repro1 -Executable C:\path\tool.exe
# reproduce
eventlog-check repro1
eventlog-stop repro1
```

If events identify an exception but not the responsible stack, use `dump-on-crash`. Open an existing dump with `dump-open`. Use `ttd-record` only when the failure requires execution history and the WinDbg package exposes TTD on the machine.

Attach the resulting folder or dump to a case with `tricky add`. Reports should distinguish observations, inferences, and the next evidence gap.
