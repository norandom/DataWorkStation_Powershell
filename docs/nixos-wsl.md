# Reproducible NixOS WSL tools

The `NixOsWsl` module provides Helm, kubectl, Pulumi, Git, jq, and OpenSSH in a locked NixOS system generation. It is the reproducible Kubernetes and infrastructure-as-code environment. Ordinary Debian remains the Homebrew, pyinfra, Docker, and Dagger environment. `Debian-MW` remains isolated for untrusted analysis and receives neither these tools nor shared SSH state.

## Environment boundaries

| Environment | Intended work | Package/state owner | SSH client |
|---|---|---|---|
| Windows | Workstation orchestration and Windows tools | WinGet, Scoop, focused PowerShell resources | Windows OpenSSH |
| Debian | pyinfra, Homebrew, Docker, and Dagger development | APT, Homebrew, pyinfra | Debian OpenSSH |
| NixOS | Helm, kubectl, Pulumi, and reproducible infrastructure tooling | Locked Nix flake | Nix store OpenSSH |
| Debian-MW | Rootless untrusted static-analysis containers | APT and pyinfra-managed Podman | No shared SSH state |

The PowerShell prefixes make the boundary visible: `wsl-dev`, `wsl-nix`, and `wsl-mw`. None of them changes the Windows default WSL distribution.

## Local selection and prerequisites

Copy the tracked selector once and review all three boundaries:

```powershell
Copy-Item .wsl-env.sample .wsl-env
Get-Content .wsl-env
```

The NixOS entries are:

```text
WSL_NIXOS_DISTRIBUTION=NixOS
WSL_NIXOS_USER=your-linux-user
```

The resource requires Windows 11 Pro, WSL 2, PowerShell 7 after the normal bootstrap stage, and distinct names for Debian, Debian-MW, and NixOS. It refuses an existing distribution with the selected name when that distribution is not NixOS.

## Read the plan first

```powershell
pwsh -NoProfile -File .\scripts\Set-NixOsWslState.ps1 -Mode Plan
.\Apply-Workstation.ps1 -Mode Test -Module NixOsWsl,SharedSshConfig -Plan
```

The initial install downloads the release-pinned NixOS-WSL image declared in `config/nixos-wsl.psd1`, verifies its SHA-256, and creates only the selected `NixOS` distribution. It does not replace a distribution, change the Windows default distribution, unregister WSL state, or restart Windows.

The plan exposes the download size, network requirement, install location, selected user, package set, distribution restart, and the fact that unregistering is never allowed.

Apply the reviewed plan explicitly:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module NixOsWsl,SharedSshConfig
```

`Ensure` deploys the locked flake, builds a boot generation, and restarts only the NixOS distribution. A compliant environment is not rebuilt or restarted. The operating system and most tools follow stable NixOS. Pulumi comes from a separately locked current Nixpkgs input because the stable branch lags far enough for the CLI to warn; it remains the source-derived CLI-only package. Cloud provider plugins are not bundled into the workstation generation.

The first Ensure performs these operations in order:

1. validate the local selector and locked source files;
2. download and hash-check the pinned NixOS-WSL image when the distribution is absent;
3. install the distribution at `%LOCALAPPDATA%\WSL\NixOS` without launching an interactive setup;
4. deploy the reviewed flake and generated local username to `/etc/nixos`;
5. build a boot generation from `flake.lock`;
6. terminate and restart only NixOS to activate it;
7. verify the selected default user and run the complete integrity check.

If the build fails, the previous active generation remains available. The resource does not unregister the distribution or delete its VHD as a recovery shortcut.

## Daily commands

```powershell
# Read-only state and integrity
nixos-check
nixos-check -Json

# Tool versions
wsl-nix helm version --short
wsl-nix kubectl version --client
wsl-nix pulumi version

# Run a command without entering an interactive shell
wsl-nix kubectl config current-context

