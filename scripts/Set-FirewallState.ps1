[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize', 'Apply', 'Remove', 'Restore', 'Disable', 'Enable', 'Status')]
    [string] $Mode = 'Ensure',

    [string] $BackupPath
)

$ErrorActionPreference = 'Stop'
$ruleGroup = 'Linux Shell - Inbound Allowlist'
$allowedTcpPorts = @(8080, 8081)
$allowedUdpPorts = @(41641)
$tailscaleProgram = Join-Path $env:ProgramFiles 'Tailscale\tailscaled.exe'
$expectedRuleNames = @(
    'LinuxShell-Allow-App-TCP-8080-8081'
    'LinuxShell-Allow-Tailscale-Interface'
    'LinuxShell-Allow-Tailscale-UDP-41641'
    'LinuxShell-Block-Other-TCP'
    'LinuxShell-Block-Other-UDP'
)

function Assert-Administrator {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights are required. Run this script through sudo.'
    }
}

function Get-BlockedPortRanges {
    param([int[]] $AllowedPorts)

    $allowed = @($AllowedPorts | Where-Object { $_ -ge 1 -and $_ -le 65535 } | Sort-Object -Unique)
    $ranges = @()
    $start = 1
    foreach ($allowedPort in $allowed) {
        if ($start -le ($allowedPort - 1)) {
            $end = $allowedPort - 1
            $ranges += if ($start -eq $end) { "$start" } else { "$start-$end" }
        }
        $start = $allowedPort + 1
    }
    if ($start -le 65535) {
        $ranges += if ($start -eq 65535) { '65535' } else { "$start-65535" }
    }
    return $ranges
}

function ConvertTo-NormalizedSet {
    param([object] $Value)

    @($Value | ForEach-Object { "$_" -split ',' } | ForEach-Object { $_.Trim() } |
        Where-Object { $_ } | Sort-Object -Unique) -join ','
}

function Test-Rule {
    param(
        [string] $Name,
        [string] $Action,
        [string] $Protocol,
        [string[]] $LocalPort,
        [string[]] $InterfaceType,
        [string[]] $InterfaceAlias,
        [string] $Program
    )

    $rule = @(Get-NetFirewallRule -Name $Name -ErrorAction Ignore)
    if ($rule.Count -ne 1) { return $false }
    $rule = $rule[0]
    if ("$($rule.Enabled)" -ne 'True' -or "$($rule.Direction)" -ne 'Inbound' -or "$($rule.Action)" -ne $Action) {
        return $false
    }

    $portFilter = $rule | Get-NetFirewallPortFilter
    if ((ConvertTo-NormalizedSet $portFilter.Protocol) -ne (ConvertTo-NormalizedSet $Protocol)) { return $false }
    if ((ConvertTo-NormalizedSet $portFilter.LocalPort) -ne (ConvertTo-NormalizedSet $LocalPort)) { return $false }

    if ($PSBoundParameters.ContainsKey('InterfaceType')) {
        $filter = $rule | Get-NetFirewallInterfaceTypeFilter
        if ((ConvertTo-NormalizedSet $filter.InterfaceType) -ne (ConvertTo-NormalizedSet $InterfaceType)) { return $false }
    }
    if ($PSBoundParameters.ContainsKey('InterfaceAlias')) {
        $filter = $rule | Get-NetFirewallInterfaceFilter
        if ((ConvertTo-NormalizedSet $filter.InterfaceAlias) -ne (ConvertTo-NormalizedSet $InterfaceAlias)) { return $false }
    }
    if ($PSBoundParameters.ContainsKey('Program')) {
        $filter = $rule | Get-NetFirewallApplicationFilter
        if ("$($filter.Program)" -ine $Program) { return $false }
    }

    return $true
}

