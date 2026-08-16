# Autopsy Windows forensic workstation

This module installs the current Autopsy Windows GUI—the desktop, Explorer-style application—not
the legacy web-based Autopsy Forensic Browser. The complete setup uses the official Autopsy 4.23.1
MSI and the matching official Sleuth Kit 4.15.0 Windows command archive.

## Plan, install, and test

Start with the dependency plan. It is read-only and shows every prerequisite:

```powershell
./Apply-Workstation.ps1 -Mode Test -Module Autopsy -Plan
```

Install or repair the complete setup, then test it:

```powershell
./Apply-Workstation.ps1 -Mode Ensure -Module Autopsy
./Apply-Workstation.ps1 -Mode Test -Module Autopsy
```

The test is observational, but the orchestrator runs this module through `sudo` because Windows
hides Defender exclusions from a non-administrator. The standalone Sleuth Kit installation is
verified as a deterministic 92-file tree. Autopsy verifies the exact size and SHA-256 of 11 exposed
executables, including the GUI, Java launcher, RegRipper, patched `ewfexport`, Tesseract, YARA,
PhotoRec, TestDisk, GStreamer, Plaso, and the logical imager. `Ensure` downloads the pinned MSI and
runs Windows Installer repair when one of those managed files drifts.

`Autopsy` is optional and is not selected by `-Module All`. Its dependencies run in this order:
`Sudo` and `PowerShell7`, then `PowerShellProfile`, `SleuthKitCli`, and finally `Autopsy`. Run only
the command suite with `-Module SleuthKitCli` when the GUI is not needed.

The Autopsy installer is about 1.29 GB. Ensure downloads it only when the declared version is
missing or drifted. The resource verifies the exact byte length, SHA-256, EV Authenticode signer,
certificate thumbprint, product version, installed GUI, and reviewed private command paths. MSI
logs are retained under `state/autopsy/`; the resource never restarts Windows.

## Start the GUI and use Sleuth Kit

Open Autopsy from PowerShell:

```powershell
autopsy
```

The managed case/output root is `%USERPROFILE%\Documents\Autopsy Cases`. Put new case output below
that directory so the declared Defender exclusion applies.

The separate native Sleuth Kit directory is added to the user `PATH`. Open a new terminal after the
first install, or use the current shell in which Ensure ran:

```powershell
mmls -V
fsstat -V
fls -V
Get-Command mmls, fls, icat, fsstat, tsk_recover
```

This is the official 4.15.0 Windows build matched by Autopsy's `TSKVersion.xml`. It provides the
normal TSK commands without WSL, Cygwin, MSYS/MSYS2, MinGW, or Git Bash.

## Defender boundary

Autopsy warns that antivirus software can quarantine or delete extracted results. Some ingest
modules write files to the case/output directory without encoding them. The managed setup uses two
durable exclusions:

- the case/output directory, which applies to real-time, scheduled, and on-demand Defender scans;
- `autopsy64.exe` as a process exclusion for files opened during real-time processing.

Defender remains installed. `WinDefend` and `MsMpEng` are not removed, disabled, or killed. This
keeps the change reversible and makes the engine, service, protection controls, and exclusion state
separately observable.

When a case requires all configured protection layers to be inactive, use the explicit session
commands:

```powershell
autopsy-defender-status
autopsy-defender-off
autopsy-defender-status
autopsy
```

Restore normal protection as soon as the work is complete:

```powershell
autopsy-defender-on
autopsy-defender-status
```

Windows can turn real-time protection back on later. The folder exclusion is therefore the durable
guardrail for case results. Disabling protection increases the chance that hostile evidence can
infect the workstation; it does not make opening or executing extracted files safe.

## Firewall listener prompt

Autopsy and its bundled Java runtime can request inbound listener rules. The workstation firewall
keeps the unmatched inbound default at Block but deliberately honors an expert's **Allow access**
choice on Domain, Private, and Public profiles. Listener notifications remain enabled; the profile
is no longer locked in a state where the button appears managed but cannot create an effective rule.

An application allow rule does not create a listener by itself. Its exposure depends on the
addresses and ports the process actually binds. After approving a new application, inspect that
boundary with `ports` or `connections`; selecting Public can expose a non-loopback listener to an
untrusted network. In the local 4.23.1 smoke test, Autopsy's private Solr Java process listened on
wildcard TCP 23232 and used loopback TCP 8079 for its stop control. Approving Java therefore makes
23232 reachable on the profiles selected in the prompt while that process is running.

## Bundled and private dependencies

The MSI is self-contained. The module does not install another Java, NetBeans, Solr, GStreamer,
RegRipper, libewf, or TSK runtime for the GUI. Autopsy 4.23.1 currently bundles Java 21.0.10,
NetBeans RCP 15, TSK 4.15.0, its patched libewf path, RegRipper plus Autopsy plugins, Solr/Lucene/Tika,
GStreamer, Tesseract, PhotoRec/TestDisk, YARA, and other ingest helpers.

Reviewed commands that need Autopsy's private layout use namespaced bindings:

| Command | Use |
|---|---|
| `autopsy-regripper` | Run the bundled RegRipper CLI with Autopsy's custom plugins. |
| `autopsy-ewfexport` | Run the patched private libewf export command explicitly. |
| `autopsy-tesseract` | Run the OCR binary used by ingest. |
| `autopsy-yara` | Compile rules with Autopsy's bundled YARA compiler. |
| `autopsy-photorec`, `autopsy-testdisk` | Run the bundled recovery consoles. |
| `autopsy-gst-inspect` | Inspect the bundled GStreamer plugins. |
| `autopsy-log2timeline` | Run the old Autopsy-compatible Plaso build; do not treat it as current general Plaso. |
| `autopsy-tsk-logical-imager` | Run Autopsy's bundled logical imager explicitly. |

These directories are not added wholesale to `PATH`. Several are compatibility versions and may
differ from current upstream releases. The bindings preserve Autopsy's relative working-directory
assumptions and prevent its patched DLLs from shadowing unrelated system tools.

Recent Activity is an Autopsy ingest module, not one standalone CLI. `autopsy-regripper` exposes one
important component and its custom plugins, but it does not reproduce the complete Recent Activity
pipeline outside the GUI.

## Relationship to native EWF verification

Autopsy does not replace `NativeForensicTools` or `ewf-verify`. The lightweight verifier has its own
reviewed package identity, read-only held-handle transaction, pre/post evidence hashes, parser,
reports, and certification boundary. Select it when only attributable E01 verification is needed:

```powershell
./Apply-Workstation.ps1 -Mode Test -Module NativeForensicTools -Plan
```

Autopsy's embedded patched libewf belongs to the GUI release. Its `ewfexport` binding can write
output and is not a substitute for the repository's read-only verification report.

## Sources and trust record

The release catalog records official URLs, exact sizes and hashes, the upstream signing-key
fingerprint, and the Autopsy MSI Authenticode identity. See the [Autopsy 4.23.1 release](https://github.com/sleuthkit/autopsy/releases/tag/autopsy-4.23.1),
the [Sleuth Kit 4.15.0 release](https://github.com/sleuthkit/sleuthkit/releases/tag/sleuthkit-4.15.0),
and Autopsy's [installation and antivirus guidance](https://sleuthkit.org/autopsy/docs/user-docs/4.22.0/installation_page.html).
