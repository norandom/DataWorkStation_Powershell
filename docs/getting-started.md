# Getting started

Windows 11 Pro is required because the managed baseline includes Hyper-V, Windows Sandbox, Windows
sudo, and other Pro workstation features.

## Prepare the checkout

Clone the repository and create the local selection files. Review each populated file before
running desired state:

```powershell
git clone https://github.com/norandom/DataWorkStation_Powershell.git "$HOME/Source/PowerShell"
cd "$HOME/Source/PowerShell"
Copy-Item .excluded.sample .excluded
Copy-Item .wsl-env.sample .wsl-env
Copy-Item .terminal-fonts-sample .terminal-fonts
# Edit .excluded for this workstation before applying desired state.
# Set WSL_USER in .wsl-env; the tracked sample selects Debian.
# Keep Fira Code in .terminal-fonts, or replace it with an installed family.
```

The populated files are ignored by Git. They hold machine-specific paths, WSL users, and terminal
preferences that do not belong in the public repository.

## Inspect the plan

Plan mode validates selection, dependencies, stages, privilege, and destructive flags. It does not
dispatch a resource:

```powershell
./Apply-Workstation.ps1 -Mode Test -Plan
./Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan
```

Use Windows PowerShell 5.1 for the initial PowerShell 7 bootstrap if `pwsh.exe` is not installed:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan
```

## Test without repairing

Test reports compliance and drift. A nonzero result means the selected state is not compliant; it
does not authorize repair.

```powershell
./Apply-Workstation.ps1 -Mode Test
./Apply-Workstation.ps1 -Mode Test -Module Firewall
profile-status
firewall-status
defender-status
tricky capabilities
```

Some Windows state tests require elevation. Capture, debugger, removal, and protection-changing
commands remain separate and explicit.

## Apply the reviewed scope

Use `Ensure` only after reviewing the plan and Test result:

```powershell
./Apply-Workstation.ps1 -Mode Ensure
# Or repair one focused dependency closure:
./Apply-Workstation.ps1 -Mode Ensure -Module PowerShellTesting
```

Desired state never restarts Windows automatically. Restart only when a completed feature or
installer operation reports that Windows requires it. Destructive debloat remains excluded from the
default run and requires its separate confirmation.

Open a new PowerShell session after profile installation. The prompt should show
`username@host path>`. Commands such as `rg`, `gh`, `uv`, `npx`, `contour`, `docker`, `mem`, `ports`,
and `tricky` should resolve.

## Enable contributor checks

Install the repository-local Git hook once after cloning:

```powershell
precommit-install
```

Commits then lint staged PowerShell files automatically. Use `precommit-run` to check the full tracked tree without committing.

## Build the documentation locally

MkDocs is a locked repository dependency, not a global workstation package:

```powershell
docs-serve
docs-build
```

The first invocation lets `uv` create the isolated documentation environment. `docs-build` uses
strict mode and writes the ignored `site/` directory.
