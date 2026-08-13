[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize', 'Disable', 'Enable', 'Status', 'Off', 'Medium', 'Full')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$systemPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'

function Get-SmartScreenState {
    $systemPolicy = Get-ItemProperty -LiteralPath $systemPolicyPath -ErrorAction Ignore
    $shellValue = $systemPolicy.EnableSmartScreen
    $mpStatus = Get-MpComputerStatus -ErrorAction Ignore
    $smartAppControl = if ($mpStatus -and $mpStatus.PSObject.Properties['SmartAppControlState']) {
        "$($mpStatus.SmartAppControlState)"
    } else {
        'Unavailable'
    }

    $effectiveMode = if ($shellValue -eq 0) {
        'Off'
    } elseif ($shellValue -eq 1 -and $systemPolicy.ShellSmartScreenLevel -eq 'Block') {
        'Full'
    } elseif ($shellValue -eq 1 -and $systemPolicy.ShellSmartScreenLevel -eq 'Warn') {
        'Medium'
    } else {
        'NotConfigured'
    }

    [pscustomobject]@{
        Mode                       = $effectiveMode
        ShellFileReputationEnabled = if ($null -eq $shellValue) { 'NotConfigured' } else { [bool]$shellValue }
        ShellEnforcementLevel      = if ($systemPolicy.ShellSmartScreenLevel) { "$($systemPolicy.ShellSmartScreenLevel)" } else { 'NotConfigured' }
        SmartAppControl            = $smartAppControl
    }
}

$state = Get-SmartScreenState
if ($Mode -eq 'Status') {
    $state
    exit 0
}

if ($Mode -eq 'Test') {
    $state
    if ($state.Mode -eq 'Medium') {
        Write-Host 'Microsoft Defender SmartScreen desired state: Warn with user override.'
        exit 0
    }
    Write-Warning 'Microsoft Defender SmartScreen desired-state drift detected.'
    exit 1
}

$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$requestedMode = switch ($Mode) {
    { $_ -in 'Disable', 'Off' } { 'Off'; break }
    'Full' { 'Full'; break }
    default { 'Medium' }
}

if ($Mode -eq 'Ensure' -and $state.Mode -eq 'Medium') {
    Write-Host 'Microsoft Defender SmartScreen is already enabled in Warn mode; no changes were made.'
    exit 0
}

New-Item -Path $systemPolicyPath -Force | Out-Null
if ($requestedMode -eq 'Off') {
    New-ItemProperty -LiteralPath $systemPolicyPath -Name EnableSmartScreen -PropertyType DWord -Value 0 -Force | Out-Null
    New-ItemProperty -LiteralPath $systemPolicyPath -Name ShellSmartScreenLevel -PropertyType String -Value 'Warn' -Force | Out-Null
} else {
    New-ItemProperty -LiteralPath $systemPolicyPath -Name EnableSmartScreen -PropertyType DWord -Value 1 -Force | Out-Null
    $level = if ($requestedMode -eq 'Full') { 'Block' } else { 'Warn' }
    New-ItemProperty -LiteralPath $systemPolicyPath -Name ShellSmartScreenLevel -PropertyType String -Value $level -Force | Out-Null
}

$deadline = (Get-Date).AddSeconds(5)
do {
    Start-Sleep -Milliseconds 250
    $result = Get-SmartScreenState
    $expected = $result.Mode -eq $requestedMode
} while (-not $expected -and (Get-Date) -lt $deadline)

$result
if (-not $expected) {
    Write-Warning "SmartScreen did not reach the requested '$requestedMode' state within 5 seconds."
    exit 1
}

Write-Host "Microsoft Defender SmartScreen mode: $requestedMode. Smart App Control was not changed."
