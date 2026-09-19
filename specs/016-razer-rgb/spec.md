# Feature Specification: Optional Razer keyboard lighting

## User Story

As a workstation operator, I can enable reactive Huntsman Mini lighting while keeping my mouse on Bluetooth with its lighting unmanaged.

## Requirements

- **REQ-001**: When the module catalog is inspected, the system shall mark RazerRgb as optional without Reinitialize support.
- **REQ-002**: When a keyboard lighting deadline is reached, the system shall restore the base color.
- **REQ-003**: When keyboard input is mapped, the system shall use physical scan-code positions.
- **REQ-004**: When deployed detector settings differ from the declared keyboard policy, the system shall report configuration drift.
- **REQ-005**: When Test mode is invoked, the system shall inspect configuration without installing or starting the helper.

## Scope

Ensure installs the pinned portable OpenRGB package, compiles the local helper and registers user startup. Only the keyboard detector and keyboard input are enabled. The Bluetooth mouse remains unmanaged. Test compares settings and source receipts; a missing physical keyboard is reported separately from configuration compliance. Synapse removal is a separate explicit switch.
