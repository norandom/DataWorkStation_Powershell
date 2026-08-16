# Crash without an error

Use existing Windows records before attaching a debugger:

```powershell
crashes -Hours 24
problems -Hours 24
```

For a reproducible executable, create a scoped development session. It temporarily increases the
relevant logging, captures ETW and Windows Error Reporting evidence, and restores the balanced
logging baseline when stopped:

```powershell
eventlog-start repro1 -Executable C:\path\tool.exe
# reproduce
eventlog-check repro1
eventlog-stop repro1
```

If events identify an exception but not the responsible stack, use `dump-on-crash`. Analyze an existing dump without opening the GUI:

```powershell
dump-analyze .\dumps\tool.dmp -Module tool,FaultingLibrary
```

`dump-analyze` runs `cdbX64.exe` headlessly and stops after a bounded timeout. It downloads public
symbols through Microsoft's symbol server into `%LocalAppData%\DataWorkStation\symbols` and writes a
sibling `.windbg.txt` log. The result distinguishes missing application or third-party PDBs from a
debugger failure. Use `-NoisySymbols` when a symbol request stalls. Use `dump-open` for interactive
WinDbg inspection. Use `ttd-record` only when the failure requires execution history and the
installed WinDbg package provides TTD.

Attach the resulting folder or dump to a case with `tricky add`. Reports should distinguish observations, inferences, and the next evidence gap.
