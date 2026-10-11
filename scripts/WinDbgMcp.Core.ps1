# WinDbg MCP core. Pure evaluation helpers plus the stdio transport that speaks Model Context
# Protocol to DbgX.Mcp.Proxy.exe, which forwards to the MCP server of one WinDbg session.
# Dot-source this file; it defines functions only and mutates nothing on import.

function Expand-WinDbgMcpPath {
    param([AllowNull()][string] $Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    [Environment]::ExpandEnvironmentVariables($Value)
}

function Get-WinDbgMcpVersionState {
    param(
        [AllowNull()][string] $InstalledVersion,
        [Parameter(Mandatory = $true)][string] $MinimumVersion
    )
    $minimum = [version] $MinimumVersion
    $installed = $null
    if (-not [string]::IsNullOrWhiteSpace($InstalledVersion)) {
        [void][version]::TryParse($InstalledVersion, [ref] $installed)
    }
    [pscustomobject]@{
        Installed = $null -ne $installed
        Version = if ($installed) { $installed.ToString() } else { $null }
        MinimumVersion = $minimum.ToString()
        Satisfied = $null -ne $installed -and $installed -ge $minimum
    }
}

function Select-WinDbgMcpProxyPath {
    param(
        [Parameter(Mandatory = $true)][string[]] $Candidates,
        [Parameter(Mandatory = $true)][scriptblock] $Exists
    )
    foreach ($candidate in $Candidates) {
        $expanded = Expand-WinDbgMcpPath $candidate
        if (-not $expanded) { continue }
        if (& $Exists $expanded) { return $expanded }
    }
    $null
}

function Get-WinDbgMcpSettingValue {
    param(
        [Parameter(Mandatory = $true)][string] $Xml,
        [Parameter(Mandatory = $true)][string] $Name,
        [string] $Namespace = 'MCP'
    )
    $document = [xml] $Xml
    $node = $document.SelectSingleNode("//Namespace[@Name='$Namespace']/Setting[@Name='$Name']")
    if (-not $node) { return $null }
    [pscustomobject]@{
        Name = $Name
        Value = $node.GetAttribute('Value')
        IsDefaultValue = $node.GetAttribute('IsDefaultValue') -eq 'true'
    }
}

function Get-WinDbgMcpFeatureState {
    param(
        [AllowNull()][string] $Xml,
        [Parameter(Mandatory = $true)][string] $Setting
    )
    if ([string]::IsNullOrWhiteSpace($Xml)) {
        return [pscustomobject]@{ Present = $false; Value = $null; Enabled = $false; Default = $false }
    }
    $current = Get-WinDbgMcpSettingValue -Xml $Xml -Name $Setting
    if (-not $current) {
        # WinDbg writes the namespace on first use. An absent setting keeps the shipped default,
        # which enables the MCP server feature.
        return [pscustomobject]@{ Present = $false; Value = $null; Enabled = $true; Default = $true }
    }
    [pscustomobject]@{
        Present = $true
        Value = $current.Value
        Enabled = $current.Value -eq 'true'
        Default = $current.IsDefaultValue
    }
}

function Set-WinDbgMcpSettingValue {
    param(
        [Parameter(Mandatory = $true)][string] $Xml,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Value,
        [string] $Namespace = 'MCP'
    )
    $document = [xml] $Xml
    $parent = $document.SelectSingleNode("//Namespace[@Name='$Namespace']")
    if (-not $parent) {
        $settings = $document.SelectSingleNode('/Settings/XmlSetting[@Name="EngineSettings"]/Settings')
        if (-not $settings) { throw 'The WinDbg settings file does not expose an EngineSettings document.' }
        $parent = $document.CreateElement('Namespace')
        $parent.SetAttribute('Name', $Namespace)
        [void] $settings.AppendChild($parent)
    }
    $node = $parent.SelectSingleNode("Setting[@Name='$Name']")
    if (-not $node) {
        $node = $document.CreateElement('Setting')
        $node.SetAttribute('Name', $Name)
        $node.SetAttribute('Type', 'VT_BOOL')
        [void] $parent.AppendChild($node)
    }
    $node.SetAttribute('Value', $Value)
    if ($node.HasAttribute('IsDefaultValue')) { $node.RemoveAttribute('IsDefaultValue') }
    $document.OuterXml
}

function Get-WinDbgMcpInstallationState {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Configuration,
        [AllowNull()][string] $InstalledVersion,
        [AllowNull()][string] $ProxyPath,
        [AllowNull()][string] $SettingsXml,
        [AllowNull()][string] $SamplingAgent,
        [AllowNull()][string] $SamplingAgentRole
    )
    $version = Get-WinDbgMcpVersionState -InstalledVersion $InstalledVersion -MinimumVersion ([string] $Configuration.MinimumVersion)
    $feature = Get-WinDbgMcpFeatureState -Xml $SettingsXml -Setting ([string] $Configuration.FeatureSetting)
    $findings = [Collections.Generic.List[string]]::new()
    if (-not $version.Installed) {
        $findings.Add("$($Configuration.PackageName) is not installed. The default Packages module installs it with WinGet.")
    } elseif (-not $version.Satisfied) {
        $findings.Add("WinDbg $($version.Version) predates the MCP server. Upgrade to $($version.MinimumVersion) or later with the Packages module.")
    }
    if (-not $ProxyPath) {
        $findings.Add('DbgX.Mcp.Proxy.exe was not found. Reinstall or repair WinDbg, then run this state again.')
    }
    if (-not $feature.Enabled) {
        $findings.Add("The WinDbg setting '$($Configuration.FeatureSetting)' is disabled. Ensure mode re-enables it while WinDbg is closed.")
    }
    $warnings = [Collections.Generic.List[string]]::new()
    if (-not $SamplingAgent) {
        $warnings.Add('No sampling agent resolved. Cross-prompt-injection protection needs one ad hoc agent call per protected operation; without it those operations return no output.')
    } elseif ($SamplingAgentRole -eq 'Fallback') {
        $warnings.Add("The only resolved sampling agent is the fallback '$SamplingAgent', which exceeded the classification budget in testing, so protected operations are expected to stall. Install the primary client from its declared channel: .\Apply-Workstation.ps1 -Mode Ensure -Module AiTools")
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'WinDbgMcp'
        State = if ($findings.Count -eq 0) { 'compliant' } else { 'drift detected' }
        Target = [string] $Configuration.Target
        Package = [string] $Configuration.PackageName
        Version = $version.Version
        MinimumVersion = $version.MinimumVersion
        VersionSatisfied = $version.Satisfied
        ProxyPath = $ProxyPath
        ProxyPresent = [bool] $ProxyPath
        FeatureSetting = [string] $Configuration.FeatureSetting
        FeatureEnabled = $feature.Enabled
        FeatureWritten = $feature.Present
        SamplingAgent = $SamplingAgent
        SamplingAgentRole = $SamplingAgentRole
        Findings = @($findings)
        Warnings = @($warnings)
    }
}

