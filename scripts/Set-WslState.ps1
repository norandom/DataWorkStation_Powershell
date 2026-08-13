[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\config\wslconfig.ini'))
$target = Join-Path $env:USERPROFILE '.wslconfig'
$desired = (Get-Content -LiteralPath $source -Raw).TrimEnd()
$current = if (Test-Path -LiteralPath $target) { (Get-Content -LiteralPath $target -Raw).TrimEnd() } else { '' }
$compliant = $current -ceq $desired

if ($Mode -eq 'Test') {
    if ($compliant) { Write-Host 'WSL memory policy: compliant.'; exit 0 }
    Write-Host 'WSL memory policy: drift detected.'
    exit 1
}

if ($Mode -eq 'Ensure' -and $compliant) {
    Write-Host 'WSL memory policy is already active; no changes were made.'
    exit 0
}

if (Test-Path -LiteralPath $target) {
    Copy-Item -LiteralPath $target -Destination "$target.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak" -Force
}
Set-Content -LiteralPath $target -Value $desired -Encoding UTF8
Write-Host "Updated WSL memory policy: $target"
Write-Host 'Run wsl --shutdown when no WSL workload is active to apply it.'

