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
| Code analysis | `codeql`, `semgrep` | explicit scan commands | SARIF or findings |
| Data movement | `rclone`, `rsync`, `taildrive` | explicit copy or mount | remote filesystem |

`config/capabilities.psd1` is the machine-readable catalog used by `tricky capabilities` and case routing.