function New-WinDbgMcpMessage {
    param(
        [AllowNull()][int] $Id,
        [Parameter(Mandatory = $true)][string] $Method,
        [AllowNull()][hashtable] $Parameters
    )
    $message = [ordered]@{ jsonrpc = '2.0'; method = $Method }
    if ($PSBoundParameters.ContainsKey('Id')) { $message['id'] = $Id }
    if ($Parameters) { $message['params'] = $Parameters }
    $message
}

function ConvertFrom-WinDbgMcpToolResult {
    param([Parameter(Mandatory = $true)] $Result)
    $text = @($Result.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string] $_.text }) -join "`n"
    [pscustomobject]@{
        IsError = [bool] $Result.isError
        Text = $text
    }
}

function ConvertFrom-WinDbgMcpSessionList {
    param([AllowNull()][string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return [pscustomobject]@{ Sessions = @(); ActiveSessionPid = $null }
    }
    $payload = $Text | ConvertFrom-Json
    $sessions = @($payload.sessions | ForEach-Object {
        # The proxy auto-connects to a single available session, and then reports it as
        # unavailable with isCurrentSession set. That session is still the one to use.
        $connected = [bool] $_.isCurrentSession
        $declared = if ($_.PSObject.Properties.Name -contains 'isAvailable') { [bool] $_.isAvailable } else { $true }
        [pscustomobject]@{
            ProcessId = [int] $_.pid
            Available = $declared -or $connected
            Connected = $connected
            Target = if ($_.windowTitle) { [string] $_.windowTitle } else { [string] $_.target }
            PipeName = [string] $_.pipeName
            StartTimeUtc = [string] $_.startTime
            UnavailableReason = [string] $_.unavailableReason
        }
    })
    [pscustomobject]@{
        Sessions = $sessions
        ActiveSessionPid = if ($null -ne $payload.activeSessionPid) { [int] $payload.activeSessionPid } else { $null }
    }
}

function Select-WinDbgMcpSession {
    param(
        [Parameter(Mandatory = $true)] $SessionList,
        [AllowNull()][int] $RequestedProcessId
    )
    $available = @($SessionList.Sessions | Where-Object Available)
    if ($PSBoundParameters.ContainsKey('RequestedProcessId') -and $RequestedProcessId -gt 0) {
        $match = @($available | Where-Object ProcessId -eq $RequestedProcessId)
        if ($match.Count -eq 0) {
            throw "WinDbg session $RequestedProcessId does not expose an available MCP service. Start the MCP service in that session, or omit -SessionProcessId."
        }
        return $match[0].ProcessId
    }
    if ($null -ne $SessionList.ActiveSessionPid) { return $SessionList.ActiveSessionPid }
    if ($available.Count -eq 0) {
        $blocked = @($SessionList.Sessions | Where-Object UnavailableReason | ForEach-Object { "$($_.ProcessId): $($_.UnavailableReason)" })
        $detail = if ($blocked.Count -gt 0) { " Unavailable sessions: $($blocked -join '; ')." } else { '' }
        throw "No WinDbg session exposes an MCP service. Open the target in WinDbg, then File > Settings > MCP service settings > MCP Service, and confirm the privacy and security warning with Secure Mode enabled.$detail"
    }
    if ($available.Count -gt 1) {
        $ids = @($available.ProcessId) -join ', '
        throw "Several WinDbg sessions expose an MCP service ($ids). Select one with -SessionProcessId."
    }
    $available[0].ProcessId
}

function Get-WinDbgMcpTargetState {
    param([AllowNull()][string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return [pscustomobject]@{ TargetType = 'Unknown'; HasTarget = $false; CanExecuteCommands = $false; IsDump = $false; IsTtd = $false; IsLive = $false }
    }
    $payload = $Text | ConvertFrom-Json
    [pscustomobject]@{
        TargetType = [string] $payload.targetType
        HasTarget = [string] $payload.targetType -ne 'NoTarget'
        CanExecuteCommands = [bool] $payload.canExecuteCommands
        IsDump = [bool] $payload.isDump
        IsTtd = [bool] $payload.isTtd
        IsLive = [bool] $payload.isLive
        RunningState = [string] $payload.runningState
        Architecture = [string] $payload.effectiveArchitecture
    }
}

function Assert-WinDbgMcpTargetReady {
    param([Parameter(Mandatory = $true)] $TargetState)
    if ($TargetState.CanExecuteCommands) { return }
    if (-not $TargetState.HasTarget) {
        throw 'The WinDbg session has no debug target. Secure mode keeps target lifecycle with the operator: load the dump or attach in WinDbg (for example with dump-open <path>), then run this command again.'
    }
    throw "The WinDbg target cannot execute commands right now (targetType=$($TargetState.TargetType), runningState=$($TargetState.RunningState)). Break into the target in WinDbg, then run this command again."
}

function Assert-WinDbgMcpToolAvailable {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]] $AvailableTools,
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][hashtable] $Configuration
    )
    if ($Name -in $AvailableTools) { return }
    if ($Name -in @($Configuration.SecureModeWithheldTools)) {
        throw "The connected WinDbg session does not expose '$Name'. Secure mode withholds the target-lifecycle tools ($(@($Configuration.SecureModeWithheldTools) -join ', ')), so the operator loads the target in WinDbg instead: dump-open <path>, or File > Open dump file. Running WinDbg without secure mode is a separate, reviewed decision."
    }
    throw "The connected WinDbg session does not expose '$Name'. Available tools: $(@($AvailableTools | Sort-Object) -join ', ')."
}

