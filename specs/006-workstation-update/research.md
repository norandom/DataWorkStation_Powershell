# Research: Managed Workstation Update

## Windows servicing

**Decision**: Use the built-in Windows Update Agent interfaces for a narrow software-update search,
download, and install wrapper. Exclude driver updates, skip updates whose EULA is not already
accepted, and report rather than perform a reboot.

**Rationale**: Microsoft documents the update-session/searcher/installer interfaces and a complete
search-download-install flow. The underlying API is supported even though Microsoft's sample
script is explicitly illustrative rather than production code. Keeping this behind a focused,
testable wrapper avoids depending on an undocumented `UsoClient` command or a third-party module.

**Alternatives considered**: `UsoClient` was rejected as an undocumented automation surface.
Installing PSWindowsUpdate was rejected as a new privileged third-party dependency. Opening the
Settings page was rejected because it cannot produce deterministic completion or JSON state.

Sources:

- https://learn.microsoft.com/windows/win32/api/wuapi/nn-wuapi-iupdatesearcher
- https://learn.microsoft.com/previous-versions/windows/desktop/aa387102(v=vs.85)

## WinGet applications

**Decision**: Preview with `winget upgrade` and apply with `winget upgrade --all` plus agreement and
noninteractive flags. Do not add `--include-unknown`, `--include-pinned`, or
`--uninstall-previous`. Treat the documented no-applicable-update HRESULT as a successful no-op.

**Rationale**: This follows Microsoft's supported all-application path while retaining existing
pins and avoiding ambiguous installed versions or forced uninstall/reinstall transitions.

**Alternatives considered**: Reapplying only repository WinGet Configuration would miss unmanaged
ordinary applications. Including unknown or pinned versions would exceed the user's release/drift
boundary.

Sources:

- https://learn.microsoft.com/windows/package-manager/winget/upgrade
- https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md

## Scoop applications

**Decision**: Require the declared official Scoop and bucket state, run `scoop update`, then
`scoop update *`. Do not run cleanup.

**Rationale**: Scoop's own Quick Start documents these as the core/manifest and all-installed-app
update commands. Cleanup is a separate destructive retention choice.

**Alternatives considered**: Updating only applications can use stale manifests. Cleanup was
rejected because it removes rollback versions and was not requested.

Source: https://github.com/ScoopInstaller/Scoop/wiki/Quick-Start

## WSL host and distributions

**Decision**: Update the host runtime with `wsl --update`. Update only the two distributions named
in `.wsl-env`, each through explicit root `apt-get update` and noninteractive `dist-upgrade`.

**Rationale**: Microsoft documents separate WSL runtime and distribution-user-binary updates.
Declared targets preserve the developer/malware boundary and avoid touching unrelated distros.

**Alternatives considered**: Enumerating every installed distribution was rejected as unmanaged
scope. Automatic `wsl --shutdown` was rejected because it interrupts workloads and is unnecessary
for reporting that a new session or restart is needed.

Sources:

- https://learn.microsoft.com/windows/wsl/basic-commands
- https://learn.microsoft.com/windows/wsl/troubleshooting

## Homebrew instances

**Decision**: Declare each managed instance in the update catalog. Run `brew update`, retain
release-owned formula pins, then run `brew upgrade` for ordinary unpinned formulae. The initial
catalog contains only developer Debian.

**Rationale**: Homebrew documents `update` for package definitions and Homebrew itself and
`upgrade` for outdated unpinned formulae. Explicit instance declarations prevent discovery across
unrelated or hostile distributions.

**Alternatives considered**: Discovering `brew` across all WSL distributions was rejected as a
trust-boundary violation. Updating metadata only would not satisfy the request to update Homebrew
instances.

Sources:

- https://docs.brew.sh/Manpage.html
- https://docs.brew.sh/FAQ

## Container engines and release reconciliation

**Decision**: Let APT update engine packages, then use the existing pyinfra-backed Docker and Podman
resources to restore their declared topology. Finish with the current checkout's default
`Apply-Workstation Ensure` followed by Test.

**Rationale**: Reusing focused resources preserves rootful developer Docker for Dagger and
daemonless rootless Podman for untrusted parsers. The current release remains the single owner of
PowerShell profiles, environment variables, pins, dependencies, and default non-destructive state.

**Alternatives considered**: Direct Docker/Podman updater commands duplicate desired-state logic.
Pulling a newer Git branch or release inside `update` would overwrite operator code and make the
state-changing boundary materially broader.
