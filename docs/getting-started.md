# Getting started

Windows 11 Pro is required.

Run desired state from PowerShell 7:

```powershell
git clone https://github.com/norandom/DataWorkStation_Powershell.git "$HOME/Source/PowerShell"
cd "$HOME/Source/PowerShell"
Copy-Item .excluded.sample .excluded
# Edit .excluded for this workstation before applying desired state.
./Apply-Workstation.ps1 -Mode Test
./Apply-Workstation.ps1 -Mode Ensure
```

To test or ensure only one managed part, use `-Module`. Inspect automatically included dependencies with `-Plan`:

```powershell
./Apply-Workstation.ps1 -Mode Test -Module Firewall
./Apply-Workstation.ps1 -Mode Test -Module Hardening -Plan
```

Open a new PowerShell session after profile installation. The prompt should show `username@host path>` and commands such as `rg`, `gh`, `uv`, `npx`, `docker`, `mem`, `ports`, and `tricky` should resolve.

Install the repository-local Git hook once after cloning:

```powershell
precommit-install
```

Commits then lint staged PowerShell files automatically. Use `precommit-run` to check the full tracked tree without committing.

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
pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test
profile-status
firewall-status
defender-status
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Test
tricky capabilities
```

Some Windows state tests require an elevated shell. Desired state enables declared Windows optional features without restarting the machine; restart explicitly if requested. Capture and debugger commands remain explicit even after `Ensure`.
