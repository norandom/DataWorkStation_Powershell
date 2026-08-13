# A Windows workstation you can interrogate

DataWorkStation PowerShell turns a Windows engineering machine into an evidence-driven environment for administration, development, data science, quant work, and occasional forensics. Every workflow is available as a direct shell command and as structured output an AI tool can reason over.

## Start with the question

| Question | First command | Escalation |
|---|---|---|
| What is consuming memory? | `mem`, `memapps`, `memproc` | `memtop`, `poolmon`, native ETW profile |
| Why did this program disappear? | `crashes`, `problems` | scoped event session, crash dump, WinDbg |
| Why can it not connect? | `ports`, `connections` | PktMon capture, DNS/IPv6/firewall triage |
| Where is CPU time going? | `profile-status` | WPR/WPA, py-spy, or dotnet-trace |
| Is workstation policy still correct? | `./Apply-Workstation.ps1 -Mode Test` | `Ensure` or `Reinitialize` |
| How do I keep the investigation together? | `tricky new ...` | inspect and render a portable case report |
| How do skills improve safely? | `skills-validate`, `skillopt-status` | reviewed tasks, held-out gate, staged adoption |

## Evidence before instrumentation

The normal order is:

1. State the failing behavior and target.
2. Attach or reference existing EVTX, ETL, PCAPNG, dumps, profiles, and snapshots.
3. Inspect and visualize what is already known.
4. Identify a concrete evidence gap.
5. Start the smallest tracer that can fill that gap.

This avoids collecting another large trace when the answer is already in an event log or packet capture.

## The two interfaces

- Humans use memorable PowerShell commands and standalone HTML reports.
- Automation uses the same commands with `-Json` or `-AsObject`.

`tricky` is the shared case interface. It does not silently start privileged capture.
