# NixOS integrity and alteration detection

The NixOS WSL self-check answers two different questions:

1. Is this the system generation declared by the repository?
2. Are the immutable files in the distribution's Nix store still byte-for-byte valid?

Run it from PowerShell:

```powershell
nixos-check
nixos-check -Json
```

The human output is the operating interface. JSON exposes the same result to scripts and AI tools. The check is deliberately read-only: it does not build, download, repair, garbage-collect, stop a distribution, or change the active generation.

## What is verified

| Layer | Verification | What it detects |
|---|---|---|
| Repository deployment | Windows SHA-256 comparison for every declared `nixos/` source plus generated `local.nix` | A repository source that was not deployed, or a deployed source changed outside the repository |
| Active generation | `/run/current-system` compared with the evaluated `system.build.toplevel` output path | A valid but different NixOS generation is active |
| Complete Nix store | `nix store verify --all --no-trust` | Content in any local `/nix/store` path no longer matches its recorded NAR hash |
| Command provenance | Each managed command is resolved and canonicalized beneath `/nix/store` | PATH injection, a local shim, or an unmanaged replacement for Helm, kubectl, Pulumi, SSH, or the self-check |

`--no-trust` disables signature-trust evaluation for this local content check. It does not disable content hashing. Every local store path is still verified against its recorded content identity, including paths that are not referenced by the active generation.

The active system path is also a reproducible identity. For example:

```text
/nix/store/fypcqn2v5s47xqx8is6rl5rmb77n8avg-nixos-system-nixos-wsl-26.05.20260814.02e0898
```

The prefix changes when a declared input or configuration changes. The self-check compares the evaluated target with the active path instead of relying on the human-readable version suffix.

## What “the entire distribution” means here

NixOS separates immutable software from mutable runtime state. The complete Nix store covers the operating-system closure, package contents, libraries, generated unit definitions, and every other realized store path in the distribution. That is the part Nix can content-address and verify comprehensively.

These paths are outside the immutable-store claim:

| Mutable surface | Examples | Why it is separate |
|---|---|---|
| User state | `/home`, shell history, Pulumi projects, kubeconfig, caches | Deliberately writable and often secret-bearing |
| Runtime state | `/run`, processes, sockets, mounts | Recreated while the distribution runs |
| Service state | `/var`, logs, journals, package caches | Expected to change independently of a generation |
| Windows mounts | `/mnt/c`, the shared SSH configuration, source checkouts | Owned by Windows/DrvFS rather than the Nix store |
| WSL host state | Kernel, WSL runtime, `.wslconfig`, VHD container | Supplied or controlled outside this NixOS closure |

The self-check therefore does not claim that every byte in the VHD is immutable. It verifies all content for which Nix has a trustworthy content identity and separately verifies the deployed configuration source. Mutable-state monitoring, credential auditing, and WSL-host verification remain different controls.

## Status and exit codes

| Status | Exit code | Operator meaning |
|---|---:|---|
| `compliant` | 0 | Generation, source, complete store, and command provenance all match. |
| `drifted` | 1 | The declared target or deployed source differs, but no verified immutable content failure was found. |
| `altered` | 2 | Store verification failed or a managed command resolved outside the Nix store. Treat this as an integrity incident until explained. |

JSON contains `activeSystem`, `targetSystem`, `storeIntegrity`, `sourceIntegrity`, `commandIntegrity`, and a bounded `detail` field. Automation should branch on `status` or the exit code, not parse the prose in `detail`.

## What the check does not prove

A compliant result is strong evidence for the declared immutable content. It is not a malware verdict and does not prove all runtime behavior is benign:

- a deliberately declared but unsafe package can still be reproducible;
- a valid store path can be present without belonging to the active generation;
- a compromised kernel or WSL host can affect what the guest observes;
- user credentials, kubeconfig, Pulumi state, and project code remain mutable;
- network services and cloud-side state are outside the generation hash.

Review changes to `flake.nix`, `flake.lock`, and the NixOS modules as code. Reproducibility makes those changes visible; it does not replace review.

## Respond to a failed check

Do not repair first. Preserve the human and JSON result:

```powershell
nixos-check
nixos-check -Json | Set-Content .\nixos-integrity-result.json
```

Then use the failure class:

### Drifted

1. Review `git diff -- nixos config/nixos-wsl.psd1` and inspect local `config.json` separately.
2. Compare the active and target system paths from JSON.
3. If the repository change is intended, inspect the module plan.
4. Reconcile only the focused module:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module NixOsWsl -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module NixOsWsl
```

### Altered

1. Retain the result and the direct verifier output before changing the store:

   ```powershell
   wsl-nix nix store verify --all --no-trust
   ```

2. Check the visible command links, then resolve a suspect link to its store path:

   ```powershell
   wsl-nix which helm kubectl pulumi ssh workstation-self-check
   wsl-nix readlink -f /run/current-system/sw/bin/helm
   ```

3. Do not run garbage collection merely to remove evidence.
4. Decide whether to fetch/rebuild the affected path, activate a reviewed generation, or preserve the VHD for deeper investigation.

The workstation resource does not silently repair an `altered` result. An integrity failure deserves an explicit operator decision.

## Verification cost

The full-store pass reads and hashes all local store content. It can take more than a minute and grows with retained generations and unreferenced store paths. That is expected; elapsed time is not treated as a compliance failure. Use the full check when integrity matters rather than replacing it with a package-list comparison.

Garbage collection can reduce future verification work, but it deletes unreferenced store paths and is intentionally not part of `Ensure` or `nixos-check`.
