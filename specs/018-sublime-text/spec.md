# Feature Specification: Optional Sublime Text PATH integration

## User Story

As a workstation operator, I can explicitly expose my existing Sublime Text installation as `subl`.

## Requirements

- **REQ-001**: When a default or All module plan is requested, the system shall exclude SublimeText.
- **REQ-002**: When SublimeText is explicitly selected, the system shall plan its PowerShell7 prerequisite before the module.
- **REQ-003**: When Test mode is invoked, the system shall report executable and user PATH state without changing the environment.
- **REQ-004**: When Ensure or Reinitialize is invoked for an installed editor, the system shall add its directory to the user PATH idempotently while preserving unrelated entries.
- **REQ-005**: If the configured executable is absent, then the system shall reject Ensure without changing PATH.

## Scope

Only PATH integration is managed. Installation, upgrades, activation, and editor preferences remain user-controlled.
