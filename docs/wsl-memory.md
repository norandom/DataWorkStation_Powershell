# WSL memory, zram and earlyoom

The workstation gives WSL a 6 GiB RAM ceiling and 6 GiB disk swap. Inside trusted Debian, a 2 GiB zram swap device compresses cold pages in RAM, and earlyoom provides emergency process termination when both available memory and free swap become scarce. These controls complement the [Windows reclaim-before-kill guard](windows-memory-reclamation.md).

## Inspect the current state

From PowerShell, check the declared host configuration:

```powershell
pwsh -NoProfile -File .\scripts\Set-WslState.ps1 -Mode Test
```

Inside trusted Debian, from the repository directory:

```sh
sh linux/zram.sh Test
sh linux/earlyoom.sh Test
free -h
swapon --show
zramctl --output NAME,ALGORITHM,DISKSIZE,DATA,COMPR,TOTAL
cat /proc/pressure/memory
journalctl -u earlyoom -n 30 --no-pager
```

These commands inspect configuration, counters and existing logs. They do not trigger cleanup or terminate workloads. The host Test compares the file; it does not prove that a running VM has adopted it.

## Where the memory goes

| Layer | Repository setting | What it controls |
| --- | --- | --- |
| WSL VM | `memory=6GB` | Guest RAM ceiling, shared across WSL 2 distributions |
| WSL disk swap | `swap=6GB` | Disk-backed guest swap capacity |
| Host reclamation | `autoMemoryReclaim=gradual` | Gradual return of eligible cached guest memory to Windows |
| Debian zram | 2 GiB, `lzo-rle`, priority 100 | Logical compressed swap capacity, stored within guest RAM |
| Debian earlyoom | `-m 10,5 -s 50,25` | Emergency termination thresholds |

The first three settings come from `config/wslconfig.ini`, copied to `%USERPROFILE%\.wslconfig`. Microsoft documents `.wslconfig` as global WSL 2 VM configuration; it takes effect after the subsystem fully stops and restarts. It is not a separate 6 GiB allocation for each distro. See [Microsoft's WSL configuration reference](https://learn.microsoft.com/en-us/windows/wsl/wsl-config).

The resulting swap total is approximately 8 GiB: 6 GiB on disk plus 2 GiB of logical zram slots. This does **not** provide 14 GiB of physical RAM. Zram's compressed payload and allocator overhead consume part of the same 6 GiB guest RAM budget.

## Why compressed swap can help

When Linux swaps a page to zram, zram compresses its contents and retains the compressed representation in RAM. A later access requires decompression. If a group of cold pages compresses well, retaining it uses less RAM than keeping the original pages resident. Compression spends CPU time to reduce memory demand; incompressible data offers little benefit. The kernel exposes logical size, original data size, compressed payload size and actual allocation separately. See the [kernel zram documentation](https://docs.kernel.org/admin-guide/blockdev/zram.html).

```text
Guest application pages
    | Linux chooses pages for swap
    +--> /dev/zram0: compressed bytes in guest RAM, priority 100
    +--> WSL disk swap: bytes on disk, observed priority -2

Windows sees the backing memory of the WSL VM.
```

Higher swap priority favors zram for new swap placement. This repository configures no zram backing device or writeback policy: disk swap is a separate destination, not an automatic overflow file for pages already held in zram. See Linux's [swapon priority rules](https://man7.org/linux/man-pages/man2/swapon.2.html).

The local snapshot on 2026-10-25 showed a 2 GiB zram device with about 2.8 MiB original data, 764.8 KiB compressed payload and 2.5 MiB total allocation. The payload alone would overstate the saving. At this tiny occupancy, allocator overhead matters; this snapshot cannot predict compression under a real workload.

Zram is a compressed block device. Zswap is a different design, a compressed cache in front of swap; this repository's installer refuses to add zram when it detects enabled zswap. See the [kernel zswap description](https://docs.kernel.org/admin-guide/mm/zswap.html). Neither setting invokes `MemoryOptimize --now`: Windows working-set trimming and guest-page compression act at different layers.

## How earlyoom decides to terminate

`config/earlyoom.default` supplies:

```text
-m 10,5 -s 50,25 -r 60 --avoid '^(systemd|init|dockerd|containerd|containerd-shim|sshd)$'
```

Earlyoom sends SIGTERM when available memory is below 10% **and** free swap is below 50%; the corresponding emergency SIGKILL thresholds are 5% and 25%. Version 1.8 uses `MemAvailable + AnonPages` as its user-memory denominator. With approximately 8 GiB total swap, the swap thresholds correspond to about 4 GiB and 2 GiB free. They refer to logical swap accounting, not zram's compressed byte count.

`--avoid` biases victim selection; it does not make matching processes immune. Matching uses the kernel process name, limited to 15 visible characters, so long names require particular care. `-r 60` requests periodic memory reports. See the [upstream earlyoom manual](https://github.com/rfjakob/earlyoom/blob/master/MANPAGE.md).

This Linux daemon is independent of our Windows earlyoom port. The Windows guard attempts headless WinMemoryCleaner reclamation at most once per configured interval before its termination fallback. Debian instead relies on normal Linux reclaim and swap before earlyoom's thresholds are crossed; it does not call the Windows alias.

## Apply the declared policy explicitly

In PowerShell:

```powershell
pwsh -NoProfile -File .\scripts\Set-WslState.ps1 -Mode Ensure
```

This backs up and updates `.wslconfig` when needed. Save work and stop WSL workloads before using `wsl --shutdown` to apply changed VM settings: that command stops all running distributions. No shutdown is performed by the configuration script.

Inside trusted Debian, from the repository directory:

```sh
sudo sh linux/zram.sh Ensure
sudo sh linux/earlyoom.sh Ensure
```

These are state-changing operations. The zram installer checks kernel/tool availability, backs up replaced files, installs `config/workstation-zram.service` and `linux/start-zram.sh`, then enables the service. The helper initializes `/dev/zram0` with `lzo-rle`, 2 GiB logical size and priority 100. An active device with configuration drift is refused; the scripts do not reset it or run `swapoff` to force compliance.

The earlyoom installer writes the declared policy, installs the Debian package if absent, and enables/restarts its service. This enables automatic process termination under pressure. These scripts target trusted Debian, not the malware-analysis distro. The locally verified kernel was `6.18.33.2-microsoft-standard-WSL2`; other kernels must provide zram support.

## Decide whether it improves your workload

Compare the same workload and concurrency using elapsed time, responsiveness, memory-pressure stall counters and swap I/O. Read `vmstat 1` alongside the counters above and the existing earlyoom journal. A larger compressed-data count alone is not evidence of faster work. Useful outcomes are fewer stalls, less disk swap traffic or completion without an emergency kill; rising CPU cost or repeated swap-in churn can outweigh the savings.

For host-side evidence and recovery commands, continue with the [memory-pressure workflow](workflows/memory-pressure.md). For the broader desired-state contract, see [Choose desired state](desired-state.md).
