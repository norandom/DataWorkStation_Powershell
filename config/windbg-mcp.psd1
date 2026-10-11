@{
    SchemaVersion = 1
    PackageName = 'Microsoft.WinDbg'
    MinimumVersion = '1.2610.1001.0'
    ProxyCandidates = @(
        '%LOCALAPPDATA%\Microsoft\WindowsApps\DbgX.Mcp.Proxy.exe'
        '%LOCALAPPDATA%\Microsoft\WindowsApps\Microsoft.WinDbg_8wekyb3d8bbwe\DbgX.Mcp.Proxy.exe'
    )
    SettingsPath = '%LOCALAPPDATA%\dbg\DbgX.xml'
    BackupDirectory = 'state\windbg-mcp-backups'
    FeatureSetting = 'EnableMcpServerFeature'
    # WinDbg writes secure-mode and cross-prompt-injection settings only after the operator
    # changes them in File > Settings > MCP service settings. They stay GUI-owned; this state
    # reports them and never writes them.
    ReportedSettings = @('EnableMcpServerFeature')
    ProtocolVersion = '2025-06-18'
    ClientName = 'tricky-windbg'
    RequestTimeoutSeconds = 120
    HandshakeTimeoutSeconds = 30
    # Host-only integration. WSL distributions reach the debugger through no route of their own;
    # see config/wsl-trust-boundaries.psd1 and docs/windbg-mcp.md#trust-boundary.
    Target = 'WindowsHost'
    SamplingAgents = @(
        @{
            Name = 'Claude Code'
            Command = 'claude'
            # Preferred when present; otherwise whatever the command resolves to on PATH is used.
            # The installation channel belongs to the AiTools module, not to this one.
            ExpectedPath = '%USERPROFILE%\.local\bin\claude.exe'
            # Measured against the live classifier prompt: about 5 seconds, exact verdict token.
            Role = 'Primary'
            Arguments = @('--print', '--permission-mode', 'plan')
            PromptVia = 'StandardInput'
            TimeoutSeconds = 90
        }
        @{
            Name = 'Codex CLI'
            Command = 'codex'
            ExpectedPath = '%USERPROFILE%\.local\bin\codex.cmd'
            # `codex exec` runs an agentic session and exceeded 90 seconds on the same prompt, so
            # protected operations stall with it. Kept as a fallback, reported as one.
            Role = 'Fallback'
            Arguments = @('exec', '--skip-git-repo-check')
            PromptVia = 'StandardInput'
            TimeoutSeconds = 90
        }
    )
    ConnectionTools = @('list_sessions', 'connect_session', 'disconnect_session')
    # Verified against a live secure-mode session: the connected server exposes 15 tools and
    # withholds target lifecycle, even though the proxy schema advertises those tools.
    RequiredTools = @('show_output', 'get_target_state', 'get_output_history', 'get_logs')
    SecureModeWithheldTools = @('open_dump', 'launch_process', 'stop_debugging', 'wait_for_break')
    DefaultCommands = @(
        @{ Command = '.lastevent'; Description = 'Shows the last debugger event, including the exception record.' }
        @{ Command = '|'; Description = 'Lists the debug targets of the session.' }
        @{ Command = 'k'; Description = 'Prints the call stack of the current thread.' }
        @{ Command = 'lm'; Description = 'Lists loaded modules with their symbol state.' }
    )
}
