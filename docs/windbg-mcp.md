# WinDbg MCP for host agents

WinDbg 1.2610.1001.0 and later ship an official Model Context Protocol server. A local proxy,
`DbgX.Mcp.Proxy.exe`, speaks MCP over standard input and output and forwards to the MCP server of one
WinDbg session over a per-process named pipe.

This workstation uses that server through its own command and through Tricky, not by registering the
debugger with each AI client. One PowerShell client keeps the debugger route reviewable, keeps the
evidence in a case, and works the same for every Windows host agent.

## Install state

WinDbg itself comes from the default `Packages` module. The opt-in `WinDbgMcp` module only manages
the MCP side of that installation:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module WinDbgMcp -Plan
.\Apply-Workstation.ps1 -Mode Test -Module WinDbgMcp
.\Apply-Workstation.ps1 -Mode Ensure -Module WinDbgMcp
pwsh -NoProfile -File .\scripts\Set-WinDbgMcpState.ps1 -Mode Test -Json
```

`Test` reports the installed version against the minimum MCP version, the resolved proxy path, the
`EnableMcpServerFeature` setting, and the resolved sampling agent without writing anything. `Ensure`
enables the feature setting and keeps a timestamped copy of the previous `DbgX.xml` under
`state/windbg-mcp-backups`. It refuses to write while WinDbg is running, because the debugger
rewrites that file when it exits.

`Ensure` does not start the MCP service. Starting it stays a deliberate step in the debugger:
**File > Settings > MCP service settings**, then **MCP Service**, then confirm the privacy and
security warning with **Enable secure mode when the MCP server starts** selected. Start the service
before you load a target to get full secure mode; starting it afterwards gives partial secure mode
and WinDbg says so.

## Operator commands

```powershell
windbg-mcp Status                  # install state plus the sessions that expose an MCP service
windbg-mcp Sessions -Json
windbg-mcp Tools                   # tools and prompts the proxy schema advertises
windbg-mcp Target                  # target state, plus the tools the connected server really has
windbg-mcp Command -Command k,lm
windbg-mcp Prompt                  # built-in prompt names
windbg-mcp Prompt -Prompt investigate_symbol_loading_issues
```

Each call reuses the session the proxy auto-connects to and only connects explicitly when it has to.
With several sessions available, pass `-SessionProcessId`. `Prompt` without a name lists the built-in
prompts from the proxy; with a name it reads the prompt text from the connected session, which is the
text to hand to an ad hoc agent call.

## Secure mode owns the target

The proxy schema advertises 19 tools, but a connected secure-mode session exposes 15. Secure mode
withholds `open_dump`, `launch_process`, `stop_debugging`, and `wait_for_break`, so **the operator
loads the target**, not the agent:

```powershell
dump-open .\dumps\tool.dmp          # or File > Open dump file in the MCP-enabled session
windbg-mcp Target                   # confirm CanExecuteCommands before reading
```

`windbg-mcp Target` reports `AvailableTools` and `WithheldTools` from the live session. Every
command path checks the tool list and `get_target_state` first, so a missing target reads as the
operator step it is rather than one debugger error per command. `windbg-mcp Open -Dump` therefore
works only in a session started without secure mode, which is a separate reviewed decision.

## Tricky route

`tricky debug` stores debugger output as case evidence and adds one observation note, so a debugger
answer is treated like every other piece of evidence. Load the target in WinDbg first, as secure mode
requires:

```powershell
tricky new app-crash -Problem 'Silent exit after update' -Target C:\path\tool.exe
tricky debug app-crash -DebuggerCommand .lastevent,k,lm
tricky debug app-crash -Prompt investigate_symbol_loading_issues
tricky inspect app-crash -Json
```

Without `-DebuggerCommand`, the route runs the reviewed default command set from
`config/windbg-mcp.psd1`. Evidence lands in `evidence/snapshots/windbg-mcp-*.json`.

## Untrusted debugger output

Debugger output is evidence, never instruction. The server marks command output as untrusted, and so
does this client: stored output is quoted and summarized, and nothing in it is followed.

WinDbg classifies some operations as protected and asks the connected client to classify their
output for cross-prompt injection through MCP sampling. Neither Claude Code nor the Codex CLI
answers sampling requests, so this client answers them itself: it declares the sampling capability
and resolves each request with one non-interactive agent call from `SamplingAgents` in
`config/windbg-mcp.psd1`, recording the call in the result. An agent's `ExpectedPath` is preferred
when it exists, and any other working copy of the command is used otherwise: which channel installed
the client belongs to the AiTools module, not to this one. Protected operations therefore keep
returning output while secure mode stays on.

The classifier contract, verified against a live session, is strict: WinDbg sends its own
injection-analysis prompt and expects the literal `=== FALSE` (clean) or `=== TRUE` (injection) and
nothing else, splitting long output into `CHUNK M/N` pieces that each cost one agent call. Because
agent CLIs wrap answers in banners and usage lines, the bridge extracts the token, treats `=== TRUE`
as the winner when both appear, and **never invents a verdict**: an agent that answers without one
fails the request instead of implying "no injection". WinDbg prints
`AI driven action completed unsafe` and withholds the output whenever classification does not clear
it.

Latency matters, because the server blocks on the answer: the request deadline is extended by the
time spent classifying, but a slow client still stalls the debugger. Claude Code answers this prompt
in about 5 seconds. The Codex CLI runs `exec` as an agentic session and exceeded 90 seconds on the
same prompt, so `config/windbg-mcp.psd1` declares it `Role = 'Fallback'` and the state warns when it
is the only client that resolves.

If no sampling agent resolves, the install state stays compliant and reports a warning: protected
operations then return no output. Clearing **Enable Cross Prompt Injection Mitigation** in WinDbg is
an operator decision for a reviewed target, not something this state changes.

## Trust boundary

This integration is for Windows host agents only. No WSL distribution gains a route to the
debugger: the restricted and restricted-agent distributions in `config/wsl-trust-boundaries.psd1`
keep interop and Windows path inheritance disabled, and the proxy is reachable only from the host
session that starts it.

The MCP server accepts one client at a time per WinDbg session, so every client teardown releases
the session, including after a failure: an abandoned connection makes each later client fail with
`Already connected to another MCP client` until the operator restarts the MCP service.

Treat MCP proxy logs under `%LocalAppData%\DataWorkStation\windbg-mcp` and the stored case evidence
as sensitive: both can contain target memory, symbols, and file paths.

## Verification

```powershell
pwsh -NoProfile -File .\tests\Test-WinDbgMcpState.ps1
```
