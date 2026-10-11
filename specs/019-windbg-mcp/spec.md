# Feature Specification: WinDbg MCP state and tricky debugger route

## User Story

As a workstation operator, I can let my Windows host agents read a live WinDbg session through the
official WinDbg MCP server, with the debugger evidence landing in a Tricky case.

## Requirements

- **REQ-001**: When a default or All module plan is requested, the system shall exclude WinDbgMcp.
- **REQ-002**: When WinDbgMcp is explicitly selected, the system shall plan its Packages prerequisite before the module.
- **REQ-003**: When Test mode is invoked, the system shall report the installed WinDbg version against the minimum MCP version, the proxy path, and the MCP feature setting without changing WinDbg settings.
- **REQ-004**: When Ensure or Reinitialize is invoked, the system shall enable the MCP feature setting idempotently and keep a timestamped copy of the previous WinDbg settings file.
- **REQ-005**: If the installed WinDbg predates the minimum MCP version or the proxy is absent, then the system shall reject Ensure without changing WinDbg settings.
- **REQ-006**: When no WinDbg session exposes an MCP service, the system shall report the manual service start instead of connecting.
- **REQ-007**: If several WinDbg sessions expose an MCP service, then the system shall require an explicit session process identifier.
- **REQ-008**: When the MCP server asks the client to classify protected debugger output, the system shall answer with one non-interactive agent call and record that call.
- **REQ-009**: If no sampling agent resolves, then the system shall report that protected operations return no output while keeping the installed state compliant.
- **REQ-010**: When the Tricky debug route runs, the system shall store the debugger output as case evidence and add one observation note.
- **REQ-011**: If the connected session withholds a requested tool, then the system shall name secure mode and the operator step instead of calling it.
- **REQ-012**: When a debugger command is requested, the system shall report a missing or unbreakable target before running any command.
- **REQ-013**: When a sampling client exists at its declared installation path, the system shall prefer that path over another copy found on the command path.

## Scope

Only MCP enablement, session access, and evidence routing are managed. WinDbg installation stays
with the Packages module. Starting the MCP service, secure mode, and cross-prompt-injection
mitigation stay operator-controlled in the WinDbg user interface. Under secure mode the connected
server withholds the target-lifecycle tools, so loading a dump or attaching stays an operator step. No AI client configuration file is
written, and no WSL distribution gains a route to the debugger.
