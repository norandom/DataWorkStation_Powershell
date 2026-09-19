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

Enumerate all processes independently of layer-1 jobs. Apply mandatory system/session/account/path/critical checks and configured executable exclusions, then rank by private bytes. Share these checks with read-only candidate inspection and final revalidation of the held process handle.

Validation uses synthetic pressure, synthetic protected identities, a real read-only memory sample and a self-exiting 96 MiB unmanaged application. It does not exhaust host memory or terminate user workloads. Live automatic termination under OOM is not stress-tested on the workstation.
