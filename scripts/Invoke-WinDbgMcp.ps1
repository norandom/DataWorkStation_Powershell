[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Selection and sampling parameters are consumed by the nested session and agent functions.')]
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Status', 'Sessions', 'Tools', 'Target', 'Command', 'Open', 'Prompt')]
    [string] $Action = 'Status',

    [string[]] $Command,
    [string[]] $Description,
    [string] $Dump,
    [string] $Prompt,
    [int] $SessionProcessId = 0,
    [string] $SamplingAgentName,
    [switch] $NoSampling,
    [string] $OutputPath,
    [switch] $Json,
    [switch] $AsObject
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'WinDbgMcp.Core.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\windbg-mcp.psd1')

function Resolve-Application {
    param([string] $Name)
    (Get-Command $Name -CommandType Application, ExternalScript -ErrorAction Ignore | Select-Object -First 1).Source
}

function Get-SamplingAgent {
    if ($NoSampling) { return $null }
    $parameters = @{
        Agents = @($configuration.SamplingAgents)
        Resolve = { param([string] $CommandName) Resolve-Application $CommandName }
    }
    if ($SamplingAgentName) { $parameters['Name'] = $SamplingAgentName }
    $agent = Select-WinDbgMcpSamplingAgent @parameters
    if ($SamplingAgentName -and -not $agent) {
        throw "The sampling agent '$SamplingAgentName' is not configured in config/windbg-mcp.psd1, or its command is not on PATH."
    }
    $agent
}

