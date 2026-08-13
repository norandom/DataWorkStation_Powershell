[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Disable', 'Enable', 'Status')]
    [string] $Mode
)

$ErrorActionPreference = 'Stop'
$policyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Attachments'

function Get-SaveZoneState {
    $policy = Get-ItemProperty -LiteralPath $policyPath -ErrorAction Ignore
    $value = $policy.SaveZoneInformation
    [pscustomobject]@{
        SaveZoneInformation   = if ($null -eq $value) { 'NotConfigured' } else { $value }
        FutureDownloadsMarked = $value -ne 1
    }
}

if ($Mode -eq 'Status') {
    Get-SaveZoneState
    exit 0
}

New-Item -Path $policyPath -Force | Out-Null
if ($Mode -eq 'Disable') {
    New-ItemProperty -LiteralPath $policyPath -Name SaveZoneInformation -PropertyType DWord -Value 1 -Force | Out-Null
} else {
    Remove-ItemProperty -LiteralPath $policyPath -Name SaveZoneInformation -ErrorAction Ignore
}

$result = Get-SaveZoneState
$result
$expected = if ($Mode -eq 'Disable') { -not $result.FutureDownloadsMarked } else { $result.FutureDownloadsMarked }
if (-not $expected) {
    Write-Warning "SaveZoneInformation did not reach the requested '$Mode' state."
    exit 1
}

$message = if ($Mode -eq 'Disable') {
    'Future downloads will not preserve Mark-of-the-Web.'
} else {
    'Future downloads will preserve Mark-of-the-Web using the Windows default.'
}
Write-Host $message
