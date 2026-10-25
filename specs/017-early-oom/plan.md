# Implementation Plan: Early-OOM recovery

Extend the existing C# memory-limit service with EarlyOom.cs rather than launch another polling daemon. Use GetPerformanceInfo for current capacity and commit, EnumPageFiles for page-file telemetry, a pure pressure state machine, and held process handles for candidate identity. Add Get-WorkloadMemoryDiagnostics.ps1 before documenting skill orchestration. Native allocation limits continue independently of guard faults.

| Requirement | Verification |
|---|---|
| REQ-001 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-002 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-003 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-004 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-005 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-006 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-007 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-008 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-009 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-010 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-011 | tests/Test-EarlyOom.ps1#Test-EarlyOom |
| REQ-012 | tests/Test-EarlyOom.ps1#Test-EarlyOom |

MemoryReclaimer runs the same area switches as MemoryOptimize --now, directly from a signed
copy staged into the service's protected Program Files directory by Ensure. The service loads
no user profile and requests no UAC or tray. Persist the attempt timestamp before launch;
keep this 15-minute default separate from the existing 15-second action cooldown. Recheck
physical and commit pressure after cleanup even on failure; critical commit exhaustion remains
a reason to terminate. A ten-second helper timeout bounds blocking; only that helper may be
stopped on timeout. Synthetic delegates exercise outcomes, restart persistence and audit failure.

Enumerate all processes independently of layer-1 jobs. Apply mandatory system/session/account/path/critical checks and configured executable exclusions, then rank by private bytes. Share these checks with read-only candidate inspection and final revalidation of the held process handle.

Validation uses synthetic pressure, synthetic protected identities, a real read-only memory sample and a self-exiting 96 MiB unmanaged application. It does not exhaust host memory or terminate user workloads. Live automatic termination under OOM is not stress-tested on the workstation.
