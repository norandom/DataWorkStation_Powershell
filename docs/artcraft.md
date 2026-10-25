# ArtCraft batch updates and PdfCraft

For everyday PDF work, prefer **PdfCraft** on this workstation. Avoid installing Adobe Acrobat and its accompanying software by default; keep Adobe only when a specific workflow requires it. This is our software preference, not a claim that every Acrobat feature has an equivalent in PdfCraft.

[PdfCraft](https://github.com/storytold/pdfcraft) is an open-source PDF reader and editor written in Rust. Test it with your own forms, fonts, annotations and printing requirements before replacing a workflow you depend on. Use the official `storytold` releases or [ArtCraft Launcher](https://github.com/storytold/craft-launcher) to obtain it. This recommendation does not uninstall Adobe or change PDF file associations.

## One command for the installed Craft suite

From this repository, check available updates without installing anything:

```powershell
pwsh -NoProfile -File .\scripts\Update-ArtCraft.ps1
```

Update all supported installed Craft apps in a sequential batch with one elevation:

```powershell
sudo pwsh -NoProfile -File .\scripts\Update-ArtCraft.ps1 -Run
```

Add `-Json` to either command for machine-readable per-app results. The managed profile also exposes:

```powershell
update -Target ArtCraft        # Static plan, no network requests
update -Target ArtCraft -Run   # Executes the batch through sudo
update -Run                   # All declared workstation update stages, including ArtCraft
```

Use the dedicated command for a single sudo boundary around the Craft batch. The complete workstation update has separate privilege boundaries for Windows servicing, per-user package managers and WSL; see [Managed workstation update](workstation-update.md).

## Why a separate batch adapter exists

The inspected launcher was version 0.7.0, running from `%LOCALAPPDATA%\Programs\ArtCraft Launcher\artcraft-launcher.exe`. Its [argument handling](https://github.com/storytold/craft-launcher/blob/v0.7.0/apps/artcraft-launcher/src/main.rs) supports version reporting and hidden startup, but no public headless update-all command. A hidden GUI is still a GUI; inventing `--update-all` would not perform a batch update.

Our adapter uses the official GitHub releases and Windows Installer directly. `config/artcraft.psd1` lists the 13 Craft suite apps plus the launcher. It inventories matching MSI registrations from the current user and machine, checks the latest stable release for each installed app, selects its Windows x64 MSI, and verifies the published SHA-256 digest before installation. It does not write the launcher's private cache or depend on its window being open.

## What the batch does

- Updates existing, recognized x64 MSI installations. It does not install missing suite members or manage portable, x86, ARM64 or old PrintCraft installations.
- Reports current versions and avoids downgrades. Ambiguous duplicate registrations are reported for manual resolution.
- Uses silent MSI installation with restart suppression and a retained per-app installation log.
- Leaves running applications open. If an update is available for a running app, it reports `blocked-running`, continues with the others and returns failure so automation notices the unfinished update.
- Includes the launcher itself when installed. Close it normally before updating it if its release is newer; the batch never terminates it.
- Reports missing hashes/assets, API errors and installer failures per app, while continuing independent updates. A reboot-required MSI result is reported without rebooting Windows.

The direct command returns 0 on success, 1 for an incomplete/failed batch and 3010 if installation succeeded but Windows Installer requests a restart. Downloads and MSI logs remain in the printed `ArtCraftUpdate-*` temporary directories for inspection. Release checks use the public GitHub API; rate limits are reported as failures, not interpreted as “already current.”

Save open work before servicing applications. The wrapper checks running process names again after downloading and disables Restart Manager's automatic app shutdown; it cannot prevent a user launching an app concurrently with Windows Installer. Deferred file replacement can require a later restart.
