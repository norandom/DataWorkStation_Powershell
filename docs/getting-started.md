# Getting started

Run desired state from PowerShell 7:

```powershell
git clone https://github.com/norandom/DataWorkStation_Powershell.git "$HOME/Source/PowerShell"
cd "$HOME/Source/PowerShell"
./Apply-Workstation.ps1 -Mode Test
./Apply-Workstation.ps1 -Mode Ensure
```

Open a new PowerShell session after profile installation. The prompt should show `username@host path>` and commands such as `rg`, `gh`, `uv`, `docker`, `mem`, `ports`, and `tricky` should resolve.

## Documentation locally

MkDocs is a locked repository dependency, not a global workstation package:

```powershell
docs-serve
docs-build
```

The first invocation lets `uv` create the isolated documentation environment. `docs-build` uses strict mode and writes the ignored `site/` directory.

## Verify without changing state

```powershell
./Apply-Workstation.ps1 -Mode Test
profile-status
firewall-status
defender-status
tricky capabilities
```

Some Windows state tests require an elevated shell. Capture and debugger commands remain explicit even after `Ensure`.
