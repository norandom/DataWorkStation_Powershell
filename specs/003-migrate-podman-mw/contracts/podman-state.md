# Rootless Podman State Contract

## Human commands

```powershell
./Apply-Workstation.ps1 -Mode Test -Module RootlessPodman -Plan
pwsh -NoProfile -File ./scripts/Set-RootlessPodmanState.ps1 -Mode Test
pwsh -NoProfile -File ./scripts/Set-RootlessPodmanState.ps1 -Mode Test -Json
wsl-mw podman info --format json
```

The first three commands are observational. They do not install packages, invoke an absent Podman
binary, start or stop services, initialize storage, retire Docker, or delete data. The low-level
`wsl-mw` command is for direct operator diagnosis after Podman has been initialized by an explicit
Ensure.

## Explicit convergence

```powershell
./Apply-Workstation.ps1 -Mode Ensure -Module RootlessPodman
```

This is a privileged and networked WSL state change. Human output must describe package and service
changes before the deploy. The operation provisions Podman first and validates local rootless
readiness before it retires Docker. Failure before the readiness gate leaves Docker installed and
available. Legacy Docker storage is never deleted by this command.

## Result

Default output is a concise named-check report. `-Json` returns the complete bounded runtime-state
record. A compliant result includes:

- the exact Debian-MW distribution and non-root user;
- Podman package/version and executable identity;
- local, rootless operation with expected storage ownership;
- subordinate UID/GID, storage driver, cgroup, and seccomp readiness;
- inactive and disabled Podman API service/socket;
- absent Docker commands, packages, services, repository, and developer routing;
- reported retained legacy storage without deletion.

Test exits nonzero on drift. Ensure exits nonzero unless the final state is compliant.
