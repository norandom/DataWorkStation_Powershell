@{
    SchemaVersion = 1
    ServiceName = 'DataWorkStationMemoryLimits'
    LimitGiB = 8
    PollMilliseconds = 500
    MachineEnvironment = @{ PYTEST_XDIST_AUTO_NUM_WORKERS = '3' }
    EarlyOom = @{
        Mode = 'Enforce'
        AvailablePhysicalPercent = 10
        CommitHeadroomPercent = 10
        EmergencyCommitHeadroomPercent = 3
        SustainSeconds = 3
        CooldownSeconds = 15
        MinimumCandidateMiB = 256
        # Layer 2 considers all user applications, independently of layer 1 targets below.
        # Windows images, critical processes, session zero and service accounts are always protected.
        ExcludedExecutables = @(
            'explorer.exe', 'dwm.exe', 'sihost.exe', 'ShellExperienceHost.exe'
            'StartMenuExperienceHost.exe', 'SearchHost.exe', 'RuntimeBroker.exe'
            'TextInputHost.exe', 'ApplicationFrameHost.exe', 'ctfmon.exe', 'LockApp.exe'
            'taskmgr.exe', 'conhost.exe', 'OpenConsole.exe', 'WindowsTerminal.exe'
            'pwsh.exe', 'powershell.exe', 'ProcessGovernor.exe', 'ProcessLasso.exe', 'MemoryLimits.exe'
        )
    }
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
