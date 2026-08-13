# PowerShell commands and aliases

The managed profile supports Windows PowerShell 5.1 and PowerShell 7. Some entries are functions or native executables rather than PowerShell `Alias` objects; this document groups them as shell commands.

## Input and prompt

| Key or command | Purpose |
|---|---|
| `Tab` | Open completion and select the next match. |
| `Shift+Tab` | Select the previous completion match. |
| `Up` / `Down` | Search history using the text already entered as a prefix. |
| `Ctrl+R` | Reverse-search command history. |
| Prompt | Shows `username@computer path>` using plain characters. |

## Files and text

Microsoft Coreutils executables take precedence over same-named PowerShell aliases:

`cat`, `cp`, `cut`, `date`, `dir`, `echo`, `env`, `expand`, `factor`, `false`, `head`, `hostname`, `join`, `link`, `ln`, `ls`, `md5sum`, `mkdir`, `mktemp`, `mv`, `nl`, `nproc`, `od`, `paste`, `pathchk`, `printenv`, `printf`, `pwd`, `readlink`, `realpath`, `rm`, `rmdir`, `sha1sum`, `sha256sum`, `sha512sum`, `sleep`, `sort`, `split`, `stat`, `sum`, `tac`, `tail`, `tee`, `test`, `touch`, `tr`, `true`, `truncate`, `uname`, `uniq`, `wc`, `whoami`.

| Command | Purpose |
|---|---|
| `grep` | Microsoft Coreutils grep. |
| `rg PATTERN [PATH]` | Fast recursive text search with ripgrep. |
| `curl` | Native Windows `curl.exe`, not `Invoke-WebRequest`. |
| `wget` | A compatibility wrapper around `curl.exe`; pass curl options. |

Options such as `ls -la` now belong to the native Coreutils command. PowerShell `Get-ChildItem` parameters no longer apply to `ls`.

## Downloads, sync, and virtual mounts

| Command | Purpose |
|---|---|
| `aria2c URL` / `aria URL` | Download with resume and three concurrent segments by default. Later arguments can override those defaults. |
| `rclone-config` | Configure rclone remotes interactively. Credentials are never created by desired state. |
| `rclone-remotes` | List configured rclone remotes. |
| `rclone-mount remote:path R:` | Mount a remote through WinFsp with network-drive semantics and `writes` VFS caching. Run non-elevated so Explorer sees it. |
| `rclone-mounts` | Show mounts started by the profile and whether their process still runs. |
| `rclone-unmount R:` | Stop a profile-managed rclone mount. |
| `rsync ...` | Run Debian WSL's rsync. Use WSL paths such as `/mnt/c/Source`; `wslpath C:\Source` converts paths. |

WinFsp makes rclone's virtual mount available on Windows. Mounts, remote configuration, and credentials are runtime/user state and are not started or generated automatically.

## Code analysis

| Command | Purpose |
|---|---|
| `semgrep-scan [PATH] [-Config auto]` | Run open-source Semgrep CE without login; defaults to the registry's automatic rules. |
| `semgrep scan ...` | Use the full Semgrep CE CLI directly. |
| `codeql ...` | Use the pinned user-local CodeQL CLI. |
| `codeql-tob DATABASE [-Language cpp|go|java] [-Output FILE]` | Analyze a CodeQL database with the installed public Trail of Bits query pack and write SARIF. |

Semgrep is installed by `uv tool` into its own environment. It does not share the AMD/PyTorch Python interpreter. CodeQL and the Trail of Bits packs are installed automatically, but database creation and scans are always explicit.

## Native debugging

| Command | Purpose |
|---|---|
| `windbg` | Open modern WinDbg. |
| `debug-run -Executable TOOL.exe -Breakpoint module!function` | Launch a target, initialize symbols, set one or more unresolved function breakpoints with `bu`, then continue. |
| `dump-on-crash TOOL.exe [-Argument ...]` | Launch under ProcDump and write a full dump on an unhandled exception to `./dumps`. |
| `dump-on-crash -ProcessId PID` | Attach ProcDump to an existing process. |
| `dump-open FILE.dmp` | Open a dump in WinDbg. |
| `ttd-record TOOL.exe [-Argument ...]` | Record a timestamped 2 GiB ring-buffer TTD trace under `./ttd`; elevation is inline. |
| `ttd-record -ProcessId PID` | Attach the TTD recorder to an existing process. |
| `ttd-open FILE.run` | Open a TTD recording in WinDbg. |
| `poolmon` | Run the existing PoolMon launcher with official tag names and automatic elevation. |
| `pooltag TAG` | Look up a pool tag in the installed official database. |