function Get-FirewallDrift {
    $issues = [Collections.Generic.List[string]]::new()

    foreach ($firewallProfile in Get-NetFirewallProfile -Profile Domain, Private, Public) {
        if ("$($firewallProfile.Enabled)" -ne 'True') { $issues.Add("$($firewallProfile.Name) firewall is disabled.") }
        if ("$($firewallProfile.DefaultInboundAction)" -ne 'Block') { $issues.Add("$($firewallProfile.Name) default inbound action is not Block.") }
        if ("$($firewallProfile.DefaultOutboundAction)" -ne 'Allow') { $issues.Add("$($firewallProfile.Name) default outbound action is not Allow.") }
    }

    $managedNames = @(Get-NetFirewallRule -Group $ruleGroup -ErrorAction Ignore | Select-Object -ExpandProperty Name | Sort-Object)
    if ((ConvertTo-NormalizedSet $managedNames) -ne (ConvertTo-NormalizedSet $expectedRuleNames)) {
        $issues.Add('The managed firewall rule set does not contain exactly the expected rules.')
    }

    if (-not (Test-Rule -Name 'LinuxShell-Allow-App-TCP-8080-8081' -Action Allow -Protocol TCP -LocalPort 8080,8081 -InterfaceType Wired,Wireless)) {
        $issues.Add('The external TCP 8080-8081 allow rule has drifted.')
    }
    if (-not (Test-Rule -Name 'LinuxShell-Allow-Tailscale-UDP-41641' -Action Allow -Protocol UDP -LocalPort 41641 -Program $tailscaleProgram)) {
        $issues.Add('The Tailscale UDP 41641 transport rule has drifted.')
    }
    if (-not (Test-Rule -Name 'LinuxShell-Allow-Tailscale-Interface' -Action Allow -Protocol Any -LocalPort Any -InterfaceAlias Tailscale)) {
        $issues.Add('The internal Tailscale interface rule has drifted.')
    }
    if (-not (Test-Rule -Name 'LinuxShell-Block-Other-TCP' -Action Block -Protocol TCP -LocalPort (Get-BlockedPortRanges $allowedTcpPorts) -InterfaceType Wired,Wireless)) {
        $issues.Add('The physical-network TCP block rule has drifted.')
    }
    if (-not (Test-Rule -Name 'LinuxShell-Block-Other-UDP' -Action Block -Protocol UDP -LocalPort (Get-BlockedPortRanges $allowedUdpPorts) -InterfaceType Wired,Wireless)) {
        $issues.Add('The physical-network UDP block rule has drifted.')
    }

    return $issues
}

function Export-FirewallBackup {
    $backupDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\state\firewall-backups'))
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $backupFile = Join-Path $backupDirectory ("firewall-before-reinitialize-{0}.wfw" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    & "$env:SystemRoot\System32\netsh.exe" advfirewall export $backupFile | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $backupFile)) {
        throw 'The firewall backup failed; no rules were changed.'
    }
    return $backupFile
}

