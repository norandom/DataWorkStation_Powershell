[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [ValidateSet('Declared', 'On', 'Off')]
    [string] $Target = 'Declared'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\focus-follows-mouse.psd1')

foreach ($propertyName in @('Enabled', 'RaiseOnFocus', 'DelayMilliseconds')) {
    if (-not $configuration.ContainsKey($propertyName)) {
        throw "Focus-follows-mouse configuration is missing '$propertyName'."
    }
}
if ($configuration.Enabled -isnot [bool] -or $configuration.RaiseOnFocus -isnot [bool]) {
    throw 'Enabled and RaiseOnFocus must be Boolean values.'
}
if ($configuration.DelayMilliseconds -isnot [int] -or $configuration.DelayMilliseconds -lt 0) {
    throw 'DelayMilliseconds must be a non-negative integer.'
}
$desiredEnabled = switch ($Target) {
    'On' { $true }
    'Off' { $false }
    default { [bool] $configuration.Enabled }
}

if (-not ('DataWorkStation.NativeActiveWindowTracking' -as [type])) {
    $nativeType = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace DataWorkStation
{
    public static class NativeActiveWindowTracking
    {
        private const uint PersistAndBroadcast = 0x0001 | 0x0002;

        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
        private static extern bool GetSystemParameter(
            uint action,
            uint parameter,
            out uint value,
            uint flags);

        [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
        private static extern bool SetSystemParameter(
            uint action,
            uint parameter,
            IntPtr value,
            uint flags);

        public static uint Get(uint action)
        {
            uint value;
            if (!GetSystemParameter(action, 0, out value, 0))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
            return value;
        }

        public static void Set(uint action, uint value)
        {
            if (!SetSystemParameter(action, 0, new IntPtr(value), PersistAndBroadcast))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error());
            }
        }
    }
}
'@
    Add-Type -TypeDefinition $nativeType
}

$getTracking = 0x1000
$setTracking = 0x1001
$getRaiseOnFocus = 0x100C
$setRaiseOnFocus = 0x100D
$getDelay = 0x2002
$setDelay = 0x2003

function Get-FocusFollowsMouseState {
    $trackingEnabled = [bool][DataWorkStation.NativeActiveWindowTracking]::Get($getTracking)
    $raiseOnFocus = [bool][DataWorkStation.NativeActiveWindowTracking]::Get($getRaiseOnFocus)
    $delayMilliseconds = [uint32][DataWorkStation.NativeActiveWindowTracking]::Get($getDelay)
    $compliant = (
        $trackingEnabled -eq $desiredEnabled -and
        $raiseOnFocus -eq $configuration.RaiseOnFocus -and
        $delayMilliseconds -eq $configuration.DelayMilliseconds
    )

    [pscustomobject]@{
        TrackingEnabled = $trackingEnabled
        DesiredTrackingEnabled = $desiredEnabled
        RaiseOnFocus = $raiseOnFocus
        DelayMilliseconds = $delayMilliseconds
        Compliant = $compliant
    }
}

function Get-FocusFollowsMouseHumanText {
    if ($desiredEnabled) {
        return "Focus follows the mouse after $($configuration.DelayMilliseconds) ms without raising windows."
    }
    return 'Focus follows mouse is disabled; click-to-focus is active.'
}

$state = Get-FocusFollowsMouseState
if ($Mode -eq 'Test') {
    $state | Format-Table -AutoSize
    if (-not $state.Compliant) {
        Write-Warning 'Focus-follows-mouse desired-state drift detected.'
        exit 1
    }
    Write-Host (Get-FocusFollowsMouseHumanText)
    exit 0
}

if ($Mode -eq 'Ensure' -and $state.Compliant) {
    $state
    Write-Host "$(Get-FocusFollowsMouseHumanText) No changes were made."
    exit 0
}

if (-not $desiredEnabled) {
    [DataWorkStation.NativeActiveWindowTracking]::Set($setTracking, 0)
}
[DataWorkStation.NativeActiveWindowTracking]::Set(
    $setRaiseOnFocus,
    [uint32][int]$configuration.RaiseOnFocus
)
[DataWorkStation.NativeActiveWindowTracking]::Set(
    $setDelay,
    [uint32]$configuration.DelayMilliseconds
)
if ($desiredEnabled) {
    [DataWorkStation.NativeActiveWindowTracking]::Set($setTracking, 1)
}

$result = Get-FocusFollowsMouseState
$result
if (-not $result.Compliant) {
    Write-Warning 'Focus-follows-mouse settings did not reach the declared state.'
    exit 1
}

Write-Host (Get-FocusFollowsMouseHumanText)
