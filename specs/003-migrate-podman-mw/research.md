# Research: Migrate Debian-MW to Podman

## Decision 1: Run Podman locally inside the existing Debian-MW distribution

**Decision**: Install the Debian Podman package inside Debian-MW and invoke it as the selected
non-root user through the existing generic `wsl-mw` boundary.

**Rationale**: Podman is daemonless and supports automatic rootless user namespaces. Local execution
avoids SSH, a Windows remote client, a second Podman-managed WSL machine, and a persistent API
endpoint. Debian has shipped Podman since Debian 11, so Debian-MW can use its distribution lifecycle.

**Alternatives considered**: Docker Desktop integration would share the developer engine and weaken
the dedicated boundary. Podman for Windows creates or controls another WSL machine and uses a remote
service. Docker contexts over SSH and an exposed Docker TCP endpoint were rejected by the user.

Sources: [Podman command and rootless model](https://docs.podman.io/en/latest/markdown/podman.1.html),
[Podman installation](https://podman.io/docs/installation).

## Decision 2: Use Debian packages and update-compatible versioning

**Decision**: Maintain `podman`, `uidmap`, `fuse-overlayfs`, and `passt` from the selected Debian 13
repositories instead of Homebrew or a third-party container repository. Accept compatible Debian
security and point updates rather than pinning one package build forever.

**Rationale**: The runtime is part of the Debian security boundary. Distribution packages receive
normal dependency and security maintenance, avoid an additional package-manager trust root, and
include integration with Debian's user namespaces, OCI runtimes, networking, and storage helpers.

**Alternatives considered**: Homebrew is useful for user development tools but is not Podman's
recommended Linux installation source. A vendor repository would add key/repository state without a
demonstrated requirement. An exact package pin would impede security updates.

## Decision 3: Gate on local rootless behavior, not on a socket path

**Decision**: Readiness requires a non-root selected user, valid subordinate UID/GID ranges, local
Podman operation, rootless security state, user-owned local storage, supported isolation facilities,
and inactive/disabled Podman API units. A reported remote-socket metadata path is not itself a
failure when the client reports local operation and no service is active.

**Rationale**: `podman info --format json` exposes host, security, store, and remote/local state. A
rootless installation can describe its conventional socket path even when no API service is
running. The security requirement is that analysis invokes the local CLI and no persistent service
or socket activation is available.

**Alternatives considered**: Checking only the effective UID does not prove rootless user-namespace
operation. Checking only a conventional socket pathname creates false positives. Enabling
`podman.socket` for Docker API compatibility contradicts the daemonless boundary.

Source: [podman info](https://docs.podman.io/en/stable/markdown/podman-info.1.html).

## Decision 4: Use a two-stage cutover with Docker retained until Podman validates

**Decision**: Provision Podman first, validate it, and only then run a separate retirement deploy
that stops/disables the rootless Docker user unit and removes Docker packages/repository metadata.
Retain the legacy Docker storage directory.

**Rationale**: Docker and Podman can coexist briefly because they use separate rootless storage and
no network/API bridge is configured. This makes the important failure boundary deterministic: a
Podman installation or readiness failure leaves the currently working Docker environment available.
After validation, removing the long-running daemon and unused repository reduces attack surface.

**Alternatives considered**: Removing Docker first creates an avoidable outage. Keeping both engines
indefinitely retains ambiguous routing and a long-running daemon. Importing Docker storage would add
opaque migration complexity and undermine the declared image baseline.

## Decision 5: Rebuild the OCI image instead of migrating runtime storage

**Decision**: Treat the Podman image as absent until a separate explicit build from the repository's
reviewed, digest-pinned source succeeds and its complete tool inventory fingerprint matches.

**Rationale**: OCI build input is the reproducible contract; local runtime stores are implementation
state. Rebuilding avoids trusting an export/import path, preserves image provenance, and keeps normal
analysis unable to pull, build, or repair its environment.

**Alternatives considered**: `docker save`/`podman load` would move an opaque artifact and require
temporary files. Registry push/pull would expose an unnecessary network and publication path.

## Decision 6: Preserve workflow commands, not engine-shaped aliases

**Decision**: Keep `malware-container`, `malware-container-status`, control, report, comparison, and
structured-output contracts. Remove `docker-mw`, `docker-mw-compose`, and any proposed `podman-mw`.
Document `wsl-mw podman ...` for low-level inspection.

**Rationale**: The malware workflow, not a general container host, is the supported user interface.
The generic WSL selector already exposes direct diagnosis without coupling PowerShell command
discovery to one runtime. Removing aliases now is an intentional breaking change captured by this
feature.

**Alternatives considered**: A Docker-to-Podman compatibility alias would hide the selected engine
and encourage unsupported flags. A Podman-specific alias would duplicate `wsl-mw`. Keeping Compose
would require an external provider and may activate an API socket despite no workflow need.

Source: [Podman Compose uses an external provider](https://docs.podman.io/en/latest/markdown/podman-compose.1.html).

## Decision 7: Keep analysis isolation and evidence processing runtime-neutral

**Decision**: Retain the existing no-network, read-only-root, dropped-capability,
no-new-privileges, non-root, resource-bound, exact-mount, fixed-entrypoint, and bounded-evidence
policies. Add explicit runtime name/version to new manifests and comparison compatibility.

**Rationale**: Podman accepts the required OCI run controls, while runtime identity is necessary to
avoid presenting Docker and Podman cases as equivalent baselines. Historical manifests remain
immutable evidence and can still be reported.

**Alternatives considered**: Rewriting old manifests destroys provenance. Treating every
`RootlessContainer` case as equivalent ignores a material backend change. Relaxing flags because the
engine is rootless would weaken defense in depth.

Source: [Podman run security and read-only controls](https://docs.podman.io/en/latest/markdown/podman-run.1.html).

## Decision 8: Defer developer Docker Desktop and Dagger migration

**Decision**: This feature changes only Debian-MW. Developer Debian, the current developer Docker
resource, Windows Docker Desktop installation, and Dagger routing remain unchanged until a separate
specification.

**Rationale**: The malware boundary has a complete independent migration path. Mixing it with the
developer-engine replacement would enlarge rollback scope and make failures difficult to attribute.

**Alternatives considered**: A single container-platform migration would be faster on paper but
would combine incompatible trust, privilege, and lifecycle requirements.
