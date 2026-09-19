@{
    SchemaVersion = 1
    ServiceName = 'DataWorkStationMemoryLimits'
    LimitGiB = 8
    PollMilliseconds = 500
    MachineEnvironment = @{ PYTEST_XDIST_AUTO_NUM_WORKERS = '3' }
    Executables = @(
        'python.exe', 'pythonw.exe', 'python3.exe', 'python3.12.exe', 'python3.13.exe', 'python3.14.exe'
        'dotnet.exe'
        'codex.exe', 'claude.exe', 'opencode.exe', 'opencode-cli.exe'
        'agy.exe', 'grok.exe', 'copilot.exe', 'cline.exe'
    )
    # Shared runtimes are selected by their tool path/command, not by runtime name alone.
    RuntimeExecutables = @('node.exe', 'bun.exe', 'agent.exe')
    # AI sandboxes create independent job hierarchies. Cap the host process and
    # let selected Python/.NET descendants receive their own tree budgets.
    ProcessOnlyExecutables = @('codex.exe', 'claude.exe', 'opencode.exe', 'opencode-cli.exe', 'agy.exe', 'grok.exe', 'copilot.exe', 'cline.exe', 'node.exe', 'bun.exe', 'agent.exe')
    RuntimeMarkers = @('\cursor-agent\', '\node_modules\cline\', '\node_modules\@cline\', '\node_modules\@github\copilot\')
}
