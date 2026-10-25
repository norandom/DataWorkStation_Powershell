# Feature Specification: Trusted Debian WSL memory policy

## User Story

As a workstation operator, I can inspect and explicitly apply a bounded WSL memory policy with compressed swap and emergency recovery.

## Requirements

- **REQ-001**: When the host memory policy is inspected, the repository shall declare a 6 GiB RAM ceiling, 6 GiB disk swap and gradual memory reclamation.
- **REQ-002**: When trusted Debian earlyoom state is tested, the command shall report compliance only when the declared configuration matches and the installed service is enabled and active.
- **REQ-003**: When trusted Debian zram state is tested, the command shall verify installed service and helper content, enabled and active service state, a 2 GiB device, lzo-rle compression and swap priority 100.

## Scope

The explicit root-only Ensure commands install the declared service state. Zram refuses active-device drift rather than resetting or swapping off live memory. Earlyoom enables automatic emergency termination. The host configuration script does not restart WSL. Validation inspects the trusted Debian deployment without inducing pressure or exercising destructive recovery.