TTD has no first-class two-trace diff. For a before/after comparison, record the same deterministic workload twice, open both traces, and compare stable semantic checkpoints such as call stacks, object fields, allocation counts, return values, and exception positions. Do not diff raw addresses because ASLR and allocation order make them unstable. TTD is most valuable inside each trace: travel backward from the failure to the last write or call that corrupted state. Recording can slow a target substantially and captures process memory, so it is never automatic.

## Processes and handles

| Command | Purpose |
|---|---|
| `ps` | Sysinternals PsList. |
| `pstree` | PsList process tree. |
| `kill PID` / `pkill NAME` | Stop a process with Sysinternals PsKill. |
| `killtree PID` | Stop a process and its descendants. |
| `lsof [SEARCH]` | Display open handles with Sysinternals Handle. |
| `lsof -i:8080` | Display the process and connections associated with port 8080. |

## SSH

| Command | Purpose |
|---|---|
| `ssh-copy-id user@host` | Install the first available `id_ed25519.pub`, `id_ecdsa.pub`, or `id_rsa.pub` on a POSIX SSH target. |
| `ssh-copy-id user@host -i PATH -p 2222` | Select a public key and non-default SSH port. |

The implementation sends only the public key over standard input, creates `~/.ssh` with mode 700, maintains `authorized_keys` at mode 600, and does not duplicate an existing key.

## GitHub

| Command | Purpose |
|---|---|
| `gh auth login` | Authenticate GitHub CLI. |
| `gh repo view --web` | Open the current repository on GitHub. |
| `gh pr status` | Show pull-request status for the current repository. |

GitHub CLI is managed separately from GitHub Desktop through the official WinGet package `GitHub.cli`.

## Ports and services

| Command | Purpose |
|---|---|
| `ports` | Listening TCP ports and bound UDP ports with PID, process, service, and exposure. |
| `daemons` | Compact listener view with Windows service names and managed-firewall classification. |
| `connections` | All TCP connections and UDP endpoints. |
| `port 8080` | Listeners and connections whose local or remote port is 8080. |
| `pidports 1234` | Network endpoints owned by process ID 1234. |

`Exposure=LocalOnly` means loopback (`127.0.0.0/8` or `::1`). `Network` includes wildcard, LAN, Wi-Fi, VPN, and Tailscale addresses. The firewall classification shows `ExternalAllowed` for TCP 8080/8081, `TailscaleTransport` for UDP 41641, and `TailnetOrInternal` for other non-loopback listeners.

## Memory and hardware

| Command | Purpose |
|---|---|
| `btop` / `top` | btop4win with its process pane sorted by RAM. |
| `memtop` | Run btop4win elevated so it can see more system-process data. |
| `memmap` | Open Sysinternals RAMMap for kernel, driver, cache, and standby memory. |
| `mem` | Show physical RAM, Windows commit, commit headroom, pagefile, pools, cache, and WSL usage. |
| `memapps` | Aggregate private and working-set memory across multi-process applications. |
| `memproc` | Show the 30 individual processes with the largest private allocation. |
| `wslmem` | Show Debian memory and Docker container memory. |
| `killapp NAME` | Confirm, then stop every process in an application group. |
| `sensors` | Read temperature, load, power, and fan sensors exposed by Libre/OpenHardwareMonitor. |
| `fanspeed` | Display detected fan speeds. MotionAssistant remains the practical fan controller for the GPD Pocket 4. |

For “what is consuming RAM, including system memory?”, use `memtop` for the live overview and `memmap` for the Windows kernel/cache breakdown.

Use `mem` first when Windows reports low memory. Low `CommitHeadroomGiB` indicates allocation pressure even if some physical RAM remains available. Use `memapps` to identify browsers and Electron applications whose consumption is split across many processes, then `killapp NAME` only after reviewing the group.

## Windows Firewall

