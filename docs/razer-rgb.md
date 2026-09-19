# Optional Razer lighting

Install the optional module and enable hidden startup at user sign-in:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module RazerRgb -Plan
.\Apply-Workstation.ps1 -Mode Ensure -Module RazerRgb
pwsh -NoProfile -File .\scripts\Set-RazerRgbState.ps1 -Mode Test
```

Remove Synapse explicitly using its registered uninstaller:

```powershell
pwsh -NoProfile -File .\scripts\Set-RazerRgbState.ps1 -Mode Ensure -RemoveSynapse
```

OpenRGB 1.0 runs privately under `%LOCALAPPDATA%\DataWorkStation\RazerRgb`.
Its portable archive is SHA-256 pinned; no motherboard driver or system service is installed.
The module is excluded from default runs. `Test` observes state; it never installs, starts,
captures input, or removes anything. `Ensure` updates the private configuration and restarts
only the module's own OpenRGB and lighting-helper processes, compiles the helper when its source changes, and enables
the `DataWorkStation Razer RGB` HKCU Run entry. It requires PowerShell 7.

The Huntsman Mini stays blue (`0000FF`). Each pressed key turns white (`FFFFFF`) for
2,000 milliseconds after its latest key-down event, then returns to blue. Other keys retain
their own timers. Repeated presses restart the affected timer; transitions have a nominal
20 ms scheduling resolution. Physical scan codes support ANSI and ISO positions independent
of the active typing language. The keyboard's internal Fn key cannot react independently
when firmware does not expose a Windows input event.

The Basilisk V3 Pro stays on Bluetooth. Its lighting is unmanaged: OpenRGB 1.0 registers
only wired and dongle detectors for this mouse. This module enables only the Huntsman Mini
detector and does not subscribe to mouse input or change Bluetooth pairing or settings.
The absence of a mouse lighting controller is expected, not configuration drift.
The helper reconnects after SDK disconnects and device notifications.
If a newly connected USB device does not appear, rerun `Ensure` to restart detection.

The helper is a small .NET Framework executable built with the Windows compiler. It receives
Raw Input only from Razer USB device paths, stores temporary LED deadlines in memory, and
never records or transmits typed text. It sends colors to `127.0.0.1:6743`. Startup uses the
interactive user session because keyboard events are unavailable to a normal system
service. The configured detector list enables only the named keyboard detector. The
disabled detector inventory combines `REGISTER_*DETECTOR*` string literals from the
official `release_1.0` source with names saved by the pinned Windows build (including
macro-generated names and exact capitalization). Revisit it when upgrading OpenRGB.
`Test` permits omitted disabled detectors that are not built for Windows, but rejects
any enabled detector outside the declared keyboard list.

`Test` compares the deployed helper source receipt, launcher, theme, detector settings, local
SDK endpoint, and startup registration. Configuration compliance does not imply that the
keyboard is connected. `runtime-status.txt` reports connection health and device names,
including an explicit message when no supported keyboard is detected, not input activity. To stop
automatic startup, disable **DataWorkStation Razer RGB** in Windows Startup Apps. To remove
the optional installation, remove that Run entry and stop the two executables from this
private folder before deleting it. Synapse removal does not restore itself automatically.

Sources: [OpenRGB releases](https://github.com/CalcProgrammer1/OpenRGB/releases/tag/release_1.0),
[SDK protocol](https://github.com/CalcProgrammer1/OpenRGB/blob/release_1.0/Documentation/OpenRGBSDK.md),
[Razer detectors](https://github.com/CalcProgrammer1/OpenRGB/blob/release_1.0/Controllers/RazerController/RazerControllerDetect.cpp).
