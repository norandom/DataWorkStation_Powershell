# Feature Specification: Optional Process Lasso

## User Story

As a workstation owner, I can explicitly install Process Lasso without including it in default workstation runs.

## Requirements

- **REQ-001**: When a default workstation plan is requested, the system shall exclude ProcessLasso.
- **REQ-002**: When ProcessLasso is explicitly selected, the system shall plan PowerShell7 followed by ProcessLasso.
- **REQ-003**: When installation state is inspected, the system shall report compliance only if both the GUI and governor executables exist.
- **REQ-004**: When JSON output is requested, the system shall identify the package as BitSum.ProcessLasso and mark it optional.

## Scope

Ensure uses the official WinGet package with vendor defaults and machine-level elevation. No watchdog termination rules or license activation are managed. Reinitialize reapplies the package declaration without resetting user settings. Test is observational. Human and JSON package status include the commercial licensing requirement and explicitly report activation as unchecked; package compliance does not establish license compliance.

Commercial deployment requires a paid license under Bitsum's terms. ProBalance improves CPU responsiveness; it does not impose the repository's independent 8 GiB Job Object memory budgets. See `docs/workload-memory.md` for the xdist/AI workload model and Java exclusion.

## Success Criteria

Focused planning and missing, partial, and complete installation fixtures pass. The installed package passes the same observational Test command.
