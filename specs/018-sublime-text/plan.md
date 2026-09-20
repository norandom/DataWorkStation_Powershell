# Implementation Plan: Optional Sublime Text PATH integration

Use config/sublime-text.psd1 and scripts/Set-SublimeTextState.ps1. Register an optional Core module,
remove automatic profile exposure, and preserve existing user PATH content. Test the real public
planner, fixture installation states, pure PATH merging, and a child process with a missing installation.

| Requirement | Verification |
|---|---|
| REQ-001 | tests/Test-SublimeTextState.ps1#Test-SublimeTextState |
| REQ-002 | tests/Test-SublimeTextState.ps1#Test-SublimeTextState |
| REQ-003 | tests/Test-SublimeTextState.ps1#Test-SublimeTextState |
| REQ-004 | tests/Test-SublimeTextState.ps1#Test-SublimeTextState |
| REQ-005 | tests/Test-SublimeTextState.ps1#Test-SublimeTextState |
