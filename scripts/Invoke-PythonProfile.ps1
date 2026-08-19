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

    [ValidateRange(1, 1000)]
    [int] $Rate = 100,

    [string] $Output,
    [string] $ConfigurationPath,
    [switch] $Open,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
if ([string]::IsNullOrWhiteSpace($Output)) {
    $traceRoot = (Import-WorkstationConfiguration -ConfigurationPath $ConfigurationPath).Paths.Traces
    $Output = Join-Path $traceRoot ("python-{0}.svg" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$pySpy = Join-Path $env:USERPROFILE '.local\bin\py-spy.exe'
if (-not (Test-Path -LiteralPath $pySpy -PathType Leaf)) { throw "py-spy is missing: $pySpy" }
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path (Split-Path -Parent $outputPath) -Force | Out-Null
$options = @('record', '--format', 'flamegraph', '--rate', $Rate, '--duration', $Seconds, '--output', $outputPath)

if ($PSCmdlet.ParameterSetName -eq 'Attach') {
    & sudo.exe $pySpy @options --pid $ProcessId
} else {
    $target = (Get-Command $Executable -CommandType Application -ErrorAction Ignore).Source
    if (-not $target) { $target = (Resolve-Path -LiteralPath $Executable -ErrorAction Stop).Path }
    & $pySpy @options -- $target @Argument
}
if ($LASTEXITCODE -ne 0) { throw "py-spy failed: $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw "py-spy did not create: $outputPath" }
if ($Open) { Start-Process -FilePath $outputPath }
$result = [pscustomobject]@{ Kind='PythonCPU'; Output=$outputPath; Seconds=$Seconds; Rate=$Rate }
if ($Json) { $result | ConvertTo-Json } else { $result }
