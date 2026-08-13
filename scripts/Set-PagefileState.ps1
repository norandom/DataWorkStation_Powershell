[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [uint32] $InitialSizeMiB = 16384,
    [uint32] $MaximumSizeMiB = 32768
)

$ErrorActionPreference = 'Stop'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Administrator rights are required. Run this script through sudo.'
}

$computer = Get-CimInstance Win32_ComputerSystem
$pagefile = Get-CimInstance Win32_PageFileSetting | Where-Object Name -ieq 'C:\pagefile.sys' | Select-Object -First 1
$compliant = -not $computer.AutomaticManagedPagefile -and $pagefile -and
    $pagefile.InitialSize -eq $InitialSizeMiB -and $pagefile.MaximumSize -eq $MaximumSizeMiB

if ($Mode -eq 'Test') {
    if ($compliant) { Write-Host "Pagefile policy: compliant ($InitialSizeMiB-$MaximumSizeMiB MiB)."; exit 0 }
    Write-Host "Pagefile policy drift: automatic=$($computer.AutomaticManagedPagefile), initial=$($pagefile.InitialSize), maximum=$($pagefile.MaximumSize)."
    exit 1
}

if ($Mode -eq 'Ensure' -and $compliant) {
    Write-Host 'Pagefile policy is already active; no changes were made.'
    exit 0
}

Set-CimInstance -InputObject $computer -Property @{ AutomaticManagedPagefile = $false } | Out-Null
$pagefile = Get-CimInstance Win32_PageFileSetting | Where-Object Name -ieq 'C:\pagefile.sys' | Select-Object -First 1
if ($pagefile) {
    Set-CimInstance -InputObject $pagefile -Property @{ InitialSize = $InitialSizeMiB; MaximumSize = $MaximumSizeMiB } | Out-Null
} else {
    New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = 'C:\pagefile.sys'; InitialSize = $InitialSizeMiB; MaximumSize = $MaximumSizeMiB } | Out-Null
}
Write-Host "Configured C:\pagefile.sys for $InitialSizeMiB-$MaximumSizeMiB MiB. A Windows restart is required."
