[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Disable', 'Enable', 'Status')]
    [string] $Mode
)

$ErrorActionPreference = 'Stop'

function Get-DefenderState {
    $status = Get-MpComputerStatus
    $preference = Get-MpPreference
    $service = Get-Service WinDefend -ErrorAction SilentlyContinue
    $process = Get-Process MsMpEng -ErrorAction SilentlyContinue | Select-Object -First 1
    [pscustomobject]@{
        DefenderEngineAvailable   = $status.AntivirusEnabled
        DefenderServiceInstalled  = [bool] $service
        DefenderServiceStatus     = if ($service) { [string] $service.Status } else { 'Absent' }
        DefenderServiceStartType  = if ($service) { [string] $service.StartType } else { 'Absent' }
        DefenderProcessRunning    = [bool] $process
        RealTimeProtectionEnabled = $status.RealTimeProtectionEnabled
        BehaviorMonitorEnabled    = $status.BehaviorMonitorEnabled
        IoavProtectionEnabled     = $status.IoavProtectionEnabled
        NetworkProtectionEnabled  = "$($preference.EnableNetworkProtection)"
        ScriptScanningEnabled     = -not [bool]$preference.DisableScriptScanning
        CloudProtection           = "$($preference.MAPSReporting)"
        TamperProtected           = $status.IsTamperProtected
    }
}

if ($Mode -eq 'Status') {
    Get-DefenderState
    exit 0
}

$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$initial = Get-DefenderState
if ($Mode -eq 'Disable' -and $initial.TamperProtected) {
    $initial
    Write-Warning 'Tamper Protection must be turned off first. Run defender-settings, switch off Tamper Protection, then run disable-defender again.'
    exit 2
}

try {
if ($Mode -eq 'Disable') {
    Set-MpPreference `
        -DisableRealtimeMonitoring $true `
        -DisableBehaviorMonitoring $true `
        -DisableScriptScanning $true `
        -DisableIOAVProtection $true `
        -DisableBlockAtFirstSeen $true `
        -MAPSReporting Disabled `
        -SubmitSamplesConsent NeverSend `
        -EnableNetworkProtection Disabled `
        -PUAProtection Disabled
} else {
    Set-MpPreference `
        -DisableRealtimeMonitoring $false `
        -DisableBehaviorMonitoring $false `
        -DisableScriptScanning $false `
        -DisableIOAVProtection $false `
        -DisableBlockAtFirstSeen $false `
        -MAPSReporting Advanced `
        -SubmitSamplesConsent SendSafeSamples `
        -EnableNetworkProtection Enabled `
        -PUAProtection Enabled
}
} catch {
    $current = Get-DefenderState
    $current
    if ($current.TamperProtected) {
        Write-Warning "Tamper Protection blocked the change. Run defender-settings, turn it off, then run $($Mode.ToLowerInvariant())-defender again."
        exit 2
    }
    Write-Warning "Defender rejected the requested '$Mode' state: $($_.Exception.Message)"
    exit 1
}

function Test-RequestedState {
    param($State)

    $active = $State.RealTimeProtectionEnabled -and
        $State.BehaviorMonitorEnabled -and
        $State.IoavProtectionEnabled -and
        $State.ScriptScanningEnabled -and
        $State.NetworkProtectionEnabled -ne '0' -and
        $State.CloudProtection -ne '0'
    $inactive = -not $State.RealTimeProtectionEnabled -and
        -not $State.BehaviorMonitorEnabled -and
        -not $State.IoavProtectionEnabled -and
        -not $State.ScriptScanningEnabled -and
        $State.NetworkProtectionEnabled -eq '0' -and
        $State.CloudProtection -eq '0'
    if ($Mode -eq 'Enable') { return $active }
    return $inactive
}

$deadline = (Get-Date).AddSeconds(20)
do {
    Start-Sleep -Milliseconds 500
    $result = Get-DefenderState
    $expected = Test-RequestedState -State $result
} while (-not $expected -and (Get-Date) -lt $deadline)

$result
if (-not $expected) {
    if ($result.TamperProtected) {
        Write-Warning "Tamper Protection blocked the change. Run defender-settings, turn it off, then run $($Mode.ToLowerInvariant())-defender again."
        exit 2
    }
    Write-Warning "Defender did not reach the requested '$Mode' state within 20 seconds. Review the status shown above."
    exit 1
}

Write-Host "Microsoft Defender protection state: $($Mode.ToLowerInvariant()). No scan was started."
