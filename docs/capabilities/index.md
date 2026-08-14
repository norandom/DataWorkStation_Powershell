# Capabilities

The environment is organized around questions, not product names.

| Domain | Inspect | Capture or change state | Main artifact |
|---|---|---|---|
| Memory | `mem`, `memapps`, `memproc`, `wslmem` | `memtop`, `poolmon`, WPR | snapshot or ETL |
| Events | `problems`, `crashes`, `loginfail` | `eventlog-start/stop` | EVTX and ETL |
| Crashes | `crashes`, `dump-open` | `dump-on-crash`, `debug-run`, `ttd-record` | DMP or TTD trace |
| Network | `ports`, `connections`, `pcap-*` | `pcap-start/stop` | ETL and PCAPNG |
| Profiling | `profile-status`, `profile-view` | native, Python, or .NET profile command | ETL, SVG, nettrace |
| Security state | status commands | enable/disable/ensure commands | state objects |
| Workstation modules | `Apply-Workstation.ps1 -Module NAME -Plan` | focused Test/Ensure in dependency order | module plan |
| Windows hardening | `Set-HardeningState.ps1 -Mode Test` | explicit `Ensure` through Windows sudo | state object |
| Windows debloat | `Set-DebloatState.ps1 -Mode Plan/Test` | explicit `Ensure -ConfirmRemoval` only | state object and pre-removal JSON |
| Desktop focus | `Set-FocusFollowsMouseState.ps1 -Mode Test` | ensure hover focus without raising | state object |
| Code analysis | `codeql`, `semgrep` | explicit scan commands | SARIF or findings |
| Data movement | `rclone`, `rsync`, `taildrive` | explicit copy or mount | remote filesystem |
| Skill development | `skills-validate`, `skillopt-status` | reviewed SkillOpt run and explicit adoption | task set and staged skill |

`config/capabilities.psd1` is the machine-readable catalog used by `tricky capabilities` and case routing.
