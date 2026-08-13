[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$poolMonDirectory = Join-Path $env:LOCALAPPDATA 'Programs\PoolMon'
$poolMon = Join-Path $poolMonDirectory 'poolmon.exe'
$destination = Join-Path $poolMonDirectory 'pooltag.txt'

function Find-OfficialPoolTagFile {
    $candidates = @()
    $kits = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Debuggers'
    if (Test-Path -LiteralPath $kits) {
        $candidates += Get-ChildItem -LiteralPath $kits -Recurse -Filter pooltag.txt -File -ErrorAction Ignore
    }

    $winDbg = Get-AppxPackage -Name Microsoft.WinDbg -ErrorAction Ignore
    if ($winDbg) {
        $architecture = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'amd64' }
        $candidate = Join-Path $winDbg.InstallLocation "$architecture\triage\pooltag.txt"
        if (Test-Path -LiteralPath $candidate) { $candidates += Get-Item -LiteralPath $candidate }
    }

    $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $poolMon -PathType Leaf)) {
    throw "PoolMon is missing: $poolMon"
}

$source = Find-OfficialPoolTagFile
if (-not $source) {
    throw 'No official pooltag.txt was found. Install WinDbg, or explicitly install the WDK with: winget install Microsoft.WindowsWDK.10.0.26100'
}

$compliant = (Test-Path -LiteralPath $destination -PathType Leaf) -and
    ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash)

if ($Mode -eq 'Test') {
    if ($compliant) { Write-Host 'PoolMon tag database: compliant.'; exit 0 }
    Write-Host "PoolMon tag database: drift detected (source: $($source.FullName))."
    exit 1
}

if (-not $compliant -or $Mode -eq 'Reinitialize') {
    New-Item -ItemType Directory -Path $poolMonDirectory -Force | Out-Null
    Copy-Item -LiteralPath $source.FullName -Destination $destination -Force
    Write-Host "Installed official PoolMon tag database: $destination"
} else {
    Write-Host 'PoolMon tag database: unchanged.'
}
