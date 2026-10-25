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
- **REQ-008**: When sustained pressure permits enforcement and automatic memory optimization is enabled and due, the system shall attempt the headless MemoryOptimize cleanup before selecting a termination candidate and cancel termination if fresh physical and commit telemetry no longer meets the pressure rule.
- **REQ-009**: When an automatic optimization is attempted, the system shall persist its cooldown before launching the helper and suppress further attempts for the configured interval, defaulting to 15 minutes, including across service restarts and after failure.
- **REQ-010**: When cleanup fails, is missing, times out or is cooling down, the system shall retain the existing pressure-based termination fallback with fresh telemetry and candidate revalidation.
- **REQ-011**: While the guard is observing or disabled, the system shall not run memory cleanup.
- **REQ-012**: When automatic cleanup runs, the system shall use a protected executable without an interactive profile or tray and bound its wait to the configured timeout, at most ten seconds, recording before and after memory evidence.

## Scope

The optional memory-limit service supplies layer-2 recovery independently of the optional commercially licensed Process Lasso installation and layer-1 allocation targets. Enforce mode first attempts bounded headless memory reclamation when due, then force-terminates one eligible user application if pressure persists, with a mandatory pre-action audit record and final eligibility/pressure recheck. Java, browsers, AI hosts and unknown applications qualify; Windows, services, desktop and recovery tools are protected from termination. Observe mode only records intended actions. No page-file resize or processor-group changes are applied. Read-only PowerShell commands expose the calculated plan, current status, candidates and existing events. Debug skills correlate UTC and process identity before new capture. This polling recovery layer is not a guaranteed allocation boundary.
