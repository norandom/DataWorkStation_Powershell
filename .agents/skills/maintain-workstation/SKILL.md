---
name: maintain-workstation
description: Test, explain, ensure, or reinitialize the declared DataWorkStation PowerShell state, including packages, profiles, sudo, firewall, security settings, memory policy, event logs, developer tools, and profilers. Use for setup, drift, missing commands, or desired-state failures.
---

# Maintain Workstation

Test first, then apply the narrowest authorized repair.

## Workflow

1. Read `../../../docs/desired-state.md`, `../../../README.md`, and the relevant script/config pair.
2. Run `./Apply-Workstation.ps1 -Mode Test` or the narrow resource's `-Mode Test`. Read failures; do not infer a repair from command absence alone.
3. Explain automatic versus explicit/EULA-gated actions before changing state.
4. Use `Ensure` for ordinary drift. Use `Reinitialize` only when the resource supports a safe rebuild and the user wants it; firewall reinitialization preserves a `.wfw` backup.
5. Use skip switches to avoid unrelated state changes. Run elevated commands only where required and make that visible.
6. Re-run the same test and a direct command smoke test. Do not run code scans, malware scans, captures, mounts, or debugger sessions as installation verification.
7. Update command docs, `config/capabilities.psd1`, and focused skills when an interface changes.

Preserve user changes outside the managed declarations and never silently weaken security state.
