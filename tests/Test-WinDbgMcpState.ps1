[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Resolver fixtures keep the injected command-name signature.')]
[CmdletBinding()]
param()

$script:RepositoryRoot = Split-Path -Parent $PSScriptRoot
$script:Runtime = (Get-Command pwsh.exe -ErrorAction Stop).Source
$script:Core = Join-Path $script:RepositoryRoot 'scripts\WinDbgMcp.Core.ps1'

function New-WinDbgMcpFixtureRoot {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('windbg-mcp-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $fixture
}

function Remove-WinDbgMcpFixtureRoot {
    param([string] $Path)
    $resolved = [IO.Path]::GetFullPath($Path)
    $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}

function New-WinDbgSettingsDocument {
    param([AllowNull()][object] $McpSetting)
    $namespace = if ($null -eq $McpSetting) { '' } else {
        "<Namespace Name=`"MCP`"><Setting Name=`"EnableMcpServerFeature`" Type=`"VT_BOOL`" Value=`"$McpSetting`" IsDefaultValue=`"true`"></Setting></Namespace>"
    }
    @"
<?xml version="1.0" encoding="utf-8"?>
<Settings>
  <Setting Name="EulaState" Value="accepted" />
  <XmlSetting Name="EngineSettings">
    <Settings Version="2">
      <Namespace Name="Debug"><Setting Name="Unrelated" Type="VT_BOOL" Value="true"></Setting></Namespace>
      $namespace
    </Settings>
  </XmlSetting>
</Settings>
"@
}

function Test-WinDbgMcpState {
    $ErrorActionPreference = 'Stop'
    $apply = Join-Path $script:RepositoryRoot 'Apply-Workstation.ps1'

    # REQ-001: the opt-in module stays out of the default and All plans.
    foreach ($selection in @(@(), @('-Module', 'All'))) {
        $plan = & $script:Runtime -NoProfile -File $apply -Mode Test -Plan -Json @selection | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or 'WinDbgMcp' -in $plan.ExecutionOrder.Name) { throw 'WinDbgMcp must be excluded from default and All plans.' }
    }

    # REQ-002: the explicit selection plans its Packages prerequisite first.
    $focused = & $script:Runtime -NoProfile -File $apply -Mode Ensure -Module WinDbgMcp -Plan -Json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) { throw 'The focused WinDbgMcp plan failed.' }
    $order = @($focused.ExecutionOrder.Name)
    if ($order[-1] -ne 'WinDbgMcp' -or 'Packages' -notin $order) { throw "Unexpected WinDbgMcp dependency plan: $($order -join ',')" }
    if ([array]::IndexOf($order, 'Packages') -ge [array]::IndexOf($order, 'WinDbgMcp')) { throw 'Packages must be planned before WinDbgMcp.' }

    # REQ-003: the reported state names the version gap, the proxy, and the feature setting.
    . $script:Core
    $configuration = Import-PowerShellDataFile (Join-Path $script:RepositoryRoot 'config\windbg-mcp.psd1')
    $old = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2502.24001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'true') -SamplingAgent 'Claude Code'
    if ($old.State -ne 'drift detected' -or $old.VersionSatisfied) { throw 'An MCP-incapable WinDbg version was accepted.' }
    if (@($old.Findings | Where-Object { $_ -match 'predates the MCP server' }).Count -ne 1) { throw 'The version finding is not actionable.' }
    $noProxy = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion ([string] $configuration.MinimumVersion) `
        -ProxyPath $null -SettingsXml (New-WinDbgSettingsDocument 'true') -SamplingAgent 'Claude Code'
    if ($noProxy.State -ne 'drift detected' -or $noProxy.ProxyPresent) { throw 'A missing proxy was accepted.' }
    $disabled = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'false') -SamplingAgent 'Claude Code'
    if ($disabled.FeatureEnabled -or $disabled.State -ne 'drift detected') { throw 'A disabled MCP feature setting was accepted.' }
    $compliant = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'true') -SamplingAgent 'Claude Code' |
        ConvertTo-Json -Depth 5 | ConvertFrom-Json
    if ($compliant.State -ne 'compliant' -or $compliant.Target -ne 'WindowsHost' -or $compliant.SchemaVersion -ne 1) { throw 'The compliant JSON contract failed.' }
    # An absent namespace keeps the shipped default, which enables the feature.
    $default = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument $null) -SamplingAgent 'Claude Code'
    if (-not $default.FeatureEnabled -or $default.FeatureWritten) { throw 'The shipped default was misreported.' }
    Write-Host 'PASS WinDbgMcpState'
}

function Test-WinDbgMcpSettings {
    $ErrorActionPreference = 'Stop'
    . $script:Core

    # REQ-004: the settings merge enables the feature, preserves unrelated namespaces, and repeats cleanly.
    $document = New-WinDbgSettingsDocument 'false'
    $updated = Set-WinDbgMcpSettingValue -Xml $document -Name 'EnableMcpServerFeature' -Value 'true'
    if ((Get-WinDbgMcpFeatureState -Xml $updated -Setting 'EnableMcpServerFeature').Enabled -ne $true) { throw 'The merge did not enable the feature.' }
    if ((([xml] $updated).SelectSingleNode("//Namespace[@Name='Debug']/Setting[@Name='Unrelated']")).GetAttribute('Value') -ne 'true') { throw 'The merge lost an unrelated namespace.' }
    if ((([xml] $updated).SelectSingleNode("//Namespace[@Name='MCP']/Setting[@Name='EnableMcpServerFeature']")).HasAttribute('IsDefaultValue')) { throw 'A reviewed value is still marked as a default.' }
    $repeated = Set-WinDbgMcpSettingValue -Xml $updated -Name 'EnableMcpServerFeature' -Value 'true'
    if (([xml] $repeated).OuterXml -cne ([xml] $updated).OuterXml) { throw 'The repeated merge is not idempotent.' }
    $created = Set-WinDbgMcpSettingValue -Xml (New-WinDbgSettingsDocument $null) -Name 'EnableMcpServerFeature' -Value 'true'
    if ((Get-WinDbgMcpFeatureState -Xml $created -Setting 'EnableMcpServerFeature').Present -ne $true) { throw 'The merge did not create the MCP namespace.' }

    $fixture = New-WinDbgMcpFixtureRoot
    try {
        $scripts = Join-Path $fixture 'scripts'
        $config = Join-Path $fixture 'config'
        New-Item -ItemType Directory -Path $scripts, $config | Out-Null
        Copy-Item -LiteralPath $script:Core -Destination $scripts
        $resource = Join-Path $scripts 'Set-WinDbgMcpState.ps1'
        Copy-Item -LiteralPath (Join-Path $script:RepositoryRoot 'scripts\Set-WinDbgMcpState.ps1') -Destination $resource
        $settingsFile = Join-Path $fixture 'DbgX.xml'
        New-WinDbgSettingsDocument 'false' | Set-Content -LiteralPath $settingsFile -Encoding utf8
        $configurationFile = Join-Path $config 'windbg-mcp.psd1'
        $template = Import-PowerShellDataFile (Join-Path $script:RepositoryRoot 'config\windbg-mcp.psd1')

        # REQ-005: an unreachable minimum version rejects Ensure and leaves the settings file alone.
        $before = Get-Content -LiteralPath $settingsFile -Raw
        Set-Content -LiteralPath $configurationFile -Encoding utf8 -Value (@"
@{
    SchemaVersion = 1
    PackageName = 'Microsoft.WinDbg'
    MinimumVersion = '9999.0.0.0'
    ProxyCandidates = @('$($settingsFile.Replace("'", "''"))')
    SettingsPath = '$($settingsFile.Replace("'", "''"))'
    BackupDirectory = 'state'
    FeatureSetting = 'EnableMcpServerFeature'
    Target = 'WindowsHost'
    SamplingAgents = @()
    ProtocolVersion = '$($template.ProtocolVersion)'
    ClientName = 'test'
    RequestTimeoutSeconds = 30
    HandshakeTimeoutSeconds = 15
    DefaultCommands = @()
}
"@)
        $rejected = & $script:Runtime -NoProfile -File $resource -Mode Ensure 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $rejected -notmatch 'or later is required') { throw 'Ensure accepted an MCP-incapable WinDbg version.' }
        if ((Get-Content -LiteralPath $settingsFile -Raw) -cne $before) { throw 'A rejected Ensure changed the WinDbg settings.' }

        # REQ-003: Test mode reports the drift without writing.
        Set-Content -LiteralPath $configurationFile -Encoding utf8 -Value ((Get-Content -LiteralPath $configurationFile -Raw) -replace "9999\.0\.0\.0", '1.0.0.0')
        $test = & $script:Runtime -NoProfile -File $resource -Mode Test -Json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 1 -or $test.FeatureEnabled -or $test.State -ne 'drift detected') { throw 'Test mode did not report the disabled feature as drift.' }
        if ((Get-Content -LiteralPath $settingsFile -Raw) -cne $before) { throw 'Test mode changed the WinDbg settings.' }

        # REQ-004: Ensure enables the feature and keeps a copy, unless a live WinDbg owns the file.
        $output = & $script:Runtime -NoProfile -File $resource -Mode Ensure -Json 2>&1 | Out-String
        if (@(Get-Process -Name 'DbgX.Shell', 'WinDbgX' -ErrorAction Ignore).Count -gt 0) {
            if ($output -notmatch 'WinDbg is running') { throw 'Ensure wrote settings while WinDbg was running.' }
            if ((Get-Content -LiteralPath $settingsFile -Raw) -cne $before) { throw 'Ensure changed settings while WinDbg was running.' }
        } else {
            $ensured = $output | ConvertFrom-Json
            if (-not $ensured.FeatureEnabled -or $ensured.State -ne 'compliant') { throw 'Ensure did not reach a compliant state.' }
            if (-not (Test-Path -LiteralPath $ensured.SettingsBackup -PathType Leaf)) { throw 'Ensure did not keep a settings backup.' }
            $afterFirst = Get-Content -LiteralPath $settingsFile -Raw
            $again = & $script:Runtime -NoProfile -File $resource -Mode Ensure -Json | ConvertFrom-Json
            if ($again.SettingsBackup) { throw 'A compliant Ensure wrote the settings file again.' }
            if ((Get-Content -LiteralPath $settingsFile -Raw) -cne $afterFirst) { throw 'Repeated Ensure is not idempotent.' }
        }
    } finally {
        Remove-WinDbgMcpFixtureRoot $fixture
    }
    Write-Host 'PASS WinDbgMcpSettings'
}

function Test-WinDbgMcpSessions {
    $ErrorActionPreference = 'Stop'
    . $script:Core

    # REQ-006: no MCP service means an actionable report, not a connection attempt.
    $empty = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[],"activeSessionPid":null}'
    if (@($empty.Sessions).Count -ne 0 -or $null -ne $empty.ActiveSessionPid) { throw 'An empty session list was misparsed.' }
    try {
        [void] (Select-WinDbgMcpSession -SessionList $empty)
        throw 'An empty session list was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch 'MCP service settings') { throw "The empty-session error is not actionable: $($_.Exception.Message)" }
    }

    # The proxy auto-connects to a single session and then reports it unavailable, with
    # isCurrentSession set. Field names follow the live DbgX.Mcp.Proxy contract.
    $autoConnected = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[{"pid":26508,"pipeName":"WinDbg-MCP-26508","windowTitle":"WinDbg 1.2610.1001.0","startTime":"2026-10-11T09:37:54.5084097Z","isCurrentSession":true,"isAvailable":false,"unavailableReason":"Already connected to this proxy session."}],"activeSessionPid":26508}'
    $session = @($autoConnected.Sessions)[0]
    if (-not $session.Available -or -not $session.Connected) { throw 'The auto-connected session was treated as unusable.' }
    if ($session.Target -ne 'WinDbg 1.2610.1001.0' -or $session.PipeName -ne 'WinDbg-MCP-26508') { throw 'The session descriptor lost its identity fields.' }
    $plan = Get-WinDbgMcpConnectionPlan -SessionList $autoConnected
    if ($plan.ProcessId -ne 26508 -or -not $plan.AlreadyConnected) { throw 'The plan would connect a session the proxy already owns.' }
    $explicitPlan = Get-WinDbgMcpConnectionPlan -SessionList $autoConnected -RequestedProcessId 26508
    if (-not $explicitPlan.AlreadyConnected) { throw 'An explicit selection of the connected session would reconnect it.' }

    # A session held elsewhere stays unusable, and its reason reaches the operator.
    $blocked = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[{"pid":99,"isCurrentSession":false,"isAvailable":false,"unavailableReason":"Already connected to another client."}],"activeSessionPid":null}'
    try {
        [void] (Get-WinDbgMcpConnectionPlan -SessionList $blocked)
        throw 'A session held by another client was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch 'Already connected to another client') { throw "The blocked-session error hides its reason: $($_.Exception.Message)" }
    }

    # REQ-007: several available sessions require an explicit selection.
    $many = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[{"pid":11,"isAvailable":true,"windowTitle":"a.dmp"},{"pid":22,"isAvailable":true,"windowTitle":"b.dmp"}],"activeSessionPid":null}'
    try {
        [void] (Select-WinDbgMcpSession -SessionList $many)
        throw 'An ambiguous session list was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch 'SessionProcessId') { throw "The ambiguous-session error does not name the selection: $($_.Exception.Message)" }
    }
    if ((Select-WinDbgMcpSession -SessionList $many -RequestedProcessId 22) -ne 22) { throw 'An explicit session was not honoured.' }
    try {
        [void] (Select-WinDbgMcpSession -SessionList $many -RequestedProcessId 33)
        throw 'An unknown session was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch '33') { throw 'The unknown-session error does not name the request.' }
    }
    $single = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[{"pid":44,"isAvailable":true,"windowTitle":"c.dmp"},{"pid":55,"isAvailable":false,"isCurrentSession":false,"windowTitle":"d.dmp"}],"activeSessionPid":null}'
    if ((Select-WinDbgMcpSession -SessionList $single) -ne 44) { throw 'The single available session was not selected.' }
    $active = ConvertFrom-WinDbgMcpSessionList -Text '{"sessions":[{"pid":66,"isAvailable":true},{"pid":77,"isAvailable":true}],"activeSessionPid":77}'
    if ((Select-WinDbgMcpSession -SessionList $active) -ne 77) { throw 'The already active session was not preferred.' }
    $failed = ConvertFrom-WinDbgMcpToolResult -Result ([pscustomobject]@{ isError = $true; content = @([pscustomobject]@{ type = 'text'; text = 'no upstream server' }) })
    if (-not $failed.IsError -or $failed.Text -ne 'no upstream server') { throw 'A tool error was not surfaced.' }
    Write-Host 'PASS WinDbgMcpSessions'
}

function Test-WinDbgMcpSecureModeBoundary {
    $ErrorActionPreference = 'Stop'
    . $script:Core
    $configuration = Import-PowerShellDataFile (Join-Path $script:RepositoryRoot 'config\windbg-mcp.psd1')
    # A live secure-mode session exposes these 15 tools and withholds target lifecycle.
    $secureModeTools = @(
        'get_output_history', 'new_script', 'get_source_code', 'set_script_content', 'execute_script',
        'get_logs', 'get_target_state', 'get_script_content', 'display_query', 'request_break',
        'get_source_from_expression', 'show_output', 'connect_session', 'list_sessions', 'disconnect_session'
    )

    # REQ-011: a withheld tool names secure mode and the operator step instead of being called.
    foreach ($withheld in @($configuration.SecureModeWithheldTools)) {
        if ($withheld -in $secureModeTools) { throw "Tool '$withheld' is not actually withheld by secure mode." }
        try {
            Assert-WinDbgMcpToolAvailable -AvailableTools $secureModeTools -Name $withheld -Configuration $configuration
            throw "A withheld tool '$withheld' was accepted."
        } catch {
            $message = $_.Exception.Message
            if ($message -notmatch 'Secure mode withholds' -or $message -notmatch 'dump-open') { throw "The withheld-tool error is not actionable: $message" }
        }
    }
    foreach ($required in @($configuration.RequiredTools)) {
        if ($required -notin $secureModeTools) { throw "Required tool '$required' is not available under secure mode." }
        Assert-WinDbgMcpToolAvailable -AvailableTools $secureModeTools -Name $required -Configuration $configuration
    }
    try {
        Assert-WinDbgMcpToolAvailable -AvailableTools $secureModeTools -Name 'invented_tool' -Configuration $configuration
        throw 'An unknown tool was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch 'Available tools') { throw 'The unknown-tool error does not list what exists.' }
    }

    # REQ-012: a missing or unbreakable target is reported before any command runs.
    $noTarget = Get-WinDbgMcpTargetState -Text '{"targetType":"NoTarget","runningState":"NoTarget","isLive":false,"isDump":false,"isTtd":false,"canExecuteCommands":false,"effectiveArchitecture":"Other"}'
    if ($noTarget.HasTarget -or $noTarget.CanExecuteCommands) { throw 'An empty session was reported as debuggable.' }
    try {
        Assert-WinDbgMcpTargetReady -TargetState $noTarget
        throw 'A session without a target was accepted.'
    } catch {
        if ($_.Exception.Message -notmatch 'no debug target' -or $_.Exception.Message -notmatch 'dump-open') { throw "The missing-target error is not actionable: $($_.Exception.Message)" }
    }
    $running = Get-WinDbgMcpTargetState -Text '{"targetType":"Live","runningState":"Running","isLive":true,"isDump":false,"isTtd":false,"canExecuteCommands":false}'
    try {
        Assert-WinDbgMcpTargetReady -TargetState $running
        throw 'A running target was accepted for command execution.'
    } catch {
        if ($_.Exception.Message -notmatch 'Break into the target') { throw 'The running-target error does not name the operator step.' }
    }
    $dump = Get-WinDbgMcpTargetState -Text '{"targetType":"Dump","runningState":"Break","isLive":false,"isDump":true,"isTtd":false,"canExecuteCommands":true,"effectiveArchitecture":"X64"}'
    if (-not $dump.IsDump -or -not $dump.CanExecuteCommands -or $dump.Architecture -ne 'X64') { throw 'A loaded dump was misreported.' }
    Assert-WinDbgMcpTargetReady -TargetState $dump

    # REQ-013: the declared installation path wins when it exists; any other copy still works.
    # Which channel installed the client is the AiTools module's concern, not this module's.
    $declared = Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve {
        param([string] $CommandName)
        # Both the declared path and a bare command resolve; the declared path must win.
        if ($CommandName -match 'claude') { $CommandName } else { $null }
    }
    if ($declared.Name -ne 'Claude Code' -or $declared.Source -notmatch '\.local\\bin\\claude\.exe$') { throw 'The declared installation path was not preferred.' }
    $elsewhere = Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve {
        param([string] $CommandName)
        if ($CommandName -eq 'claude') { 'C:\elsewhere\claude.exe' } else { $null }
    }
    if ($elsewhere.Name -ne 'Claude Code' -or $elsewhere.Source -ne 'C:\elsewhere\claude.exe') { throw 'A working client outside the declared path was refused.' }
    $sanctioned = $declared
    if ($sanctioned.PromptVia -ne 'StandardInput') { throw 'The prompt channel was lost.' }
    if ($sanctioned.Role -ne 'Primary') { throw 'The verified classifier is not declared as the primary agent.' }

    # A fallback-only resolution stays compliant but must say that protected operations will stall.
    $fallbackOnly = Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve {
        param([string] $CommandName)
        if ($CommandName -match 'codex') { 'C:\Users\x\.local\bin\codex.cmd' } else { $null }
    }
    if ($fallbackOnly.Role -ne 'Fallback') { throw 'The slow classifier is not declared as a fallback.' }
    $onFallback = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'true') `
        -SamplingAgent $fallbackOnly.Name -SamplingAgentRole $fallbackOnly.Role
    if ($onFallback.State -ne 'compliant') { throw 'A fallback agent must not fail the installed state.' }
    if (@($onFallback.Warnings | Where-Object { $_ -match 'fallback' -and $_ -match 'Module AiTools' }).Count -ne 1) {
        throw 'The fallback warning does not name the remedy.'
    }
    $onPrimary = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'true') `
        -SamplingAgent 'Claude Code' -SamplingAgentRole 'Primary'
    if (@($onPrimary.Warnings).Count -ne 0) { throw 'A primary agent must not warn.' }
    Write-Host 'PASS WinDbgMcpSecureModeBoundary'
}

function Test-WinDbgMcpSampling {
    $ErrorActionPreference = 'Stop'
    . $script:Core
    $configuration = Import-PowerShellDataFile (Join-Path $script:RepositoryRoot 'config\windbg-mcp.psd1')

    # REQ-009: a missing sampling agent warns about protected operations without failing the state.
    $withoutAgent = Get-WinDbgMcpInstallationState -Configuration $configuration -InstalledVersion '1.2611.1001.0' `
        -ProxyPath 'C:\proxy\DbgX.Mcp.Proxy.exe' -SettingsXml (New-WinDbgSettingsDocument 'true') -SamplingAgent $null
    if ($withoutAgent.State -ne 'compliant') { throw 'A missing sampling agent must not fail the installed state.' }
    if (@($withoutAgent.Warnings | Where-Object { $_ -match 'protected operation' }).Count -ne 1) { throw 'The sampling warning is missing.' }

    $resolvable = Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve {
        param([string] $CommandName)
        if ($CommandName -eq 'codex') { 'C:\tools\codex.exe' } else { $null }
    }
    if ($resolvable.Name -ne 'Codex CLI' -or $resolvable.Source -ne 'C:\tools\codex.exe') { throw 'Agent resolution skipped the available client.' }
    if ($null -ne (Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve { param($CommandName) $null })) { throw 'An unresolvable agent was returned.' }
    $named = Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Name 'Codex CLI' -Resolve { param($CommandName) "C:\tools\$CommandName.exe" }
    if ($named.Name -ne 'Codex CLI') { throw 'An explicitly named agent was not honoured.' }

    $prompt = Get-WinDbgMcpSamplingPrompt -Parameters ([pscustomobject]@{
        systemPrompt = 'Classify the debugger output.'
        messages = @(
            [pscustomobject]@{ role = 'user'; content = [pscustomobject]@{ type = 'text'; text = 'kd> !analyze -v' } }
            [pscustomobject]@{ role = 'assistant'; content = @([pscustomobject]@{ type = 'text'; text = 'safe' }) }
        )
    })
    if ($prompt -notmatch 'Classify the debugger output' -or $prompt -notmatch '\[user\] kd> !analyze -v' -or $prompt -notmatch '\[assistant\] safe') {
        throw "The sampling prompt lost content: $prompt"
    }
    $reply = New-WinDbgMcpSamplingResult -Text 'benign' -Model 'Codex CLI' | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    if ($reply.role -ne 'assistant' -or $reply.content.text -ne 'benign' -or $reply.stopReason -ne 'endTurn') { throw 'The sampling reply contract failed.' }

    # The classifier contract is one literal token, and agent CLIs wrap it in their own chrome.
    if ((Get-WinDbgMcpSamplingVerdict -Text "thinking...`n=== FALSE`ntokens used: 812") -ne '=== FALSE') { throw 'A verdict surrounded by agent chrome was not extracted.' }
    if ((Get-WinDbgMcpSamplingVerdict -Text '===FALSE') -ne '=== FALSE') { throw 'A verdict without the inner space was not extracted.' }
    if ((Get-WinDbgMcpSamplingVerdict -Text '=== false') -ne '=== FALSE') { throw 'A lowercase verdict was not normalized.' }
    if ((Get-WinDbgMcpSamplingVerdict -Text "=== FALSE then `n=== TRUE") -ne '=== TRUE') { throw 'An injection verdict must win over a clean one.' }
    if ($null -ne (Get-WinDbgMcpSamplingVerdict -Text 'I cannot help with that.')) { throw 'A missing verdict must not be invented.' }
    if ($null -ne (Get-WinDbgMcpSamplingVerdict -Text $null)) { throw 'Empty agent output must not produce a verdict.' }

    # REQ-008: a protected-output request is answered with exactly one recorded agent call.
    $writer = [IO.StringWriter]::new()
    $client = [pscustomobject]@{
        Process = [pscustomobject]@{ StandardInput = $writer; HasExited = $false }
        Configuration = $configuration
        SamplingAgent = [pscustomobject]@{
            Name = 'Fixture agent'
            Command = 'pwsh'
            Source = $script:Runtime
            # Consumes the prompt and answers with the contract token plus realistic chrome.
            Arguments = @('-NoProfile', '-Command', '[void][Console]::In.ReadToEnd(); "classifying..."; "=== FALSE"')
            PromptVia = 'StandardInput'
            TimeoutSeconds = 60
        }
        SamplingCalls = [Collections.Generic.List[object]]::new()
        SamplingSeconds = 0.0
    }
    $request = [pscustomobject]@{
        jsonrpc = '2.0'
        id = 7
        method = 'sampling/createMessage'
        params = [pscustomobject]@{ messages = @([pscustomobject]@{ role = 'user'; content = [pscustomobject]@{ type = 'text'; text = 'suspect output' } }) }
    }
    Resolve-WinDbgMcpServerMessage -Client $client -Message $request
    $answer = $writer.ToString().Trim() | ConvertFrom-Json
    if ($answer.id -ne 7 -or $answer.result.content.text -ne '=== FALSE') { throw "The sampling bridge did not answer with the verdict: $($writer.ToString())" }
    if ($client.SamplingCalls.Count -ne 1 -or $client.SamplingCalls[0].Verdict -ne '=== FALSE') { throw 'The verdict was not recorded.' }
    if ($client.SamplingCalls[0].Failure) { throw 'A successful classification recorded a failure.' }
    if ($client.SamplingSeconds -le 0) { throw 'The time the server spent waiting was not accounted for.' }

    # An agent that answers without a verdict must fail the request, never imply "no injection".
    $silentWriter = [IO.StringWriter]::new()
    $silent = [pscustomobject]@{
        Process = [pscustomobject]@{ StandardInput = $silentWriter; HasExited = $false }
        Configuration = $configuration
        SamplingAgent = [pscustomobject]@{
            Name = 'Unhelpful agent'
            Command = 'pwsh'
            Source = $script:Runtime
            Arguments = @('-NoProfile', '-Command', '[void][Console]::In.ReadToEnd(); "I will not answer."')
            PromptVia = 'StandardInput'
            TimeoutSeconds = 60
        }
        SamplingCalls = [Collections.Generic.List[object]]::new()
        SamplingSeconds = 0.0
    }
    Resolve-WinDbgMcpServerMessage -Client $silent -Message $request
    $refused = $silentWriter.ToString().Trim() | ConvertFrom-Json
    if ($refused.result) { throw 'A missing verdict was reported as a successful classification.' }
    if ($refused.error.code -ne -32603 -or $refused.error.message -notmatch 'no .=== TRUE') { throw "The missing-verdict error is not explicit: $($refused.error.message)" }
    if ($silent.SamplingCalls[0].Verdict) { throw 'A verdict was recorded for an agent that gave none.' }

    # An unimplemented server request is refused rather than ignored.
    $other = [IO.StringWriter]::new()
    $plain = [pscustomobject]@{
        Process = [pscustomobject]@{ StandardInput = $other; HasExited = $false }
        Configuration = $configuration
        SamplingAgent = $null
        SamplingCalls = [Collections.Generic.List[object]]::new()
        SamplingSeconds = 0.0
    }
    Resolve-WinDbgMcpServerMessage -Client $plain -Message ([pscustomobject]@{ jsonrpc = '2.0'; id = 9; method = 'roots/list' })
    $refusal = $other.ToString().Trim() | ConvertFrom-Json
    if ($refusal.error.code -ne -32601) { throw 'An unsupported server request was not refused.' }
    Write-Host 'PASS WinDbgMcpSampling'
}

