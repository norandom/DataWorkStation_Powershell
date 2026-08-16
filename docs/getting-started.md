# Getting started

Windows 11 Pro is required because the managed baseline includes Hyper-V, Windows Sandbox, Windows
sudo, and other Pro workstation features.

## Prepare the checkout

Clone the repository and create the local configuration files. Review each file before applying
desired state:

```powershell
git clone https://github.com/norandom/DataWorkStation_Powershell.git "$HOME/Source/PowerShell"
cd "$HOME/Source/PowerShell"
Copy-Item .excluded.sample .excluded
Copy-Item .wsl-env.sample .wsl-env
Copy-Item .terminal-fonts-sample .terminal-fonts
# Edit .excluded for this workstation before applying desired state.
# Set the ordinary Debian, Debian-MW, and NixOS users in .wsl-env.
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
and `tricky` should resolve. Use `wsl-nix helm version`, `wsl-nix kubectl version --client`, and
`nixos-check` for the reproducible NixOS tool boundary.

## Enable contributor checks

Install the repository-local Git hook once after cloning:

```powershell
precommit-install
```

Commits then check staged PowerShell, Python, Dockerfile, GitHub Actions, YAML, JSON, and TOML files.
The hook also detects merge markers, case-conflicting paths, large files, private keys, and mixed
line endings. Run `precommit-run` to check the complete tracked tree without committing.

## Build the documentation locally

MkDocs is a locked repository dependency, not a global workstation package:

```powershell
docs-serve
docs-build
```

The first invocation lets `uv` create the isolated documentation environment. `docs-build` uses
strict mode and writes the ignored `site/` directory.