function Get-WinDbgMcpConnectionPlan {
    param(
        [Parameter(Mandatory = $true)] $SessionList,
        [AllowNull()][int] $RequestedProcessId
    )
    $parameters = @{ SessionList = $SessionList }
    if ($PSBoundParameters.ContainsKey('RequestedProcessId') -and $RequestedProcessId -gt 0) {
        $parameters['RequestedProcessId'] = $RequestedProcessId
    }
    $processId = Select-WinDbgMcpSession @parameters
    [pscustomobject]@{
        ProcessId = $processId
        # The proxy connects to a single available session on startup; connecting again fails.
        AlreadyConnected = $null -ne $SessionList.ActiveSessionPid -and [int] $SessionList.ActiveSessionPid -eq $processId
    }
}

function Get-WinDbgMcpSamplingPrompt {
    param([Parameter(Mandatory = $true)] $Parameters)
    $lines = [Collections.Generic.List[string]]::new()
    if ($Parameters.systemPrompt) { $lines.Add([string] $Parameters.systemPrompt) }
    foreach ($message in @($Parameters.messages)) {
        $role = [string] $message.role
        $content = $message.content
        $text = if ($content -is [array]) {
            @($content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string] $_.text }) -join "`n"
        } else {
            [string] $content.text
        }
        if ($text) { $lines.Add("[$role] $text") }
    }
    ($lines -join "`n`n").Trim()
}