function Initialize-FirewallState {
    $backupFile = Export-FirewallBackup

    Get-NetFirewallRule -Group $ruleGroup -ErrorAction Ignore | Remove-NetFirewallRule
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow -LogBlocked True

    New-NetFirewallRule -Name 'LinuxShell-Allow-Tailscale-UDP-41641' -DisplayName 'Allow Tailscale WireGuard UDP 41641' -Group $ruleGroup -Direction Inbound -Action Allow -Profile Any -Protocol UDP -LocalPort 41641 -Program $tailscaleProgram | Out-Null
    New-NetFirewallRule -Name 'LinuxShell-Allow-Tailscale-Interface' -DisplayName 'Allow all traffic from Tailscale interface' -Group $ruleGroup -Direction Inbound -Action Allow -Profile Any -Protocol Any -InterfaceAlias 'Tailscale' | Out-Null
    New-NetFirewallRule -Name 'LinuxShell-Allow-App-TCP-8080-8081' -DisplayName 'Allow application TCP 8080-8081' -Group $ruleGroup -Direction Inbound -Action Allow -Profile Any -Protocol TCP -LocalPort 8080,8081 -InterfaceType Wired,Wireless | Out-Null
    New-NetFirewallRule -Name 'LinuxShell-Block-Other-TCP' -DisplayName 'Block all other inbound TCP ports on physical networks' -Group $ruleGroup -Direction Inbound -Action Block -Profile Any -Protocol TCP -LocalPort (Get-BlockedPortRanges $allowedTcpPorts) -InterfaceType Wired,Wireless | Out-Null
    New-NetFirewallRule -Name 'LinuxShell-Block-Other-UDP' -DisplayName 'Block all other inbound UDP ports on physical networks' -Group $ruleGroup -Direction Inbound -Action Block -Profile Any -Protocol UDP -LocalPort (Get-BlockedPortRanges $allowedUdpPorts) -InterfaceType Wired,Wireless | Out-Null

    $drift = @(Get-FirewallDrift)
    if ($drift.Count -gt 0) { throw "Firewall reinitialization did not converge: $($drift -join ' ')" }

    Write-Host 'Firewall desired state is active.'
    Write-Host 'Physical networks: inbound TCP 8080-8081 and Tailscale UDP 41641 are allowed; all other TCP/UDP ports are blocked.'
    Write-Host 'Internal access: loopback and the Tailscale interface remain unrestricted by the managed port block rules.'
    Write-Host "Backup: $backupFile"
}

if ($Mode -eq 'Restore') {
    Assert-Administrator
    if (-not $BackupPath -or -not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        throw 'Restore requires -BackupPath to reference an existing .wfw file.'
    }
    & "$env:SystemRoot\System32\netsh.exe" advfirewall import $BackupPath
    if ($LASTEXITCODE -ne 0) { throw "Firewall import failed with exit code $LASTEXITCODE." }
    Write-Host "Firewall restored from: $BackupPath"
    exit 0
}

if ($Mode -eq 'Remove') {
    Assert-Administrator
    Get-NetFirewallRule -Group $ruleGroup -ErrorAction Ignore | Remove-NetFirewallRule
    Write-Host "Removed the managed firewall rules: $ruleGroup"
    exit 0
}

if ($Mode -in 'Status', 'Disable', 'Enable') {
    if ($Mode -ne 'Status') {
        Assert-Administrator
        $enabled = $Mode -eq 'Enable'
        Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled $enabled

        $deadline = (Get-Date).AddSeconds(5)
        do {
            Start-Sleep -Milliseconds 250
            $profiles = @(Get-NetFirewallProfile -Profile Domain,Private,Public)
            $expected = @($profiles | Where-Object { ("$($_.Enabled)" -eq 'True') -ne $enabled }).Count -eq 0
        } while (-not $expected -and (Get-Date) -lt $deadline)
    } else {
        $profiles = @(Get-NetFirewallProfile -Profile Domain,Private,Public)
        $expected = $true
    }

    $profiles | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction,AllowInboundRules
    if (-not $expected) {
        Write-Warning "Windows Firewall did not reach the requested '$Mode' state within 5 seconds."
        exit 1
    }
    if ($Mode -ne 'Status') {
        Write-Host "Windows Firewall protection state: $($Mode.ToLowerInvariant()). Managed rules were preserved."
    }
    exit 0
}

$drift = @(Get-FirewallDrift)
if ($Mode -eq 'Test') {
    if ($drift.Count -eq 0) {
        Write-Host 'Firewall desired state: compliant.'
        exit 0
    }
    Write-Host 'Firewall desired state: drift detected.'
    $drift | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Assert-Administrator
if ($Mode -eq 'Apply') { $Mode = 'Ensure' }
if ($Mode -eq 'Ensure' -and $drift.Count -eq 0) {
    Write-Host 'Firewall desired state is already active; no changes were made.'
    exit 0
}

Initialize-FirewallState