# Enter the selected NixOS user shell
wsl-nix
```

Keep Kubernetes configuration, Pulumi projects, and credentials out of the Nix store. They belong to the selected user's mutable home or an explicitly mounted project directory.

## Verify drift and alteration

Use the same check directly from Windows or inside NixOS:

```powershell
nixos-check
nixos-check -Json
wsl-nix workstation-self-check
wsl-nix workstation-self-check --json
```

The result separates two failure classes:

| Status | Meaning |
|---|---|
| `compliant` | The active generation equals the locked target, deployed sources match, managed commands come from `/nix/store`, and store contents verify. |
| `drifted` | The repository/deployed source or evaluated target differs from the active generation, or the flake cannot be evaluated. |
| `altered` | `nix store verify --all --no-trust` finds changed store content, or a managed command resolves outside `/nix/store`. |

Nix can content-verify the entire local Nix store, not only the current package list. The active `/run/current-system` store path also acts as the identity of the system generation. Mutable data is deliberately outside that model: `/home`, `/var`, Windows mounts, credentials, caches, and runtime state are not part of a NixOS system closure. The self-check therefore also verifies a separately embedded SHA-256 manifest for `/etc/nixos`. It does not claim that user data or runtime files are immutable.

The self-check is read-only. It uses `nix eval`, never `nix build`, and does not repair a failed verification.

See [NixOS integrity and alteration detection](nixos-integrity.md) for the verified layers, exit-code contract, threat-model limits, failure response, and the exact meaning of whole-distribution hashing.

## One SSH client configuration, native clients

`SharedSshConfig` uses `%USERPROFILE%\.ssh\config` as the canonical client configuration. Trusted Debian and NixOS `~/.ssh/config` paths are symlinks to that file. Each environment still uses its native client:

| Context | Default client |
|---|---|
| Windows PowerShell | Windows `ssh.exe` |
| ordinary Debian via `wsl-dev` | Debian `/usr/bin/ssh` |
| NixOS via `wsl-nix` | Nix store OpenSSH |
| Debian-MW | excluded; no shared config |

The resource creates a comment-only canonical file when none exists. Through NixOS's metadata-aware Windows mount it records mode 0600 for OpenSSH, then verifies that both Linux clients observe that mode. It refuses to replace an existing regular `~/.ssh/config` in either trusted Linux distribution, so reconcile that file manually before Ensure. It validates the canonical syntax with all three native clients. Private keys are not copied or managed; use explicit `IdentityFile` paths that are readable in every context where a host entry is used.

Portable host options such as `HostName`, `User`, `Port`, `ProxyJump`, and `ForwardAgent` work well in the canonical file. Be careful with OS-specific absolute `IdentityFile` and `Include` paths: Windows and Linux interpret them differently. `IdentityFile ~/.ssh/id_ed25519` is portable syntax, but it refers to a separate key in each environment's home. The module deliberately does not copy private keys into WSL.

If a Windows editor replaces the canonical file and loses its DrvFS mode metadata, `Test` reports drift. A focused `SharedSshConfig` Ensure reapplies mode 0600 and validates every native client.

Examples:

```powershell
ssh server.example                 # Windows client
wsl-dev ssh server.example         # Debian client
wsl-nix ssh server.example         # NixOS client
wsl-nix helm version
wsl-nix kubectl version --client
wsl-nix pulumi version
```

No profile alias replaces `ssh`, `helm`, `kubectl`, or `pulumi` on Windows. The `wsl-nix` prefix makes the execution boundary visible.

### Concurrent systemd distributions

[WSL distributions share one kernel and some kernel-global state](https://github.com/microsoft/WSL/discussions/8869). On current WSL builds, a running rootless Podman user manager in Debian-MW can cause NixOS startup to print `Failed to start the systemd user session` for the same Linux UID; related [rootless Podman and user-session failures are tracked by WSL](https://github.com/microsoft/WSL/issues/13053). The NixOS CLI and system generation remain usable; confirm their declared state with `nixos-check`. The workstation resource does not stop Debian-MW, kill its Podman pause process, or run the VM-wide `wsl --shutdown` to hide this warning. Those actions could interrupt analysis work and remain explicit operator choices.

## Updating the locked environment

Ordinary workstation reconciliation never rewrites `flake.lock`. The normal `update -Run` command reapplies the current lock; it does not adopt newer Nix inputs.

Update the lock as a reviewed source change:

```powershell
wsl-nix
cd /mnt/c/Users/<windows-user>/Source/PowerShell/nixos
nix flake update
exit

git diff -- nixos/flake.lock
.\Apply-Workstation.ps1 -Mode Test -Module NixOsWsl -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module NixOsWsl
nixos-check
```

The flake intentionally has two Nixpkgs inputs. Stable Nixpkgs owns NixOS, Helm, kubectl, Git, jq, and OpenSSH. The separately locked unstable input supplies only the Pulumi CLI. Review both revisions in `flake.lock`; do not replace `pulumi` with `pulumi-bin`, which brings provider bundles beyond the declared CLI scope.

## Generations and rollback

Inspect retained generations inside NixOS:

```powershell
# The examples use the sample distribution name, NixOS. If you changed
# WSL_NIXOS_DISTRIBUTION, substitute that name here.
wsl.exe -d NixOS -u root -- nixos-rebuild list-generations
```

An emergency rollback is an explicit recovery action:

```powershell
wsl.exe -d NixOS -u root -- nixos-rebuild boot --rollback
wsl.exe --terminate NixOS
```

The next launch uses the selected previous generation. Repository `Test` should then report drift because the active generation no longer equals the declared target. Reconcile the Git source and run the focused Ensure after the incident is understood.

## Removal boundary

This module has no uninstall or unregister mode. `wsl.exe --unregister NixOS` permanently deletes the distribution VHD and its mutable home, so it is intentionally outside desired-state automation. Export or back up required user state before any manually approved removal.
