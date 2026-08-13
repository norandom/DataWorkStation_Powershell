---
name: profile-dotnet
description: Profile .NET processes on Windows with dotnet-trace EventPipe data and Speedscope output. Use for managed CPU stacks, runtime activity, and portable flame-graph inspection without attaching a full debugger.
---

# Profile .NET

Capture bounded EventPipe evidence and view the converted Speedscope profile.

## Workflow

1. Read `../../../docs/workflows/performance-profiling.md`; run `profile-status` and `profile-dotnet-ps`.
2. Inspect existing `.nettrace` or `.speedscope.json` evidence first and attach it to the Tricky case.
3. Select the managed process and representative interval. Check whether child processes or native work require a system-wide profile instead.
4. Consult `profile-dotnet -?` and run a bounded capture with `-ProcessId` or `-Executable`, `-Seconds`, and an explicit `-OutputBase`. Do not guess wrapper syntax.
5. Open the generated Speedscope JSON with `profile-view`. Compare total and self weight, thread/process context, GC/runtime frames, and application frames.
6. Update the Tricky report with capture interval, runtime version, hot stacks, and limitations.

Use `$profile-native` when scheduler, native dependencies, drivers, or cross-process system context dominate.
