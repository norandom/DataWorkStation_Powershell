# Podman Static Container Contract

## Stable operator interface

```powershell
malware-container-status
malware-container-status -Json
malware-container <file>
malware-container <file> -Json
malware-container <file> -Run -ConfirmContainer
malware-container-control <file>
malware-container-control <file> -Run -ConfirmContainer
```

These command names, planning behavior, confirmations, result states, non-verdict, and evidence
formats remain stable. Runtime-specific convenience aliases are not part of the contract. Use
`wsl-mw podman ...` only for low-level diagnosis.

## Plan and gate

Planning creates a new ignored case and exact argument array without starting Podman or changing
image state. A confirmed run requires:

- the dedicated Debian-MW distribution and selected non-root user;
- local rootless Podman with no active API service/socket;
- the declared Podman-local OCI image and complete tool fingerprint;
- `--rm`, `--network none`, `--read-only`, dropped capabilities, no-new-privileges, explicit
  non-root image user, and CPU/memory/PID/time bounds;
- a read-only mount for exactly one target when the role is Target;
- a writable mount for exactly one new case output;
- bounded transient storage;
- no engine socket, host device, host namespace, privileged mode, network override, Compose
  operation, unsupported flag, or unrelated mount.

The target path is a fixed argument and never shell-interpolated. A failed gate blocks before the
parser can read the target.

## Image state

```powershell
pwsh -NoProfile -File ./scripts/Set-MalwareContainerImageState.ps1 -Mode Test
pwsh -NoProfile -File ./scripts/Set-MalwareContainerImageState.ps1 -Mode Test -Json
pwsh -NoProfile -File ./scripts/Set-MalwareContainerImageState.ps1 -Mode Ensure
```

Test inspects only Podman's local image store. Ensure is the separate explicit networked build from
reviewed source. Neither command imports the legacy Docker image store. Analysis never calls Ensure.

## Evidence compatibility

New manifests add Podman runtime name/version while preserving the existing schema's case, image,
tool, isolation, status, and non-verdict fields. Historical Docker cases remain readable and
immutable. Docker/Podman, runtime-version, image, inventory, or isolation mismatches make two cases
incompatible for differential conclusions.

Raw parser output remains attacker-controlled and passes only through the existing bounded Python
ingestor before host display or correlation.