function Test-WinDbgMcpTrickyRoute {
    $ErrorActionPreference = 'Stop'
    $tricky = Join-Path $script:RepositoryRoot 'scripts\Invoke-Tricky.ps1'
    $fixture = New-WinDbgMcpFixtureRoot
    $previousTool = $env:TRICKY_WINDBG_MCP_TOOL
    try {
        # REQ-010: the route stores debugger output as case evidence and adds one observation note.
        $stub = Join-Path $fixture 'stub.ps1'
        Set-Content -LiteralPath $stub -Encoding utf8 -Value @'
[CmdletBinding()]
param(
    [string] $Action,
    [string[]] $Command,
    [string[]] $Description,
    [string] $Dump,
    [string] $Prompt,
    [int] $SessionProcessId = 0,
    [string] $OutputPath,
    [switch] $AsObject,
    [switch] $Json
)
$result = [pscustomobject]@{
    SchemaVersion = 1
    Kind = 'WinDbgMcpCommands'
    SessionProcessId = 4242
    Commands = @($Command | ForEach-Object { [pscustomobject]@{ Command = $_; Description = 'stub'; Output = "output of $_" } })
}
if ($OutputPath) { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8 }
if ($AsObject) { $result }
'@
        $env:TRICKY_WINDBG_MCP_TOOL = $stub
        $case = & $script:Runtime -NoProfile -File $tricky new windbg-route -Problem 'Route verification' -Root $fixture -Json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'The fixture case was not created.' }
        # -File cannot pass an array, so the route runs through -Command for the command list.
        $debug = & $script:Runtime -NoProfile -Command "& '$($tricky.Replace("'", "''"))' debug '$($case.Directory.Replace("'", "''"))' -DebuggerCommand k,lm -Json" | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) { throw 'The tricky debug route failed.' }
        if (@($debug.Steps).Count -ne 1 -or $debug.SessionProcessId -ne '4242') { throw 'The route did not report the debugged session.' }
        if (@($debug.Steps[0].Commands).Count -ne 2) { throw 'The route lost a debugger command.' }
        $evidence = @(Get-ChildItem -LiteralPath (Join-Path $case.Directory 'evidence\snapshots') -Filter 'windbg-mcp-commands-*.json')
        if ($evidence.Count -ne 1) { throw 'The route did not store exactly one evidence file.' }
        $stored = Get-Content -LiteralPath $evidence[0].FullName -Raw | ConvertFrom-Json
        if ($stored.Kind -ne 'WinDbgMcpCommands' -or @($stored.Commands)[0].Output -ne 'output of k') { throw 'The stored evidence lost the debugger output.' }
        $notes = @(Get-Content -LiteralPath (Join-Path $case.Directory 'notes.json') -Raw | ConvertFrom-Json)
        if ($notes.Count -ne 1 -or $notes[0].Type -ne 'Observation') { throw 'The route did not add exactly one observation note.' }
        if ($notes[0].Message -notmatch 'WinDbg MCP evidence captured' -or $notes[0].Path -ne $evidence[0].FullName) { throw 'The note does not reference the stored evidence.' }
        $inspection = & $script:Runtime -NoProfile -File $tricky inspect $case.Directory -Json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or $inspection.EvidenceCount -lt 1) { throw 'The stored evidence is invisible to tricky inspect.' }
    } finally {
        $env:TRICKY_WINDBG_MCP_TOOL = $previousTool
        Remove-WinDbgMcpFixtureRoot $fixture
    }
    Write-Host 'PASS WinDbgMcpTrickyRoute'
}

Test-WinDbgMcpState
Test-WinDbgMcpSettings
Test-WinDbgMcpSessions
Test-WinDbgMcpSecureModeBoundary
Test-WinDbgMcpSampling
Test-WinDbgMcpTrickyRoute
Write-Host 'WinDbg MCP state, settings, session selection, secure-mode boundary, sampling bridge, and tricky route tests passed.'