function Get-WinDbgMcpSamplingVerdict {
    param([AllowNull()][string] $Text)
    # The classifier contract is one literal token. Agent CLIs wrap their answer in banners and
    # usage lines, so the token is extracted rather than assumed to be the whole output.
    # '=== TRUE' wins when both appear: blocking output is the safe direction.
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    if ($Text -match '===\s*TRUE') { return '=== TRUE' }
    if ($Text -match '===\s*FALSE') { return '=== FALSE' }
    $null
}

function New-WinDbgMcpSamplingResult {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string] $Text,
        [Parameter(Mandatory = $true)][string] $Model
    )
    [ordered]@{
        role = 'assistant'
        content = [ordered]@{ type = 'text'; text = $Text }
        model = $Model
        stopReason = 'endTurn'
    }
}

function Select-WinDbgMcpSamplingAgent {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]] $Agents,
        [Parameter(Mandatory = $true)][scriptblock] $Resolve,
        [AllowNull()][string] $Name
    )
    foreach ($agent in $Agents) {
        if ($Name -and [string] $agent.Name -ne $Name) { continue }
        # Prefer the declared installation path when it exists, otherwise use whatever the command
        # resolves to. Which channel installed the client is the AiTools module's concern.
        $source = $null
        $expected = Expand-WinDbgMcpPath ([string] $agent.ExpectedPath)
        if ($expected -and (& $Resolve $expected)) { $source = $expected }
        if (-not $source) { $source = & $Resolve ([string] $agent.Command) }
        if ($source) {
            return [pscustomobject]@{
                Name = [string] $agent.Name
                Command = [string] $agent.Command
                Source = [string] $source
                Arguments = @($agent.Arguments)
                PromptVia = if ($agent.PromptVia) { [string] $agent.PromptVia } else { 'StandardInput' }
                Role = if ($agent.Role) { [string] $agent.Role } else { 'Primary' }
                TimeoutSeconds = if ($agent.TimeoutSeconds) { [int] $agent.TimeoutSeconds } else { 120 }
            }
        }
    }
    $null
}

