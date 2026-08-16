# PowerShell commands and aliases

The managed profile supports Windows PowerShell 5.1 and PowerShell 7. Some entries are functions or native executables rather than PowerShell `Alias` objects; this document groups them as shell commands.

## Native development commands

The native development toolchain exposes vendor commands directly instead of hiding them behind
aliases: `cl`, `link`, `msbuild`, `cmake`, `ninja`, `rustc`, `cargo`, `java`, and `javac`. A normal
PowerShell 5.1 or Core session receives the same environment from the managed profile.

## Input and prompt

| Key or command | Purpose |
|---|---|
| `Tab` | Open completion and select the next match. |
| `Shift+Tab` | Select the previous completion match. |
| `Up` / `Down` | Search history using the text already entered as a prefix. |
| `Ctrl+R` | Reverse-search command history. |
| Prompt | Shows `username@computer path>`; in Contour it marks each prompt line and makes a filesystem path clickable. |
| `terminal-link URI [TEXT]` | Emit an OSC 8 hyperlink in Contour, falling back to plain text elsewhere or when output is redirected. |
| `workstation-help` / `wshelp` | List managed commands, loaded aliases, and repository skills together. Filter with `-Type Commands|Aliases|Skills`, `-Name PATTERN`, or emit stable data with `-Json`. |
| `caffeine` | Start the real Zhorn Software Caffeine tray utility installed by the focused `Caffeine` WinGet module. It starts active at sign-in; double-click its tray icon to toggle inhibition. |

Contour's built-in bindings use `Ctrl+Alt+K` / `Ctrl+Alt+J` to jump to the previous or next marked prompt, `Ctrl+click` to follow an OSC 8 hyperlink, and `Ctrl+Shift+U` to open hint mode for detected URLs and paths.