| Command | Purpose |
|---|---|
| `firewall-status` | Show status and default actions for all firewall profiles. |
| `enable-firewall` | Enable Domain, Private, and Public profiles while preserving managed rules. |
| `disable-firewall` | Disable all profiles while preserving managed rules. |
| `fw-rules` | Show the managed allow/block rules and port ranges. |
| `fw-on`, `fw-off`, `fw-status` | Compatibility names for the unified commands. |
| `fw-ensure` | Test the declared firewall state and repair it only if drift is found. |
| `fw-reinit` | Always back up the firewall, remove the managed group, and recreate it. |
| `fw-lockdown` | Compatibility name for `fw-ensure`. |
| `fw-unlock` | Remove only this repository's managed rules; Windows rules remain. |

The declared policy applies explicit block rules to physical wired and Wi-Fi interfaces. It allows inbound TCP 8080 and 8081 there, plus UDP 41641 for direct Tailscale transport, and blocks all other inbound TCP/UDP ports. Therefore SSH 22 and RDP 3389 are not exposed through physical networks.

The Tailscale interface is fully allowed, so SSH, RDP, and other services remain available inside the Tailnet subject to the Tailscale access policy. Loopback is unaffected. WSL/Docker services published on loopback are also local-only. Outbound traffic remains allowed. Router/NAT port forwarding still determines whether TCP 8080/8081 are reachable from the public internet.

Use a loopback binding for Docker services that should not be externally exposed:

```yaml
ports:
  - "127.0.0.1:3000:3000"
```

Containers on the same Docker network do not need published ports. To expose a loopback service only to the Tailnet, use `tailscale serve --bg http://127.0.0.1:3000`.

## Microsoft Defender

| Command | Purpose |
|---|---|
| `defender-status` | Show real-time, behavior, script, download, cloud, network, and Tamper Protection state. |
| `defender-settings` | Open Virus & threat protection settings directly. |
| `disable-defender` | Disable those Defender runtime protections through inline `sudo`. No scan is started. |
| `enable-defender` | Restore those Defender runtime protections through inline `sudo`. No scan is started. |

Tamper Protection can reject these settings even for an administrator. `disable-defender` checks it before changing anything and directs you to `defender-settings` when necessary. Windows can also restore real-time protection later; `defender-status` reports the effective state.

## SmartScreen and Mark-of-the-Web

| Command | Purpose |
|---|---|
| `set-smartscreen off` | Disable Explorer executable reputation checks. |
| `set-smartscreen medium` | Enable `Warn` mode with a user override. This is the managed default. |
| `set-smartscreen full` | Enable `Block` mode without a user bypass. |
| `smartscreen-status` | Show the effective mode and policy values. |
| `disable-smartscreen`, `smartscreen-off` | Convenience names for `off`. |
| `enable-smartscreen`, `smartscreen-medium` | Convenience names for `medium`. |
| `smartscreen-full` | Convenience name for `full`. |
| `disable-savezone` | Stop adding Mark-of-the-Web to future downloaded attachments. |
| `enable-savezone` | Restore the Windows default of preserving Mark-of-the-Web. |
| `savezone-status` | Show whether future downloads receive a zone marker. |
| `unblock PATH` | Remove Mark-of-the-Web from selected files. |
| `unblock-downloads [-Path PATH]` | Recursively remove existing zone markers, defaulting to Downloads. |

SmartScreen and SaveZone are intentionally independent. Disabling SaveZone affects future downloads only; `unblock-downloads` handles existing files. Smart App Control is not modified.

## Tailscale and Taildrive

| Command | Purpose |
|---|---|
| `ts-status` | Show Tailscale devices and direct/relay connections. |
| `taildrive` | Show configured Taildrive shares. |
| `tailshare NAME PATH` | Persistently share an existing folder through Taildrive. The share name is lowercased. |
| `tailunshare NAME` | Remove a Taildrive share without deleting its files. |
| `tailscale file cp FILE DEVICE:` | Send a one-off file through Taildrop. |
| `tailscale file get TARGET` | Retrieve received Taildrop files. |

Taildrive is a persistent WebDAV file server inside the Tailnet, locally reachable at `http://100.100.100.100:8080`. Before creating a share, merge the entries from `config/taildrive-policy.hujson` into the existing Tailnet policy. Existing `nodeAttrs` and `grants` must not be replaced.

## Docker in Debian WSL

