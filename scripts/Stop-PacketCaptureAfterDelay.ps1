[CmdletBinding()]
param([Parameter(Mandatory = $true)][string] $SessionFile)
$ErrorActionPreference = 'Stop'
$session = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
$deadline = ([datetime] $session.StartedUtc).AddSeconds([int] $session.Seconds)
$remaining = [Math]::Max(0, ($deadline.ToUniversalTime() - [datetime]::UtcNow).TotalSeconds)
Start-Sleep -Seconds ([int] [Math]::Ceiling($remaining))
$latest = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
if ($latest.StartedUtc -ne $session.StartedUtc -or $latest.Status -eq 'Completed') { return }
try {
    & (Join-Path $PSScriptRoot 'Invoke-PacketCapture.ps1') -Action Stop -Name $session.Name -WorkingDirectory (Split-Path $session.CaptureDirectory -Parent) -Json | Out-Null
} catch {
    'Automatic stop/conversion failed. Inspect pktmon status and the session before retrying pcap-stop.' | Set-Content -LiteralPath (Join-Path (Split-Path $SessionFile -Parent) 'autostop-error.txt')
    exit 1
}
