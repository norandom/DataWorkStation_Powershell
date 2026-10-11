[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'WinDbgMcp.Core.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\windbg-mcp.psd1')

function Get-InstalledWinDbgVersion {
    $package = Get-AppxPackage -Name ([string] $configuration.PackageName) -ErrorAction Ignore |
        Sort-Object { [version] $_.Version } -Descending |
        Select-Object -First 1
    if ($package) { [string] $package.Version } else { $null }
}

function Get-SettingsText {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    Get-Content -LiteralPath $Path -Raw
}

function Get-ResolvedSamplingAgent {
    Select-WinDbgMcpSamplingAgent -Agents @($configuration.SamplingAgents) -Resolve {
        param([string] $Command)
        (Get-Command $Command -CommandType Application, ExternalScript -ErrorAction Ignore |
            Select-Object -First 1).Source
    }
}

function Get-WinDbgMcpCurrentState {
    $settingsPath = Expand-WinDbgMcpPath ([string] $configuration.SettingsPath)
    $agent = Get-ResolvedSamplingAgent
    $agentName = if ($agent) { [string] $agent.Name } else { $null }
    $agentRole = if ($agent) { [string] $agent.Role } else { $null }
    $proxyPath = Select-WinDbgMcpProxyPath -Candidates @($configuration.ProxyCandidates) -Exists {
        param($Path) Test-Path -LiteralPath $Path -PathType Leaf
    }
    Get-WinDbgMcpInstallationState -Configuration $configuration `
        -InstalledVersion (Get-InstalledWinDbgVersion) `
        -ProxyPath $proxyPath `
        -SettingsXml (Get-SettingsText $settingsPath) `
        -SamplingAgent $agentName `
        -SamplingAgentRole $agentRole
}

function Backup-WinDbgSettings {
    param([string] $Path)
    $backupRoot = Join-Path $repositoryRoot ([string] $configuration.BackupDirectory)
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $backup = Join-Path $backupRoot ('DbgX-{0}.xml' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
    Copy-Item -LiteralPath $Path -Destination $backup
    $backup
}

function Set-WinDbgMcpFeature {
    $settingsPath = Expand-WinDbgMcpPath ([string] $configuration.SettingsPath)
    $text = Get-SettingsText $settingsPath
    if (-not $text) {
        throw "WinDbg has not written '$settingsPath' yet. Start WinDbg once, accept its licence, close it, and run Ensure again."
    }
    # WinDbg rewrites this file when it exits, so an open debugger would discard the change.
    if (@(Get-Process -Name 'DbgX.Shell', 'WinDbgX' -ErrorAction Ignore).Count -gt 0) {
        throw 'WinDbg is running. Close every WinDbg window before Ensure writes its MCP settings.'
    }
    $updated = Set-WinDbgMcpSettingValue -Xml $text -Name ([string] $configuration.FeatureSetting) -Value 'true'
    if ($updated -ceq $text) { return $null }
    $backup = Backup-WinDbgSettings -Path $settingsPath
    $updated | Set-Content -LiteralPath $settingsPath -Encoding utf8
    $backup
}

$result = Get-WinDbgMcpCurrentState
$backupPath = $null
if ($Mode -ne 'Test') {
    if (-not $result.VersionSatisfied) {
        throw "WinDbg $($result.MinimumVersion) or later is required for the MCP server. Run: .\Apply-Workstation.ps1 -Mode Ensure -Module Packages"
    }
    if (-not $result.ProxyPresent) {
        throw 'DbgX.Mcp.Proxy.exe is missing from the WinDbg package. Repair or reinstall WinDbg before enabling this module.'
    }
    if (-not $result.FeatureEnabled -or $Mode -eq 'Reinitialize') {
        $backupPath = Set-WinDbgMcpFeature
    }
    $result = Get-WinDbgMcpCurrentState
    if (-not $result.VersionSatisfied -or -not $result.ProxyPresent -or -not $result.FeatureEnabled) {
        throw 'The WinDbg MCP state did not become compliant.'
    }
}
$result | Add-Member -NotePropertyName Mode -NotePropertyValue $Mode
$result | Add-Member -NotePropertyName SettingsBackup -NotePropertyValue $backupPath

if ($Json) {
    $result | ConvertTo-Json -Depth 5
} else {
    $result | Format-Table Resource, State, Version, ProxyPresent, FeatureEnabled, SamplingAgent -AutoSize -Wrap | Out-Host
    foreach ($finding in @($result.Findings)) { Write-Host "finding: $finding" }
    foreach ($warning in @($result.Warnings)) { Write-Host "warning: $warning" }
    if ($backupPath) { Write-Host "settings backup: $backupPath" }
    Write-Host 'Starting the MCP service stays manual in WinDbg: File > Settings > MCP service settings, then confirm the warning with Secure Mode enabled.'
}
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
