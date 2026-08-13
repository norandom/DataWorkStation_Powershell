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
| `fw-status` | Show status and default actions for all firewall profiles. |
| `fw-rules` | Show the managed allow/block rules and port ranges. |
| `fw-on` | Enable Domain, Private, and Public firewall profiles through inline `sudo`. |
| `fw-off` | Disable every firewall profile. This leaves the machine unprotected on attached networks. |
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
