# Performance profiling

Choose the narrowest stack source that matches the workload.

| Workload | Capture | View |
|---|---|---|
| Native or system-wide | `profile-native-record NAME -Seconds 30` | `profile-native-open NAME` / WPA |
| Python | `profile-python -ProcessId PID -Seconds 30 -Output python-NAME.svg` | standalone interactive SVG |
| .NET | `profile-dotnet -ProcessId PID -Seconds 30 -OutputBase dotnet-NAME` | `profile-view *.speedscope.json` |
| AMD hardware counters | `uprof` / `uprof-cli` | AMD uProf |

Run `profile-status` first. WPR/WPA, py-spy, dotnet-trace, and Speedscope are desired-state
dependencies. AMD uProf remains a separate installation because its EULA requires explicit
acceptance.

WPA's flame graph is best for compiled and system-wide ETW analysis. py-spy produces a small portable Python artifact without importing the workload environment. dotnet-trace uses EventPipe and converts to Speedscope. None of these tools need the AMD/PyTorch Python interpreter.
