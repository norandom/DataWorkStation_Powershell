# Data Model: PowerShell Test Framework

## Framework state

- Declared version
- Repository name
- Shared per-user module base
- Versions resolved by PowerShell 7 and Windows PowerShell 5.1
- Compliance status and pending repair

States: `absent-or-drifted` → explicit Ensure → `compliant`.

## Test lane

- Runtime: modern or compatibility
- Parallel eligibility
- Requested and effective throttle
- Sequential fallback reason
- Selected paths and filters

## Test file

- Standard discoverable path
- Logical suite and section selectors
- Runtime compatibility
- Exclusive/no-parallel marker

## Test summary

- Schema version
- Runtime and framework version
- Parallel state and throttle
- Total, passed, failed, skipped, and not-run counts
- Duration
- Bounded failure records
- Overall status and process exit code
