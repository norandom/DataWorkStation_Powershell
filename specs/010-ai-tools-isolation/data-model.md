# Data Model: AI Tools and WSL Isolation

## ToolDeclaration

- `Name`, `Enabled`, `Target`: reviewed product identity and Windows/AI-WSL location.
- `Channel`, `Source`, `ExpectedCommand`: exact selected delivery and observation contract.
- `VersionIdentity`, `Digest`: pinned when the channel provides immutable assets.
- `ObservedVersion`, `ObservedPath`, `ObservedChannel`, `Status`, `Action`: observational result.

## EditorDeclaration

- Stable VS Code WinGet identity.
- Four exact Marketplace extension IDs.
- Berg commit, raw source URI/digest, generated local extension identity.
- Managed setting keys and resolved local-or-portable font family.
- Unrelated settings/extensions are outside ownership.

## WslTrustRecord

- `Distribution`, `Role`, `TrustLevel`, `DailyUser`, `MaintenanceUser`.
- WSL2 identity, default user, sudo/group state, interop, Windows PATH injection, automount.
- Observed Windows/shared/other-distribution mounts and shared sockets.
- Credential metadata checks and residual Windows-host administration statement.
- `Status`, failed checks, and required explicit action.

## AiNixGeneration

- Pinned NixOS-WSL image, flake inputs, active/evaluated generation, deployed-source manifest.
- Root-owned OpenCode binary identity and command provenance.
- Maintenance-owned Homebrew/nono identity and minimum safe version.
- Daily user and immutable boundary files.
- Store/source/command/boundary integrity results.

## SandboxPolicy

- Root-owned profile identity and digest; official upstream lineage.
- Project read/write grant and reviewed runtime paths.
- Explicit credential, host, other-WSL, socket, and out-of-project denials.
- Delegated-child inheritance and network allowlist intent.
- Setup, kernel, version, policy-diff, path-probe, and network-enforcement gates.
- Launchable only when every gate is compliant.

## CaseTransferRecord

- Case ID and direction (`import` or `export`).
- Canonical Windows source/destination and private guest path.
- Entry inventory, byte count, SHA-256 identities, and transfer timestamp.
- Reparse/link/traversal/device/socket validation results.
- No evidence bytes are stored in the repository or JSON status output.

## State transitions

- Tool/editor: `absent|drifted → Plan → explicit Ensure → compliant`; Test never transitions.
- Restricted WSL: `absent|integrated|drifted → explicit Ensure → terminate selected distro →
  restricted → verified`; no unregister transition exists.
- OpenCode: `requested → preflight → denied` on any failed gate, otherwise `sandbox exec`.
- Case import: `validated Windows source → streamed staging → guest validation/hash → committed case`.
- Case export: `validated guest results → streamed Windows staging → validation/hash → committed output`.
