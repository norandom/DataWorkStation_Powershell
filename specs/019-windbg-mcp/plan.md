# Implementation Plan: WinDbg MCP state and tricky debugger route

Use config/windbg-mcp.psd1, scripts/WinDbgMcp.Core.ps1, scripts/Set-WinDbgMcpState.ps1, and
scripts/Invoke-WinDbgMcp.ps1. Register an opt-in Extended module behind Packages, add the `debug`
action to scripts/Invoke-Tricky.ps1, and expose the human command `windbg-mcp`. Keep the transport
in one file so the pure planner, settings merge, session selection, and sampling bridge are tested
without a live debugger: the real public planner, fixture settings documents, pure session lists,
and a fake MCP server over the same stdio contract.

| Requirement | Verification |
|---|---|
| REQ-001 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpState |
| REQ-002 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpState |
| REQ-003 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpState |
| REQ-004 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSettings |
| REQ-005 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSettings |
| REQ-006 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSessions |
| REQ-007 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSessions |
| REQ-008 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSampling |
| REQ-009 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSampling |
| REQ-010 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpTrickyRoute |
| REQ-011 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSecureModeBoundary |
| REQ-012 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSecureModeBoundary |
| REQ-013 | tests/Test-WinDbgMcpState.ps1#Test-WinDbgMcpSecureModeBoundary |