| Command | Purpose |
|---|---|
| `docker ps` | Run the Debian Docker CLI from PowerShell. WSL starts on demand. |
| `docker compose ...` | Use the installed Docker Compose plugin inside Debian. |
| `docker-compose ...` | Compatibility wrapper for `docker compose`. |
| `wsl --terminate Debian` | Stop Debian and its Docker daemon. A later Docker command starts Debian again. |

The wrappers are defined only when the corresponding native Windows executable is absent. This means Docker Desktop or another Windows Docker CLI can take precedence if installed later. For best filesystem performance, keep container projects in Debian's Linux filesystem rather than under `/mnt/c`.

## Windows event logs

All triage commands accept `-Hours` and `-MaxEvents`, for example `crashes -Hours 168 -MaxEvents 200`.

| Command | Purpose |
|---|---|
| `problems` | Application and System warnings, errors, and critical events. |
| `crashes` | Application crashes, hangs, .NET failures, bugchecks, and unexpected shutdowns. |
| `logins` | Successful/failed logons, explicit credentials, logoffs, and privileged logons. |
| `loginfail` | Failed authentication and credential-validation events. |
| `service-errors` | Service failures, timeouts, unexpected termination, creation, and start-mode changes. |
| `defender-events` | Defender detections, remediation, and protection-setting changes. This does not start a scan. |
| `ps-events` | PowerShell engine, module, and script-block events. |
| `remote-events` | RDP session and OpenSSH operational events. |
| `task-events` | Scheduled-task registration, execution, and failure events. |
| `hardware-events` | WHEA hardware-error events. |
| `audit-events` | Process/service/task creation, audit changes, account changes, and log clearing. |
| `eventlog-status` | Test the managed logging policy and list recent archives. |
| `eventlog-export` | Create an EVTX archive immediately without clearing live logs. |
| `eventlog-start NAME -Executable TOOL.exe` | Create `eventlog-NAME`, enable temporary diagnostic channels, WPR/ETW, and per-tool full dumps. |
| `eventlog-check NAME` | Show events and dump count while the reproduction session remains active. |
| `eventlog-stop NAME` | Save EVTX, CSV/JSON, and `trace.etl`, then restore the previous quiet logging and WER state. |

Run the development commands from the project directory that should receive the output. For example:

```powershell
eventlog-start parser-crash -Executable parser.exe
.\parser.exe .\bad-input.dat
eventlog-check parser-crash
eventlog-stop parser-crash
```

The result is written under `eventlog-parser-crash`: full WER dumps in `dumps`, channel exports plus normalized event rows in `events`, and an ETW first-level-triage trace at `trace.etl`. Keep the capture interval short because full dumps and ETL traces can be large. `eventlog-stop` restores each channel's prior enabled, size, and retention state and restores any previous per-executable WER configuration.

WPR/ETW is the default native tracing path. eBPF for Windows is a separate Microsoft runtime, is not currently installed, and is more useful for purpose-built networking hooks than this general user-mode crash workflow. Packet Monitor remains available in-box when a separate network ETL or PCAPNG capture is needed.

### Packet capture and compact PCAP queries

| Command | Purpose |
|---|---|
| `pcap-start NAME [-Port 22,443]` | Start a 64 MiB circular NIC capture with 256-byte packet snapshots. Optional ports are capture filters. |
| `pcap-debug-start NAME [-Port 22,443]` | Capture at all Windows network-stack components so PktMon can expose internal paths and supported drops. |
| `pcap-stop NAME` | Stop PktMon and retain both `capture.etl` and converted `capture.pcapng` under `pcap-NAME`. |
| `pcap-status` | Show whether PktMon is recording. |
| `pcap-counters` | Show per-component packet and drop counters during capture. |
| `pcap CAPTURE` | Show time, direction, endpoints, protocol, ports, size, and Windows component from a PktMon capture name/directory/ETL. `pcap-read` and `pcap-view` are equivalent. |
| `pcap FILE -Port 443` | Limit the packet list to TCP, UDP, or SCTP port 443. |
| `pcap FILE -Protocol dns` | Apply a simple protocol display filter. |
| `pcap CAPTURE -Failures` | Show explicit PktMon drops plus ICMP/ICMPv6 diagnostic traffic. |
| `pcap-protocols FILE` | Count decoded protocols. |
| `pcap-ports FILE` | Count source and destination port occurrences. |
| `pcap-endpoints FILE` | Count source and destination addresses. |
| `pcap-dns FILE` | Show DNS request/response flows, endpoints, sizes, and direction. Encrypted DNS remains TLS/HTTPS traffic. |
| `pcap-ipv6 FILE` | Show IPv6 and ICMPv6 traffic, including neighbor discovery and path errors. |
| `pcap-firewall FILE` | Read PktMon ETL statistics and list component drop/filter evidence. |