function Invoke-WinDbgMcpAgent {
    param(
        [Parameter(Mandatory = $true)] $Agent,
        [Parameter(Mandatory = $true)][string] $Prompt
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $fileName = [string] $Agent.Source
    $arguments = @($Agent.Arguments | ForEach-Object { [string] $_ })
    if ($fileName -match '\.(cmd|bat)$') {
        # CreateProcess cannot start a command script, so run it through the command processor.
        $arguments = @('/c', $fileName) + $arguments
        $fileName = if ($env:ComSpec) { $env:ComSpec } else { 'cmd.exe' }
    }
    if ($Agent.PromptVia -eq 'Argument') { $arguments += $Prompt }
    $startInfo.FileName = $fileName
    foreach ($argument in $arguments) { [void] $startInfo.ArgumentList.Add($argument) }
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($startInfo)
    try {
        if ($Agent.PromptVia -ne 'Argument') { $process.StandardInput.Write($Prompt) }
        $process.StandardInput.Close()
        $output = $process.StandardOutput.ReadToEndAsync()
        if (-not $process.WaitForExit([int] $Agent.TimeoutSeconds * 1000)) {
            $process.Kill($true)
            throw "Sampling agent '$($Agent.Name)' exceeded $($Agent.TimeoutSeconds) seconds."
        }
        [void] $output.Wait(5000)
        ([string] $output.Result).Trim()
    } finally {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
}

function Start-WinDbgMcpClient {
    param(
        [Parameter(Mandatory = $true)][string] $ProxyPath,
        [Parameter(Mandatory = $true)][hashtable] $Configuration,
        [AllowNull()] $SamplingAgent,
        [AllowNull()][string] $LogPath
    )
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ProxyPath
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($startInfo)
    $process.StandardInput.NewLine = "`n"
    $client = [pscustomobject]@{
        Process = $process
        Configuration = $Configuration
        SamplingAgent = $SamplingAgent
        NextId = 0
        Diagnostics = $process.StandardError.ReadToEndAsync()
        LogPath = $LogPath
        SamplingCalls = [Collections.Generic.List[object]]::new()
        SamplingSeconds = 0.0
        PendingRead = $null
    }
    $capabilities = [ordered]@{}
    if ($SamplingAgent) { $capabilities['sampling'] = [ordered]@{} }
    $handshake = Invoke-WinDbgMcpRequest -Client $client -Method 'initialize' -Parameters @{
        protocolVersion = [string] $Configuration.ProtocolVersion
        capabilities = $capabilities
        clientInfo = @{ name = [string] $Configuration.ClientName; version = '1.0.0' }
    } -TimeoutSeconds ([int] $Configuration.HandshakeTimeoutSeconds)
    Send-WinDbgMcpNotification -Client $client -Method 'notifications/initialized'
    $client | Add-Member -NotePropertyName ServerInfo -NotePropertyValue $handshake.serverInfo -PassThru
}

function Send-WinDbgMcpNotification {
    param(
        [Parameter(Mandatory = $true)] $Client,
        [Parameter(Mandatory = $true)][string] $Method,
        [AllowNull()][hashtable] $Parameters
    )
    $message = New-WinDbgMcpMessage -Method $Method -Parameters $Parameters
    $Client.Process.StandardInput.WriteLine(($message | ConvertTo-Json -Depth 12 -Compress))
    $Client.Process.StandardInput.Flush()
}

function Read-WinDbgMcpLine {
    param(
        [Parameter(Mandatory = $true)] $Client,
        [Parameter(Mandatory = $true)][DateTime] $Deadline,
        [Parameter(Mandatory = $true)][string] $PendingMethod
    )
    # One read task at a time. Abandoning a ReadLineAsync task would consume a line that no
    # caller ever observes, so the pending task is kept on the client between slices.
    if (-not $Client.PendingRead) { $Client.PendingRead = $Client.Process.StandardOutput.ReadLineAsync() }
    $remaining = [int] ($Deadline - [DateTime]::UtcNow).TotalMilliseconds
    if ($remaining -le 0) { return $null }
    if (-not $Client.PendingRead.Wait([Math]::Min(2000, $remaining))) { return $null }
    $line = $Client.PendingRead.Result
    $Client.PendingRead = $null
    if ($null -eq $line) {
        throw "The WinDbg MCP proxy closed its output while '$PendingMethod' was pending. $(Get-WinDbgMcpDiagnostics -Client $Client)"
    }
    $line
}

function Invoke-WinDbgMcpRequest {
    param(
        [Parameter(Mandatory = $true)] $Client,
        [Parameter(Mandatory = $true)][string] $Method,
        [AllowNull()][hashtable] $Parameters,
        [int] $TimeoutSeconds = 0
    )
    if ($TimeoutSeconds -le 0) { $TimeoutSeconds = [int] $Client.Configuration.RequestTimeoutSeconds }
    $Client.NextId++
    $id = $Client.NextId
    $message = New-WinDbgMcpMessage -Id $id -Method $Method -Parameters $Parameters
    $Client.Process.StandardInput.WriteLine(($message | ConvertTo-Json -Depth 12 -Compress))
    $Client.Process.StandardInput.Flush()
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $sampled = [double] $Client.SamplingSeconds
    while ([DateTime]::UtcNow -lt $deadline) {
        $line = Read-WinDbgMcpLine -Client $Client -Deadline $deadline -PendingMethod $Method
        if ([double] $Client.SamplingSeconds -gt $sampled) {
            $deadline = $deadline.AddSeconds([double] $Client.SamplingSeconds - $sampled)
            $sampled = [double] $Client.SamplingSeconds
        }
        if ($null -eq $line) { continue }
        if (-not $line.TrimStart().StartsWith('{')) { continue }
        $incoming = $line | ConvertFrom-Json
        if ($incoming.PSObject.Properties.Name -contains 'method') {
            Resolve-WinDbgMcpServerMessage -Client $Client -Message $incoming
            continue
        }
        if ([int] $incoming.id -ne $id) { continue }
        if ($incoming.PSObject.Properties.Name -contains 'error') {
            throw "The WinDbg MCP server rejected '$Method': $($incoming.error.message) (code $($incoming.error.code))"
        }
        return $incoming.result
    }
    throw "The WinDbg MCP server did not answer '$Method' within $TimeoutSeconds seconds."
}

function Resolve-WinDbgMcpServerMessage {
    param(
        [Parameter(Mandatory = $true)] $Client,
        [Parameter(Mandatory = $true)] $Message
    )
    $method = [string] $Message.method
    if ($Message.PSObject.Properties.Name -notcontains 'id') { return }
    if ($method -ne 'sampling/createMessage') {
        $response = [ordered]@{
            jsonrpc = '2.0'
            id = $Message.id
            error = [ordered]@{ code = -32601; message = "The tricky WinDbg MCP client does not implement '$method'." }
        }
        $Client.Process.StandardInput.WriteLine(($response | ConvertTo-Json -Depth 8 -Compress))
        $Client.Process.StandardInput.Flush()
        return
    }
    # Cross-prompt injection protection asks the client to classify debugger output. Answer it with
    # one ad hoc, non-interactive agent call so protected operations keep returning output while
    # secure mode stays on.
    $prompt = Get-WinDbgMcpSamplingPrompt -Parameters $Message.params
    $response = [ordered]@{ jsonrpc = '2.0'; id = $Message.id }
    if (-not $Client.SamplingAgent) {
        $response['error'] = [ordered]@{
            code = -32601
            message = 'This client has no sampling agent. Configure one in config/windbg-mcp.psd1, or clear Enable Cross Prompt Injection Mitigation in WinDbg after a security review.'
        }
    } else {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $verdict = $null
        $failure = $null
        try {
            $text = Invoke-WinDbgMcpAgent -Agent $Client.SamplingAgent -Prompt $prompt
            $verdict = Get-WinDbgMcpSamplingVerdict -Text $text
            if ($verdict) {
                $response['result'] = New-WinDbgMcpSamplingResult -Text $verdict -Model $Client.SamplingAgent.Name
            } else {
                # Never guess the verdict: a missing token must not become "no injection".
                $failure = "returned no '=== TRUE' or '=== FALSE' verdict"
            }
        } catch {
            $failure = $_.Exception.Message
        }
        if ($failure) {
            $response['error'] = [ordered]@{ code = -32603; message = "The sampling agent '$($Client.SamplingAgent.Name)' failed: $failure" }
        }
        $watch.Stop()
        # The server blocks on this answer, so the caller must not count it against its own budget.
        $Client.SamplingSeconds += $watch.Elapsed.TotalSeconds
        $Client.SamplingCalls.Add([pscustomobject]@{
            TimeUtc = [DateTime]::UtcNow.ToString('o')
            Agent = $Client.SamplingAgent.Name
            PromptLength = $prompt.Length
            Verdict = $verdict
            Failure = $failure
            Seconds = [math]::Round($watch.Elapsed.TotalSeconds, 1)
        })
    }
    $Client.Process.StandardInput.WriteLine(($response | ConvertTo-Json -Depth 8 -Compress))
    $Client.Process.StandardInput.Flush()
}

function Invoke-WinDbgMcpTool {
    param(
        [Parameter(Mandatory = $true)] $Client,
        [Parameter(Mandatory = $true)][string] $Name,
        [AllowNull()][hashtable] $Arguments,
        [int] $TimeoutSeconds = 0
    )
    $result = Invoke-WinDbgMcpRequest -Client $Client -Method 'tools/call' -TimeoutSeconds $TimeoutSeconds -Parameters @{
        name = $Name
        arguments = if ($Arguments) { $Arguments } else { @{} }
    }
    $converted = ConvertFrom-WinDbgMcpToolResult -Result $result
    if ($converted.IsError) { throw "The WinDbg MCP tool '$Name' failed: $($converted.Text)" }
    $converted.Text
}

function Get-WinDbgMcpDiagnostics {
    param([Parameter(Mandatory = $true)] $Client)
    if (-not $Client.Diagnostics.IsCompleted) { return 'Proxy diagnostics are still streaming.' }
    $text = [string] $Client.Diagnostics.Result
    if (-not $text) { return 'The proxy produced no diagnostics.' }
    @($text -split "`r?`n" | Where-Object { $_ } | Select-Object -Last 5) -join ' | '
}

function Stop-WinDbgMcpClient {
    param([Parameter(Mandatory = $true)] $Client)
    try {
        if (-not $Client.Process.HasExited) {
            # The WinDbg MCP server accepts one client per session, and the proxy auto-connects on
            # startup. An abandoned connection blocks every later client until the operator
            # restarts the MCP service, so release it even when this client never connected itself.
            try { [void] (Invoke-WinDbgMcpTool -Client $Client -Name 'disconnect_session' -TimeoutSeconds 15) } catch {
                Write-Verbose "Releasing the WinDbg session failed: $($_.Exception.Message)"
            }
            $Client.Process.StandardInput.Close()
            [void] $Client.Process.WaitForExit(5000)
        }
    } catch {
        Write-Verbose "The WinDbg MCP proxy did not shut down cleanly: $($_.Exception.Message)"
    } finally {
        if (-not $Client.Process.HasExited) { $Client.Process.Kill($true) }
        if ($Client.LogPath -and $Client.Diagnostics.IsCompleted) {
            [string] $Client.Diagnostics.Result | Set-Content -LiteralPath $Client.LogPath -Encoding utf8
        }
        $Client.Process.Dispose()
    }
}
