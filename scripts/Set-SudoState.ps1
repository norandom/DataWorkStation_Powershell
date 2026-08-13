[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo'
$enabled = (Get-ItemProperty -LiteralPath $registryPath -Name Enabled -ErrorAction Ignore).Enabled

if ($Mode -eq 'Test') {
    if ($enabled -eq 3) {
        Write-Host 'Windows sudo inline mode: compliant.'
        exit 0
    }
    Write-Host "Windows sudo inline mode: drift detected (Enabled=$enabled)."
    exit 1
}

if ($Mode -eq 'Ensure' -and $enabled -eq 3) {
    Write-Host 'Windows sudo inline mode is already active; no changes were made.'
    exit 0
}

$sudo = (Get-Command sudo.exe -ErrorAction Stop).Source
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    & $sudo config --enable normal
    if ($LASTEXITCODE -ne 0) { throw "sudo configuration failed with exit code $LASTEXITCODE." }
} else {
    $process = Start-Process -FilePath $sudo -ArgumentList 'config','--enable','normal' -Verb RunAs -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "sudo configuration failed with exit code $($process.ExitCode)." }
}

Write-Host 'Windows sudo inline mode is active.'

