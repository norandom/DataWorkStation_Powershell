# Feature Specification: Early-OOM recovery

## User Story

As a workstation operator running xdist and parallel AI agents, I can recover from sustained global memory pressure across ordinary user applications and inspect attributable recovery logs before debugging a disappearance.

## Requirements

- **REQ-001**: When memory capacity changes, the system shall evaluate pressure against the current physical and commit capacities.
- **REQ-002**: When pressure is transient or an intervention is within its cooldown, the system shall defer another intervention.
- **REQ-003**: When memory telemetry is invalid, the system shall reject the pressure decision.
- **REQ-004**: When a candidate is a system process, critical process, Windows-directory image, session-zero process, service account, configured excluded executable or cannot be queried, the system shall exclude it from termination.
- **REQ-005**: When guard events are inspected, the system shall report timestamp-filtered events and malformed-record counts from a bounded rotated-log tail.
- **REQ-006**: When an ordinary user application exceeds the candidate minimum and has no exclusion, the system shall consider it independently of executable inclusion lists and managed-job membership.
- **REQ-007**: When candidates are inspected, the system shall report eligible processes ranked by private bytes and exclusion counts without terminating any process.

## Scope

The optional memory-limit service supplies layer-2 recovery independently of the optional commercially licensed Process Lasso installation and layer-1 allocation targets. Enforce mode force-terminates one eligible user application under sustained pressure, with a mandatory pre-action audit record and final eligibility/pressure recheck. Java, browsers, AI hosts and unknown applications qualify; Windows, services, desktop and recovery tools are protected. Observe mode only records intended actions. No page-file resize, memory-trimming policy or processor-group changes are applied. Read-only PowerShell commands expose the calculated plan, current status, candidates and existing events. Debug skills correlate UTC and process identity before new capture. This polling recovery layer is not a guaranteed allocation boundary.