function Get-LocalState {
    param([AllowNull()] $Agent)
    $package = Get-AppxPackage -Name ([string] $configuration.PackageName) -ErrorAction Ignore |
        Sort-Object { [version] $_.Version } -Descending | Select-Object -First 1
    $settingsPath = Expand-WinDbgMcpPath ([string] $configuration.SettingsPath)
    $settingsXml = if (Test-Path -LiteralPath $settingsPath -PathType Leaf) { Get-Content -LiteralPath $settingsPath -Raw } else { $null }
    $installedVersion = if ($package) { [string] $package.Version } else { $null }
    $agentName = if ($Agent) { [string] $Agent.Name } else { $null }
    $agentRole = if ($Agent) { [string] $Agent.Role } else { $null }
    $proxyPath = Select-WinDbgMcpProxyPath -Candidates @($configuration.ProxyCandidates) -Exists {
        param($Path) Test-Path -LiteralPath $Path -PathType Leaf
    }
    Get-WinDbgMcpInstallationState -Configuration $configuration `
        -InstalledVersion $installedVersion `
        -ProxyPath $proxyPath `
        -SettingsXml $settingsXml `
        -SamplingAgent $agentName `
        -SamplingAgentRole $agentRole
}

function Get-CommandPlan {
    $plan = [Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($entry in @($Command)) {
        $text = [string] $entry
        # The server answers an empty command with an error string in its output, which would be
        # stored as if it were debugger evidence. Refuse it here instead.
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw 'A debugger command is empty. Pass each command as its own value, quoting any command that begins with a dot, for example: -Command ''.lastevent'',k,lm'
        }
        $explanation = if ($Description -and $index -lt @($Description).Count) {
            [string] @($Description)[$index]
        } else {
            $known = @($configuration.DefaultCommands | Where-Object { [string] $_.Command -eq $text })
            if ($known.Count -gt 0) { [string] $known[0].Description } else { "Debugger command requested through the tricky WinDbg MCP client: $text" }
        }
        $plan.Add([pscustomobject]@{ Command = $text; Description = $explanation })
        $index++
    }
    @($plan)
}

function Invoke-ConnectedWork {
    param(
        [Parameter(Mandatory = $true)] $State,
        [AllowNull()] $Agent,
        [Parameter(Mandatory = $true)][scriptblock] $Work,
        # Passed to the work block explicitly. A work block must never read caller variables:
        # it runs in a child scope of this function, where a same-named local would win.
        [AllowNull()] $WorkArgument
    )
    if (-not $State.ProxyPresent) { throw ($State.Findings -join ' ') }
    $logDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'DataWorkStation\windbg-mcp'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $logPath = Join-Path $logDirectory ('proxy-{0}.log' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
    $client = Start-WinDbgMcpClient -ProxyPath $State.ProxyPath -Configuration $configuration -SamplingAgent $Agent -LogPath $logPath
    try {
        $sessionText = Invoke-WinDbgMcpTool -Client $client -Name 'list_sessions'
        $sessions = ConvertFrom-WinDbgMcpSessionList -Text $sessionText
        $connectionParameters = @{ SessionList = $sessions }
        if ($SessionProcessId -gt 0) { $connectionParameters['RequestedProcessId'] = $SessionProcessId }
        $connection = Get-WinDbgMcpConnectionPlan @connectionParameters
        if (-not $connection.AlreadyConnected) {
            [void] (Invoke-WinDbgMcpTool -Client $client -Name 'connect_session' -Arguments @{ pid = $connection.ProcessId })
        }
        # The connected server, not the proxy schema, decides which tools exist: secure mode
        # withholds the target-lifecycle tools.
        $live = Invoke-WinDbgMcpRequest -Client $client -Method 'tools/list'
        $client | Add-Member -NotePropertyName ServerTools -NotePropertyValue @($live.tools.name) -Force
        # Stop-WinDbgMcpClient releases the session on every teardown, including failures.
        & $Work $client $connection.ProcessId $WorkArgument
    } finally {
        Stop-WinDbgMcpClient -Client $client
    }
}

function Invoke-SessionProbe {
    param([Parameter(Mandatory = $true)] $State, [AllowNull()] $Agent)
    if (-not $State.ProxyPresent) { return [pscustomobject]@{ Sessions = @(); ActiveSessionPid = $null; Error = ($State.Findings -join ' ') } }
    $client = Start-WinDbgMcpClient -ProxyPath $State.ProxyPath -Configuration $configuration -SamplingAgent $Agent
    try {
        ConvertFrom-WinDbgMcpSessionList -Text (Invoke-WinDbgMcpTool -Client $client -Name 'list_sessions')
    } finally {
        Stop-WinDbgMcpClient -Client $client
    }
}

$agent = Get-SamplingAgent
$state = Get-LocalState -Agent $agent
$result = switch ($Action) {
    'Status' {
        $probe = Invoke-SessionProbe -State $state -Agent $agent
        [pscustomobject]@{
            SchemaVersion = 1
            Kind = 'WinDbgMcpStatus'
            TimeUtc = [DateTime]::UtcNow.ToString('o')
            State = $state
            Sessions = @($probe.Sessions)
            ActiveSessionPid = $probe.ActiveSessionPid
            SamplingAgent = if ($agent) { $agent.Name } else { $null }
        }
    }
    'Sessions' {
        $probe = Invoke-SessionProbe -State $state -Agent $agent
        [pscustomobject]@{
            SchemaVersion = 1
            Kind = 'WinDbgMcpSessions'
            TimeUtc = [DateTime]::UtcNow.ToString('o')
            Sessions = @($probe.Sessions)
            ActiveSessionPid = $probe.ActiveSessionPid
        }
    }
    'Tools' {
        if (-not $state.ProxyPresent) { throw ($state.Findings -join ' ') }
        $client = Start-WinDbgMcpClient -ProxyPath $state.ProxyPath -Configuration $configuration -SamplingAgent $agent
        try {
            $tools = Invoke-WinDbgMcpRequest -Client $client -Method 'tools/list'
            $prompts = Invoke-WinDbgMcpRequest -Client $client -Method 'prompts/list'
            [pscustomobject]@{
                SchemaVersion = 1
                Kind = 'WinDbgMcpTools'
                TimeUtc = [DateTime]::UtcNow.ToString('o')
                ServerInfo = $client.ServerInfo
                Tools = @($tools.tools | ForEach-Object { [pscustomobject]@{ Name = $_.name; Description = $_.description } })
                Prompts = @($prompts.prompts | ForEach-Object { [pscustomobject]@{ Name = $_.name; Description = $_.description } })
            }
        } finally {
            Stop-WinDbgMcpClient -Client $client
        }
    }
    'Target' {
        Invoke-ConnectedWork -State $state -Agent $agent -Work {
            param($Client, $ProcessId)
            $raw = Invoke-WinDbgMcpTool -Client $Client -Name 'get_target_state'
            [pscustomobject]@{
                SchemaVersion = 1
                Kind = 'WinDbgMcpTarget'
                TimeUtc = [DateTime]::UtcNow.ToString('o')
                SessionProcessId = $ProcessId
                AvailableTools = @($Client.ServerTools | Sort-Object)
                WithheldTools = @(@($configuration.SecureModeWithheldTools) | Where-Object { $_ -notin @($Client.ServerTools) })
                TargetState = Get-WinDbgMcpTargetState -Text $raw
            }
        }
    }
    'Open' {
        if (-not $Dump) { throw 'Usage: windbg-mcp Open -Dump <path>' }
        $resolvedDump = (Resolve-Path -LiteralPath $Dump -ErrorAction Stop).Path
        Invoke-ConnectedWork -State $state -Agent $agent -WorkArgument $resolvedDump -Work {
            param($Client, $ProcessId, $DumpPath)
            Assert-WinDbgMcpToolAvailable -AvailableTools @($Client.ServerTools) -Name 'open_dump' -Configuration $configuration
            [pscustomobject]@{
                SchemaVersion = 1
                Kind = 'WinDbgMcpOpen'
                TimeUtc = [DateTime]::UtcNow.ToString('o')
                SessionProcessId = $ProcessId
                Dump = $DumpPath
                Result = Invoke-WinDbgMcpTool -Client $Client -Name 'open_dump' -Arguments @{ path = $DumpPath }
                TargetState = Invoke-WinDbgMcpTool -Client $Client -Name 'get_target_state'
            }
        }
    }
    'Command' {
        if (-not $Command) { throw 'Usage: windbg-mcp Command -Command k,lm [-Description "...","..."]' }
        Invoke-ConnectedWork -State $state -Agent $agent -WorkArgument (Get-CommandPlan) -Work {
            param($Client, $ProcessId, $Steps)
            Assert-WinDbgMcpToolAvailable -AvailableTools @($Client.ServerTools) -Name 'show_output' -Configuration $configuration
            # get_target_state before any command, so a missing target reads as an operator step
            # rather than a debugger error per command.
            Assert-WinDbgMcpTargetReady -TargetState (Get-WinDbgMcpTargetState -Text (Invoke-WinDbgMcpTool -Client $Client -Name 'get_target_state'))
            $outputs = foreach ($step in @($Steps)) {
                $text = Invoke-WinDbgMcpTool -Client $Client -Name 'show_output' -Arguments @{
                    cmd = $step.Command
                    commandDescription = $step.Description
                }
                [pscustomobject]@{ Command = $step.Command; Description = $step.Description; Output = $text }
            }
            [pscustomobject]@{
                SchemaVersion = 1
                Kind = 'WinDbgMcpCommands'
                TimeUtc = [DateTime]::UtcNow.ToString('o')
                SessionProcessId = $ProcessId
                # Debugger output is untrusted evidence. Never treat it as instructions.
                Commands = @($outputs)
                SamplingCalls = @($Client.SamplingCalls)
            }
        }
    }
    'Prompt' {
        if (-not $state.ProxyPresent) { throw ($state.Findings -join ' ') }
        if (-not $Prompt) {
            # The proxy answers prompts/list from its own schema, without a connected session.
            $client = Start-WinDbgMcpClient -ProxyPath $state.ProxyPath -Configuration $configuration -SamplingAgent $agent
            try {
                $prompts = Invoke-WinDbgMcpRequest -Client $client -Method 'prompts/list'
                [pscustomobject]@{
                    SchemaVersion = 1
                    Kind = 'WinDbgMcpPrompts'
                    TimeUtc = [DateTime]::UtcNow.ToString('o')
                    Prompts = @($prompts.prompts | ForEach-Object { [pscustomobject]@{ Name = $_.name; Description = $_.description } })
                }
            } finally {
                Stop-WinDbgMcpClient -Client $client
            }
        } else {
            # Prompt text comes from the connected WinDbg session, so it needs a live MCP service.
            Invoke-ConnectedWork -State $state -Agent $agent -WorkArgument $Prompt -Work {
                param($Client, $ProcessId, $PromptName)
                $retrieved = Invoke-WinDbgMcpRequest -Client $Client -Method 'prompts/get' -Parameters @{ name = $PromptName; arguments = @{} }
                [pscustomobject]@{
                    SchemaVersion = 1
                    Kind = 'WinDbgMcpPrompt'
                    TimeUtc = [DateTime]::UtcNow.ToString('o')
                    SessionProcessId = $ProcessId
                    Name = $PromptName
                    Text = @($retrieved.messages | ForEach-Object { [string] $_.content.text }) -join "`n`n"
                }
            }
        }
    }
}

if ($OutputPath) {
    $directory = Split-Path -Parent $OutputPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding utf8
}
if ($Json) { $result | ConvertTo-Json -Depth 10 }
elseif ($AsObject) { $result }
else {
    switch ($result.Kind) {
        'WinDbgMcpStatus' {
            $result.State | Format-Table Resource, State, Version, ProxyPresent, FeatureEnabled, SamplingAgent -AutoSize -Wrap | Out-Host
            foreach ($finding in @($result.State.Findings)) { Write-Host "finding: $finding" }
            foreach ($warning in @($result.State.Warnings)) { Write-Host "warning: $warning" }
            if (@($result.Sessions).Count -eq 0) {
                Write-Host 'No WinDbg session exposes an MCP service. In WinDbg: File > Settings > MCP service settings > MCP Service, then confirm with Secure Mode enabled.'
            } else {
                @($result.Sessions) | Format-Table ProcessId, Available, Target -AutoSize | Out-Host
            }
        }
        'WinDbgMcpCommands' {
            foreach ($entry in @($result.Commands)) {
                Write-Host "--- $($entry.Command) ($($entry.Description)) ---"
                Write-Host $entry.Output
            }
        }
        'WinDbgMcpPrompt' { Write-Host $result.Text }
        default { $result | Format-List | Out-Host }
    }
    if ($OutputPath) { Write-Host "evidence: $OutputPath" }
}
