[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$policyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
$desired = @{ EnableSmartScreen = 1; ShellSmartScreenLevel = 'Warn' }
$current = Get-ItemProperty -LiteralPath $policyPath -ErrorAction Ignore
$compliant = $current.EnableSmartScreen -eq 1 -and $current.ShellSmartScreenLevel -eq 'Warn'

if ($Mode -eq 'Test') {
    if ($compliant) {
        Write-Host 'Microsoft Defender SmartScreen policy: Warn with user override.'
        exit 0
    }
    Write-Host "Microsoft Defender SmartScreen policy drift: EnableSmartScreen='$($current.EnableSmartScreen)', ShellSmartScreenLevel='$($current.ShellSmartScreenLevel)'."
    exit 1
}

if ($Mode -eq 'Ensure' -and $compliant) {
    Write-Host 'Microsoft Defender SmartScreen policy is already set to Warn; no changes were made.'
    exit 0
}

New-Item -Path $policyPath -Force | Out-Null
New-ItemProperty -LiteralPath $policyPath -Name EnableSmartScreen -PropertyType DWord -Value $desired.EnableSmartScreen -Force | Out-Null
New-ItemProperty -LiteralPath $policyPath -Name ShellSmartScreenLevel -PropertyType String -Value $desired.ShellSmartScreenLevel -Force | Out-Null
Write-Host 'Microsoft Defender SmartScreen now warns and permits an explicit user override.'
Write-Host 'Smart App Control was not changed.'

