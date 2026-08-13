---
name: profile-native
description: Profile native, compiled, mixed-process, driver-adjacent, or system-wide Windows CPU and latency behavior with WPR and WPA. Use when Python or .NET runtime-specific profilers are not the correct source, or when scheduler and system context matter.
---

# Profile Native Code

Use WPR for bounded ETW capture and WPA for stack/flame-graph analysis.

## Workflow

1. Read `../../../docs/workflows/performance-profiling.md` and run `profile-status`.
2. Inspect existing ETL first. Add it to the Tricky case and open with `profile-view <etl>` or `profile-native-open <name>`.
3. Confirm the slow interval, workload, symbols, target processes, and whether system-wide context is required.
4. If capture is needed, prefer `profile-native-record <name> -Seconds <bounded-duration>`. Use start/stop only when an interactive reproduction requires it; always ensure stop or cancel runs.
5. In WPA, filter the exact interval and target, then use CPU Usage (Sampled), stack, process/thread, and flame-graph views. Separate wall time, sampled CPU, waits, and disk/network latency.
6. Record hot stacks with inclusive/exclusive weight, time range, symbol quality, and alternative explanations in the Tricky report.

Do not use AMD uProf unless hardware-counter evidence is specifically required and its EULA-gated installation is already complete.
