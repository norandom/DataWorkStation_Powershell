# Contract: PowerShell test command

## Human interface

```powershell
test-powershell
test-powershell -Compatibility
test-powershell -Path tests/pester/RootlessPodman.Tests.ps1
```

The default lane uses bounded file-level parallel execution when PowerShell 7.4+ and the selected
inputs permit it. `-Compatibility` dispatches the same discoverable tests through Windows
PowerShell 5.1 sequentially. `-ThrottleLimit` accepts only the configured finite range.

## Machine interface

```powershell
test-powershell -Json
```

The JSON object contains schema version, status, runtime, framework version, parallel/effective
throttle values, counts, duration, and bounded failure records. A failed or undiscoverable test
returns nonzero in both output modes.

## Safety

- The command never installs or repairs Pester.
- Files marked `#pester:no-parallel` remain outside the concurrent batch.
- Live-state test files must use that marker.
- Compatibility exclusions are explicit.
