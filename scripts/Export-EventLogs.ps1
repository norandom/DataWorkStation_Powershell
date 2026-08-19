[CmdletBinding()]
param(
    [string] $ConfigurationPath,
    [string] $ArchiveRoot
)

$ErrorActionPreference = 'Stop'
$statusDirectory = Join-Path $env:ProgramData 'LinuxShell\EventLogs'
$statusPath = Join-Path $statusDirectory 'last-export.json'
New-Item -ItemType Directory -Path $statusDirectory -Force | Out-Null
trap {
    [pscustomobject]@{
        TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
        Success = $false
        Error = ($_ | Out-String).Trim()
        Position = $_.InvocationInfo.PositionMessage
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $statusPath -Encoding UTF8
    exit 1
}
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) {
    $ConfigurationPath = Join-Path $scriptDirectory 'eventlogs.psd1'
}
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
if ([string]::IsNullOrWhiteSpace($ArchiveRoot)) {
    if (-not $configuration.ArchiveRoot) { throw 'ArchiveRoot must be supplied by the local workstation configuration.' }
    $ArchiveRoot = [Environment]::ExpandEnvironmentVariables([string] $configuration.ArchiveRoot)
}
$archiveRoot = [IO.Path]::GetFullPath($ArchiveRoot)
$runStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmmssZ')
$stagingRoot = Join-Path $env:ProgramData 'LinuxShell\EventLogs\staging'
$staging = Join-Path $stagingRoot $runStamp
$archive = Join-Path $archiveRoot "eventlogs-$runStamp.zip"

New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
New-Item -ItemType Directory -Path $staging -Force | Out-Null
$manifest = [Collections.Generic.List[object]]::new()
$windowMilliseconds = [int64]$configuration.ExportWindowHours * 60 * 60 * 1000
$query = "*[System[TimeCreated[timediff(@SystemTime) <= $windowMilliseconds]]]"

try {
    foreach ($channel in $configuration.Channels) {
        $safeName = $channel.Name -replace '[^A-Za-z0-9._-]', '_'
        $destination = Join-Path $staging "$safeName.evtx"
        $output = & "$env:SystemRoot\System32\wevtutil.exe" epl $channel.Name $destination "/q:$query" /ow:true 2>&1
        $exitCode = $LASTEXITCODE
        $manifest.Add([pscustomobject]@{
            Channel = $channel.Name
            Exported = $exitCode -eq 0
            File = if ($exitCode -eq 0) { [IO.Path]::GetFileName($destination) } else { $null }
            Error = if ($exitCode -ne 0) { "$output" } else { $null }
        })
    }

    [pscustomobject]@{
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        WindowHours = $configuration.ExportWindowHours
        Channels = $manifest
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $staging 'manifest.json') -Encoding UTF8

    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $archive -CompressionLevel Optimal -Force
} finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}

$cutoff = (Get-Date).AddDays(-[int]$configuration.RetentionDays)
Get-ChildItem -LiteralPath $archiveRoot -File -Filter 'eventlogs-*.zip' |
    Where-Object LastWriteTime -lt $cutoff |
    Remove-Item -Force

$archiveBudget = [int64]$configuration.MaxArchiveMiB * 1MB
$minimumFree = [int64]$configuration.MinimumFreeMiB * 1MB
$archives = [Collections.Generic.List[IO.FileInfo]]@(
    Get-ChildItem -LiteralPath $archiveRoot -File -Filter 'eventlogs-*.zip' | Sort-Object LastWriteTime
)
while ($archives.Count -gt 1) {
    $totalBytes = ($archives | Measure-Object Length -Sum).Sum
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($archiveRoot).TrimEnd(':\'))
    if ($totalBytes -le $archiveBudget -and $drive.Free -ge $minimumFree) { break }
    Remove-Item -LiteralPath $archives[0].FullName -Force
    $archives.RemoveAt(0)
}

Write-Host "Event log archive created: $archive"
[pscustomobject]@{
    TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
    Success = $true
    Archive = $archive
} | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
