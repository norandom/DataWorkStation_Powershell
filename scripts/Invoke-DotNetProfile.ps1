[CmdletBinding(DefaultParameterSetName = 'Attach')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Attach')]
    [int] $ProcessId,

    [Parameter(Mandatory = $true, ParameterSetName = 'Launch')]
    [string] $Executable,

    [Parameter(ParameterSetName = 'Launch')]
    [string[]] $Argument,

    [ValidateRange(1, 86400)]
    [int] $Seconds = 30,

    [string] $OutputBase = (Join-Path (Get-Location).Path ("dotnet-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch] $Open,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$dotnetTrace = Join-Path $env:USERPROFILE '.dotnet\tools\dotnet-trace.exe'
if (-not (Test-Path -LiteralPath $dotnetTrace -PathType Leaf)) { throw "dotnet-trace is missing: $dotnetTrace" }
$basePath = [IO.Path]::GetFullPath($OutputBase)
$tracePath = if ($basePath -like '*.nettrace') { $basePath } else { "$basePath.nettrace" }
New-Item -ItemType Directory -Path (Split-Path -Parent $tracePath) -Force | Out-Null
$duration = [TimeSpan]::FromSeconds($Seconds)
$durationText = '{0:00}:{1:00}:{2:00}:{3:00}' -f $duration.Days,$duration.Hours,$duration.Minutes,$duration.Seconds
$options = @('collect', '--profile', 'dotnet-sampled-thread-time,dotnet-common', '--duration', $durationText, '--format', 'Speedscope', '--output', $tracePath)

if ($PSCmdlet.ParameterSetName -eq 'Attach') {
    & $dotnetTrace @options --process-id $ProcessId
} else {
    $target = (Get-Command $Executable -CommandType Application -ErrorAction Ignore).Source
    if (-not $target) { $target = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path }
    & $dotnetTrace @options -- $target @Argument
}
if ($LASTEXITCODE -ne 0) { throw "dotnet-trace failed: $LASTEXITCODE" }
$directory = Split-Path -Parent $tracePath
$leaf = [IO.Path]::GetFileNameWithoutExtension($tracePath)
$files = @(Get-ChildItem -LiteralPath $directory -File | Where-Object Name -like "$leaf*")
$speedFile = $files | Where-Object Name -like '*.speedscope.json' | Select-Object -First 1
if ($Open -and $speedFile) {
    & (Join-Path $PSScriptRoot 'Open-Profile.ps1') -Path $speedFile.FullName
}
$result = [pscustomobject]@{ Kind='DotNetCPU'; Seconds=$Seconds; Files=@($files.FullName) }
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { $result }