See [Sample outputs](sample-outputs.md#managed-aliases) for one use case and invocation for every
managed PowerShell alias loaded on this workstation.

## Workstation updates

| Command | Purpose |
|---|---|
| `update` | Show the complete ordered workstation update plan without invoking an updater. |
| `update -Json` | Emit the same plan as bounded structured data. |
| `update -Target WinGet,Scoop` | Plan only the selected targets and their declared prerequisites. |
| `update -Run` | Explicitly run Windows, package-manager, WSL, Linux, Homebrew, container, and current-release reconciliation stages. |

`update -Run` may install packages, restart Linux services or the developer Docker daemon, and leave
Windows with a pending restart. It displays each Windows administrator or WSL-root boundary first.
It never restarts Windows, shuts down WSL, updates drivers, discovers unrelated distributions,
overrides pins, cleans Scoop versions/caches, or prunes container data. See
[Managed workstation update](workstation-update.md).

## Files and text

Microsoft Coreutils executables take precedence over same-named PowerShell aliases:

`cat`, `cp`, `cut`, `date`, `dir`, `echo`, `env`, `expand`, `factor`, `false`, `head`, `hostname`, `join`, `link`, `ln`, `ls`, `md5sum`, `mkdir`, `mktemp`, `mv`, `nl`, `nproc`, `od`, `paste`, `pathchk`, `printenv`, `printf`, `pwd`, `readlink`, `realpath`, `rm`, `rmdir`, `sha1sum`, `sha256sum`, `sha512sum`, `sleep`, `sort`, `split`, `stat`, `sum`, `tac`, `tail`, `tee`, `test`, `touch`, `tr`, `true`, `truncate`, `uname`, `uniq`, `wc`, `whoami`.

| Command | Purpose |
|---|---|
| `grep` | Microsoft Coreutils grep. |
| `rg PATTERN [PATH]` | Fast recursive text search with ripgrep. |
| `curl` | Native Windows `curl.exe`, not `Invoke-WebRequest`. |

Options such as `ls -la` now belong to the native Coreutils command. PowerShell `Get-ChildItem` parameters no longer apply to `ls`.

## Downloads, sync, and virtual mounts

| Command | Purpose |
|---|---|
| `aria2c URL` / `aria URL` / `wget URL` | Download with resume and three concurrent segments by default. `wget` is a PowerShell alias for the managed `aria2c` wrapper; later arguments can override its defaults. |
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
| `lint-python [PATH...]` | Run the repository-pinned Ruff policy over pyinfra and static-container Python. |
| `go version` / `go env GOPATH GOBIN GOTOOLCHAIN GOROOT` | Inspect the MSI-backed Go runtime and built-in project toolchain selector. |
| `malware_hashes PATH [--json]` | Run the hash-pinned released static hash tool directly; suspicious-case reports are retained and ingested through the case workflow. |

Semgrep is installed by `uv tool` into its own environment. It does not share the AMD/PyTorch Python interpreter. CodeQL and the Trail of Bits packs are installed automatically, but database creation and scans are always explicit.

## Native debugging

| Command | Purpose |
|---|---|
| `windbg` | Open modern WinDbg. |
| `debug-run -Executable TOOL.exe -Breakpoint module!function` | Launch a target, initialize symbols, set one or more unresolved function breakpoints with `bu`, then continue. |
| `dump-on-crash TOOL.exe [-Argument ...]` | Launch under ProcDump and write a full dump on an unhandled exception to `./dumps`. |
| `dump-on-crash -ProcessId PID` | Attach ProcDump to an existing process. |
| `dump-analyze FILE.dmp [-Module NAME] [-NoisySymbols]` | Analyze a dump headlessly with `cdbX64`, CLI symbol downloads, a bounded timeout, and a retained text log. |
| `dump-open FILE.dmp` | Open a dump in WinDbg. |
| `ttd-record TOOL.exe [-Argument ...]` | Record a timestamped 2 GiB ring-buffer TTD trace under `./ttd`; elevation is inline. |
| `ttd-record -ProcessId PID` | Attach the TTD recorder to an existing process. |
| `ttd-open FILE.run` | Open a TTD recording in WinDbg. |
| `poolmon` | Run the existing PoolMon launcher with official tag names and automatic elevation. |
| `pooltag TAG` | Look up a pool tag in the installed official database. |

TTD has no first-class two-trace diff. For a before/after comparison, record the same deterministic workload twice, open both traces, and compare stable semantic checkpoints such as call stacks, object fields, allocation counts, return values, and exception positions. Do not diff raw addresses because ASLR and allocation order make them unstable. TTD is most valuable inside each trace: travel backward from the failure to the last write or call that corrupted state. Recording can slow a target substantially and captures process memory, so it is never automatic.

## Performance profiling

| Command | Purpose |
|---|---|
| `profile-status` | Report WPT/WPA, py-spy, dotnet-trace, Speedscope, and optional AMD uProf state as PowerShell objects. |
| `profile-status -Json` | Emit the same inventory for scripts or AI tools. |
| `profile-native-start NAME` | Start a system-wide sampled CPU trace with WPR's `CPU` profile and file-mode buffering. Elevation is inline. |
| `profile-native-stop NAME` | Stop the named WPR instance and save `profile-native-NAME/cpu.etl`. |
| `profile-native-cancel NAME` | Cancel a named capture without retaining an ETL. |
| `profile-native-record NAME [-Seconds 15]` | Run a bounded native CPU capture and stop it automatically. This is the normal capture command. |
| `profile-native-open NAME` | Open the retained ETL in Windows Performance Analyzer. |
| `profile-native Status [NAME]` | List retained native sessions or inspect one session's JSON-backed state. |
| `profile-python -ProcessId PID [-Seconds 30] [-Rate 100] [-Open]` | Attach py-spy and create a standalone interactive SVG flame graph. |
| `profile-python -Executable python.exe -Argument script.py` | Launch and profile a Python workload without modifying its environment. |
| `profile-dotnet-ps` | List traceable .NET processes. |
| `profile-dotnet -ProcessId PID [-Seconds 30] [-Open]` | Record sampled managed stacks, retain the original `.nettrace`, and create Speedscope JSON. |
| `profile-dotnet -Executable TOOL.exe -Argument ...` | Launch and trace a .NET workload from startup. |
| `profile-view FILE` | Open ETL in WPA, SVG in the browser, Speedscope JSON in the local Speedscope viewer, or convert `.nettrace` before opening it. |
| `wpa FILE.etl` | Open an ETL directly in WPA. |
| `speedscope FILE.speedscope.json` | Open a profile in the locally installed Speedscope CLI/browser viewer. |
| `uprof` / `uprof-cli` | Open AMD uProf after its explicit installation. |
| `uprof-install` | Open AMD's official EULA-gated uProf download page. |

Use WPR and WPA for compiled programs, drivers, kernel activity, cross-process CPU work, and system-wide investigation. In WPA, select the sampled CPU data and its flame visualization, then group or filter by process and stack. Keep the ETL because WPA can revisit it with different tables, symbols, and views.

WPR CPU captures are system-wide and can produce roughly tens of MiB per second before compression on a busy machine. Prefer `profile-native-record` with a short interval. Stopping and compressing the ETL can take substantially longer than the recording interval.

Use py-spy for Python-first CPU questions. It is installed in an isolated uv tool environment and does not alter the AMD/PyTorch interpreter being observed. Its SVG result is self-contained and remains local.

Use dotnet-trace for managed stacks. The `.nettrace` is the complete retained source artifact; the `.speedscope.json` file is the visualization derivative. Speedscope runs from the locally installed package and serves the selected profile to the local browser rather than requiring a trace upload.

AMD uProf 5.3 is optional and useful when AMD PMU events, IBS, power, memory bandwidth, or other hardware counters are required. Desired state does not silently accept AMD's EULA, so it reports uProf separately and does not fail workstation compliance when uProf is absent.

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
| `ssh HOST` | Use the native Windows OpenSSH client and canonical `%USERPROFILE%\.ssh\config`. |
| `wsl-dev ssh HOST` | Use Debian's native OpenSSH client with the same canonical configuration. |
| `wsl-nix ssh HOST` | Use NixOS's store-backed OpenSSH client with the same canonical configuration. |
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

`Exposure=LocalOnly` means loopback (`127.0.0.0/8` or `::1`). `Network` includes wildcard, LAN, Wi-Fi, VPN, and Tailscale addresses. The firewall classification shows `ExternalAllowed` for TCP 22/3389/8080/8081, `TailscaleTransport` for UDP 41641, and `TailnetOrInternal` for other non-loopback listeners.

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
| `fanspeed` | Display fan speeds exposed by a supported hardware-monitor provider. It does not install or control a vendor-specific fan service. |

To find what is consuming RAM, including system memory, use `memtop` for the live overview and
`memmap` for the Windows kernel/cache breakdown.

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

The declared policy applies explicit block rules to physical wired and Wi-Fi interfaces. It allows inbound TCP 22 for SSH, 3389 for RDP, and 8080/8081 for HTTP/application services, plus UDP 41641 for direct Tailscale transport. All other inbound TCP/UDP ports on physical interfaces are blocked.

The Tailscale interface is fully allowed, so SSH, RDP, and other services remain available inside the
Tailnet subject to its access policy. Loopback is unaffected. WSL/Docker services published on
loopback remain local. Outbound traffic is allowed. Router or NAT port forwarding determines whether
the physically allowed ports 22, 3389, 8080, and 8081 are reachable from the public internet.

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

SmartScreen and SaveZone are independent controls. Disabling SaveZone affects future downloads only;
`unblock-downloads` handles existing files. Smart App Control is not modified.

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

## Container engines in Debian WSL

| Command | Purpose |
|---|---|
| `docker ps` | Run the Debian Docker CLI from PowerShell. WSL starts on demand. |
| `docker compose ...` | Use the installed Docker Compose plugin inside Debian. |
| `docker-compose ...` | Compatibility wrapper for `docker compose`. |
| `wsl-mw podman info --format json` | Inspect local rootless Podman in `Debian-MW`. |
| `wsl --terminate Debian` | Stop Debian and its Docker daemon. A later Docker command starts Debian again. |

The ordinary Docker wrappers are defined only when the corresponding native Windows executable is absent. This means Docker Desktop or another Windows Docker CLI can take precedence if installed later. Direct malware-runtime diagnosis uses the generic `wsl-mw` boundary and its dedicated distro/user from `.wsl-env`; there is no runtime-specific malware alias or Compose wrapper.

`Debian` currently runs the pyinfra-managed engine required by Dagger. `Debian-MW` is a clean, separately managed distro with daemonless rootless Podman and user-scoped storage beneath `/home/mc/.local/share/containers`. Its Podman API socket remains disabled. Do not use `Debian` for untrusted analysis, and do not add Dagger to `Debian-MW`. For best filesystem performance, keep ordinary container projects in Debian's Linux filesystem rather than under `/mnt/c`.

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

The balanced template enables relevant channels, expands undersized logs, records command lines for
process-creation events, and enables PowerShell script-block logging. It avoids high-volume
file-system, registry, handle, packet, and per-connection auditing. Existing additional audit
categories are preserved.

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
| `.\Apply-Workstation.ps1 -Mode Test` | Report package, Windows feature, profile, sudo, and firewall drift without repairing it. |
| `.\Apply-Workstation.ps1 -Mode Ensure` | Install/update declared packages and Windows features, then repair only drifted local state without restarting Windows. |
| `.\Apply-Workstation.ps1 -Mode Reinitialize` | Reapply local state and always recreate the firewall rules with a backup. |
| `.\Apply-Workstation.ps1 -Mode Test -Module MODULE` | Test only one module plus its declared dependencies. |
| `.\Apply-Workstation.ps1 -Mode Ensure -Module MODULE` | Ensure only one module plus its declared dependencies. |
| `.\Apply-Workstation.ps1 -Mode Test -Module MODULE -Plan [-Json]` | Validate and display the resolved dependency order without invoking resources. |
| `.\Apply-Workstation.ps1 -Mode Test -Module MODULE1,MODULE2` | Test several named modules in topological dependency order. |
| `pwsh -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test` | Test the pinned Spec Kit EARS/TDD tool without changing state. |
| `.\Apply-Workstation.ps1 -Mode Ensure -Module SpecDrivenDevelopment` | Install the hash-verified release wheel after the managed `uv` dependency. |
| `ears-sdd init --project . --integration codex` | Explicitly adopt the EARS/TDD Spec Kit components in the current project. |
| `.\ears-sdd.ps1 validate --phase spec` | Validate human-readable EARS requirements; use `--json` for agents. |
| `pwsh -NoProfile -File .\scripts\Set-ScoopState.ps1 -Mode Test` | Verify Scoop prerequisites and official Main/Extras bucket sources. |
| `pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test` | Verify the official Contour MSI, absence of the legacy Scoop package, native Desktop shortcut, managed BlueTerm config, and bounded graphics gate. |
| `.\Apply-Workstation.ps1 -Mode Ensure -Module ContourTerminal` | Ensure Sudo, the hash-pinned machine-wide Contour MSI, and the translated theme in dependency order. |
| `pwsh -NoProfile -File .\scripts\Set-WindowsTerminalState.ps1 -Mode Test` | Inspect the PowerShell Core default, retained Windows PowerShell profile, and shared Terminal appearance without changing settings or installing a package. |
| `.\Apply-Workstation.ps1 -Mode Ensure -Module WindowsTerminal` | Ensure the stable Terminal package, back up drifted settings, and merge only the declared PowerShell defaults. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-WorkstationBaseline.ps1 -Section PowerShellRuntimes` | Smoke-test the managed profile in both Windows PowerShell 5.1 and the newest installed PowerShell Core. |
| `powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan` | Validate dependencies and show the Windows feature installation order without elevation. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test` | Report Hyper-V and Windows Sandbox state without changing it. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Ensure` | Enable missing declared Windows features without restarting Windows. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan` | Show the `DeveloperBaseline` controls without elevation or state changes. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Test` | Compare the hardening profile with registry, SMB, feature, and adapter state. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Ensure` | Repair only drifted hardening controls without restarting Windows. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Plan` | Show the opt-in `DeveloperMinimal` removal allowlist without elevation. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Test` | Inventory exact matching installed/provisioned apps, capabilities, and features without removal. |
| `sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Ensure -ConfirmRemoval` | Explicitly remove the reviewed targets after writing a pre-removal snapshot. |
| `.\Apply-Workstation.ps1 -Mode Ensure -Module Debloat -ConfirmRemoval` | Run the same opt-in debloat profile through the general module orchestrator. |
| `sudo COMMAND` | Run a command elevated in the current terminal; Windows sudo is maintained in `normal` inline mode. |

The workstation state reads Microsoft Defender paths from the ignored `.excluded` file. Start from `.excluded.sample`; native Windows `%ENVIRONMENT_VARIABLE%` references expand before paths are validated. The public repository therefore contains no machine-specific exclusion list, and unrelated Defender exclusions are preserved.

Scheduled Defender activity runs only while idle, at low priority, with a 15% average CPU target and no catch-up scans. SmartScreen uses warning mode and permits an explicit override. Use `unblock PATH` to remove Mark-of-the-Web from a file you have independently verified. Smart App Control is not modified.

Complete firewall backups are stored under `state/firewall-backups`. Restore one from an elevated shell with:

```powershell
sudo pwsh -NoProfile -File .\scripts\Set-FirewallState.ps1 -Mode Restore -BackupPath .\state\firewall-backups\firewall-before-reinitialize-YYYYMMDD-HHMMSS.wfw
```
## Tricky cases and documentation

| Command | Purpose |
|---|---|
| `tricky new NAME -Problem '...' [-Target '...']` | Create an evidence-first investigation case. |
| `tricky add NAME -Path PATH [-Copy]` | Reference existing evidence, or copy it into the case. |
| `tricky inspect NAME [-Hash] [-Json\|-AsObject]` | Inventory evidence and route explicit evidence gaps. |
| `tricky report NAME [-Hash] [-Open]` | Write Markdown, JSON, and standalone visual HTML reports. |
| `tricky list` | List cases under the current directory. |
| `tricky capabilities [-Json]` | Show the machine-readable capability catalog. |
| `docs-serve` | Serve the locked MkDocs site locally. |
| `docs-build` | Build the MkDocs site in strict mode. |

## Skill optimization

| Command | Purpose |
|---|---|
| `skillopt-status` | Show SkillOpt state and the latest staged proposal. |
| `skillopt-harvest SKILL` | Create a local, unapproved task draft from project Codex sessions. |
| `skillopt-review SKILL -TasksFile PATH` | Inspect task metadata and the checkable task list. |
| `skillopt-approve-tasks SKILL -TasksFile PATH -ConfirmReview` | Mark a fully inspected/redacted task file as reviewed. |
| `skillopt-dry-run SKILL -TasksFile PATH` | Run the deterministic mock gate without staging or provider calls. |
| `skillopt-run SKILL -TasksFile PATH -Backend Codex -AllowProviderCalls` | Run a real gated optimization and stage accepted edits. |
| `skillopt-review SKILL -Staging PATH` | Read a staged report and artifact inventory. |
| `skillopt-adopt SKILL -Staging PATH -ConfirmAdoption` | Explicitly adopt one reviewed staged proposal, then validate skills. |
| `skills-validate` | Validate all repository skills without optimizing them. |

Desired state installs `skillopt==0.2.0` through `uv tool`. It never harvests transcripts, contacts a provider, schedules runs, or adopts edits automatically.

## Repository quality

| Command | Purpose |
|---|---|
| `lint-powershell [PATH ...]` | Run PSScriptAnalyzer 1.25.0 on selected files, or all tracked PowerShell files when no paths are supplied. |
| `lint-python [PATH ...]` | Run the pinned Ruff policy over Python deploy, parser, and test code. |
| `lint-repository [-Category All\|Docker\|Actions] [PATH ...]` | Run the native repository linters; the default checks Dockerfiles with Hadolint and workflows with actionlint. |
| `lint-docker [DOCKERFILE ...]` | Run Hadolint over selected Dockerfiles, or every tracked Dockerfile. |
| `lint-actions [WORKFLOW ...]` | Run actionlint over selected GitHub Actions workflows, or every tracked workflow. |
| `test-powershell [-Path PATH] [-ThrottleLimit N]` | Run standard PowerShell test files through pinned Pester with bounded file-level parallelism when supported. |
| `test-powershell -Compatibility` | Run the compatible test suite sequentially through inbox Windows PowerShell 5.1. |
| `test-powershell -Json` | Return the bounded aggregate test result for machine consumption. |
| `precommit-install` | Explicitly install pinned pre-commit/PSScriptAnalyzer plus native Hadolint/actionlint dependencies, validate the configuration, and install `.git/hooks/pre-commit`. |
| `precommit-run` | Execute every configured non-mutating pre-commit check against all tracked files. |

Ordinary commits check only matching staged files. PowerShell and Python use the same repository
wrappers as `lint-powershell` and `lint-python`. Dockerfiles and workflows share `lint-repository`.
Documentation changes run the strict MkDocs build. Portable upstream hooks parse YAML, including
`.winget` declarations; JSON, including Spec Kit `.registry` files; and TOML. They also reject merge
markers, case conflicts, oversized additions, private keys, and mixed line endings.

`mixed-line-ending` runs with `--fix=no`. Generated `.agents/` and `.specify/` metadata retain their
upstream line endings and are excluded from that check. No configured hook silently rewrites a
staged file. Run one portable check directly with `pre-commit run check-yaml --all-files`. Hook
installation is per clone because `.git/hooks` and tool installations are local state.
## Suspicious-file commands

These commands plan potentially dangerous work before they run it. `-Json` provides the machine-readable form.

| Command | Behavior |
|---|---|
| `is-this-malware <path>` | bounded hash, signature, entropy, strings, PE, and indicator inspection without host execution |
| `malware-sandbox <path> -Mode Dissect` | create a reviewable document-dissection Sandbox job |
| `disass <path>` | create a reviewable Rizin/text/SQLite Sandbox job |
| `decomp <path>` | create a reviewable best-effort Ghidra Sandbox job |
| `malware-sandbox <path> -Mode Detonate` | create a reviewable execution plan without launching it |
| `malware-control <path> -Mode <mode>` | create the clean-control half of a matched Sandbox comparison without touching the target |
| `malware-diff -ControlCase <case> -TargetCase <case>` | retain canonical evidence directories and display a native Git standard unified diff |
| `malware-container-status` | verify that the dedicated Debian-MW engine is rootless and arguments are policy-compatible |
| `malware-container-image -Mode Test` | inspect the reviewed local static-parser image and inventory fingerprint |
| `malware-container <path>` | plan inert rootless static parsing without starting a container |
| `malware-container <path> -Run -ConfirmContainer` | explicitly run inert static parsing with networking disabled |
| `malware-container-control <path>` | plan the clean control for a matched static-container comparison |
| `host-static <path>` | explicit alias for bounded host byte inspection (`is-this-malware`) |
| `sandbox-static <path> -Mode Dissect` | explicit alias for Windows Sandbox planning (`malware-sandbox`) |
| `sandbox-behavior-control <path>` | plan a clean Windows Sandbox behavior baseline without reading or executing the target |
| `sandbox-behavior-target <path>` | plan the target half of a general Windows Sandbox behavior comparison |
| `sandbox-behavior-diff -ControlCase <case> -TargetCase <case>` | compare completed compatible behavior cases through the bounded standard-diff path |
| `binary-diff <baseline> <candidate>` | plan a graph-based Ghidra/BinExport/BinDiff comparison in the rootless static container |
| `binary-diff <baseline> <candidate> -Run -ConfirmContainer` | explicitly run non-executing graph parsers with two read-only inputs and networking disabled |
| `binary-diff-report <case>` | show the bounded validated summary for an existing binary-diff case |

Add `-Run -ConfirmSandbox` only after reviewing `analysis.wsb`. Detonation also requires
`-ConfirmExecution`. `-AllowNetwork` is separate because it exposes networks reachable from the
host. Documents never open automatically. Sandbox jobs close the guest after writing the terminal
result; add `-KeepSandboxOpen` only when you need an interactive guest.

For a differential run, plan `malware-control` and `malware-sandbox` with the same path, mode,
duration, and network policy. Review and approve each Sandbox launch separately; the target
`Detonate` job still requires `-ConfirmExecution`. Compare only completed compatible cases.
`malware-diff` uses native Windows `git diff --no-index --no-ext-diff --text`; it does not use Git
Bash, MSYS, Cygwin, or BusyBox. Raw trace/parser/decompiler output is never parsed by PowerShell:
the bounded Python boundary canonicalizes only known schemas and records other files by path, size,
and SHA-256. Default output gives the diff path; `-ShowDiff` prints only escaped canonical content.
The canonical directories remain available for another ordinary directory-diff program.

`binary-diff` retains `baseline.BinExport`, `candidate.BinExport`, and the canonical read-only
`baseline_vs_candidate.BinDiff` SQLite result. `binary-analysis.sqlite` is a separate query sidecar
for functions, instructions, blocks, edges, calls, best-effort decompilation, and a bounded match
projection. Raw bytes, file versions, assembly text, and decompiler text never replace graph
matching. See [Analysis and differencing cases](analysis-differencing.md) for artifact roles and SQL.

## Execution-boundary and WSL commands

| Command | Boundary |
|---|---|
| `host-static <path>` | Windows host; bounded inert byte inspection only |
| `sandbox-static <path> ...` | Windows Sandbox; complex parsing or explicitly approved execution |
| `wsl-dev [command]` | configured developer distribution and user (`WSL_DISTRIBUTION`, `WSL_USER`) |
| `wsl-mw [command]` | configured dedicated malware-analysis distribution and user (`WSL_MALWARE_DISTRIBUTION`, `WSL_MALWARE_USER`) |
| `wsl-nix [command]` | configured reproducible NixOS distribution and user (`WSL_NIXOS_DISTRIBUTION`, `WSL_NIXOS_USER`) |
| `nixos-check [-Json]` | read-only generation, source, command-provenance, and full Nix-store integrity check |

Windows Sandbox is not a WSL distribution. `wsl-dev` is the ordinary Debian development boundary
and must never receive suspicious samples. `wsl-mw` reaches the separate rootless analysis distro;
`wsl-nix` reaches the locked Kubernetes/IaC tool environment. The shared SSH module excludes `wsl-mw`.
it does not make arbitrary containers safe. Both commands read ignored `.wsl-env`, refuse a missing
selection, and refuse to use the same distribution for developer and malware state. With no
arguments they open the selected distribution; with arguments they execute that command directly.

`docker`, `docker-compose`, `rsync`, and `wslpath` use `wsl-dev`. Direct Podman diagnosis uses
`wsl-mw podman ...`; malware analysis itself uses the policy-gated `malware-container` commands.
