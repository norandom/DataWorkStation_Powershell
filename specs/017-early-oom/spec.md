# Feature Specification: Early-OOM recovery

## User Story

As a workstation operator running xdist and AI tools, I can recover from sustained global memory pressure using a bounded worker policy and inspect attributable recovery logs before debugging a disappearance.

## Requirements

- **REQ-001**: When memory capacity changes, the system shall evaluate pressure against the current physical and commit capacities.
- **REQ-002**: When pressure is transient or an intervention is within its cooldown, the system shall defer another intervention.
- **REQ-003**: When memory telemetry is invalid, the system shall reject the pressure decision.
- **REQ-004**: When a termination executable outside the managed Python and .NET worker scope is declared, the system shall reject the policy.
- **REQ-005**: When guard events are inspected, the system shall report timestamp-filtered events and malformed-record counts from a bounded rotated-log tail.

## Scope

The optional memory-limit service supplies the guard, independently of the optional commercially licensed Process Lasso installation. Enforce mode force-terminates one eligible already-managed worker under sustained pressure, with a mandatory pre-action audit record. Observe mode only records intended actions. No global desktop/Java/AI-host termination policy, page-file resize, memory-trimming policy or processor-group changes are applied. Read-only PowerShell commands expose the calculated plan, current status and existing events. Debug skills correlate UTC and process identity before new capture.
