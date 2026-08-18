# Performance profiling

Choose the narrowest stack source that matches the workload.

| Workload | Capture | View |
|---|---|---|
| Native or system-wide | `profile-native-record NAME -Seconds 30` | `profile-native-flamegraph NAME` / qView; `profile-native-open NAME` / WPA |
| Python | `profile-python -ProcessId PID -Seconds 30 -Output python-NAME.svg` | standalone interactive SVG |
| .NET | `profile-dotnet -ProcessId PID -Seconds 30 -OutputBase dotnet-NAME` | `profile-view *.speedscope.json` |
| AMD hardware counters | `uprof` / `uprof-cli` | AMD uProf |

Run `profile-status` first. WPR/WPA, qView, py-spy, dotnet-trace, and Speedscope are desired-state
dependencies. `profile-native-flamegraph` exports collapsed sampled stacks and a standalone SVG
headlessly through Microsoft's typed ETL processor, then opens the completed SVG in qView. The first
run restores the pinned TraceProcessor package through the declared .NET 10 project. AMD uProf
remains a separate installation because its EULA requires explicit acceptance.

The native SVG uses hex colors, contrast-aware text, and fixed canvas geometry for qView
compatibility. Keep the ETL for
WPA when timeline correlation or richer system context is needed. py-spy produces a small portable
Python artifact without importing the workload environment. dotnet-trace uses EventPipe and converts
to Speedscope. None of these tools need the AMD/PyTorch Python interpreter.