For example:

```powershell
pcap-start web-debug -Port 8080,8081
# reproduce the network failure
pcap-counters
pcap-stop web-debug
pcap web-debug -Failures
pcap-protocols web-debug
pcap-ports web-debug
```

For the usual DNS, IPv6, then filtering investigation:

```powershell
pcap-debug-start path-debug -Port 53,8080,8081
# reproduce the failure
pcap-stop path-debug
pcap-dns path-debug
pcap-ipv6 path-debug
pcap-firewall path-debug
```

PktMon is part of Windows and captures to ETL; the stop command converts it to PCAPNG. The compact query commands format and parse the retained ETL with in-box PktMon, so Wireshark and tshark are not required. Captures are circular, capped at 64 MiB, and retain only the first 256 bytes of each packet; this is enough for network headers and basic protocol diagnosis while limiting disk growth. On this Windows build, PktMon reports a fixed 768 MiB logger memory reservation while either NIC-only or all-component capture is active. Keep captures short and always run `pcap-stop`; the logger releases the reservation when stopped.

The ETL can contain Windows component and packet-drop context that is absent from a conventional wire capture. Use `pcap-debug-start` when Windows filtering is in question; the ordinary `pcap-start` produces a cleaner NIC-only wire view. A drop marker can identify a blocked path, but its absence is not proof that Windows Firewall allowed a flow. PktMon supports one machine-wide capture, and `pcap-start` owns its active filters until `pcap-stop`.

The balanced template enables relevant channels, expands undersized logs, records command lines for process-creation events, and enables PowerShell script-block logging. It intentionally avoids high-volume file-system, registry, handle, packet, and per-connection auditing. Existing additional audit categories are preserved.

Windows event channels do not have a time-based retention property. Live logs therefore use circular overwrite, while a SYSTEM task exports the most recent 48 hours daily. Archives in `E:\Logs` are kept for at most 14 days and also rotated against a 768 MiB budget with 128 MiB reserved free space.

For offline investigation, the recommended templates are:

1. Native aliases for daily operational diagnosis.
2. Hayabusa as the first-choice EVTX timeline and curated detection-rule engine.
3. Chainsaw for custom Sigma hunts and keyword/regex searches.
4. Eric Zimmerman's EvtxECmd when normalized CSV/JSON output and event maps are the priority.

These community tools are not installed automatically because they do not currently have suitable WinGet packages and their rules/maps should be versioned alongside the binaries used for a case.

## Desired-state entry points

| Command | Purpose |
|---|---|
| `.\Apply-Workstation.ps1 -Mode Test` | Report package, profile, sudo, and firewall drift without repairing it. |
| `.\Apply-Workstation.ps1 -Mode Ensure` | Install/update declared packages and repair only drifted local state. |
| `.\Apply-Workstation.ps1 -Mode Reinitialize` | Reapply local state and always recreate the firewall rules with a backup. |
| `sudo COMMAND` | Run a command elevated in the current terminal; Windows sudo is maintained in `normal` inline mode. |

The workstation state also maintains Microsoft Defender path exclusions for `D:\` and `%USERPROFILE%\Source`. Because `D:\` is a whole-volume exclusion, Defender does not scan existing or newly created content anywhere on that volume. The configuration preserves unrelated Defender exclusions.

Scheduled Defender activity runs only while idle, at low priority, with a 15% average CPU target and no catch-up scans. SmartScreen uses warning mode and permits an explicit override. Use `unblock PATH` to remove Mark-of-the-Web from a file you have independently verified. Smart App Control is not modified.

Complete firewall backups are stored under `state/firewall-backups`. Restore one from an elevated shell with:

```powershell
sudo pwsh -NoProfile -File .\scripts\Set-FirewallState.ps1 -Mode Restore -BackupPath .\state\firewall-backups\firewall-before-reinitialize-YYYYMMDD-HHMMSS.wfw
```
