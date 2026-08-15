[CmdletBinding()]
param(
    [string[]] $Path,
    [switch] $Compatibility,
    [switch] $Json,
    [ValidateRange(1, 8)]
    [int] $ThrottleLimit = 4,
    [Parameter(DontShow = $true)]
    [switch] $CompatibilityChild,
    [Parameter(DontShow = $true)]
    [string] $PathListJson
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\pester.psd1')
$failureMessageLimit = [int] $configuration.FailureMessageLimit
$failureRecordLimit = [int] $configuration.FailureRecordLimit
if ($PathListJson) { $Path = @($PathListJson | ConvertFrom-Json -ErrorAction Stop) }
if (-not $Path -or $Path.Count -eq 0) { $Path = @([string] $configuration.TestPath) }
$resolvedPaths = foreach ($candidate in $Path) {
    if ([IO.Path]::IsPathRooted($candidate)) { $candidate } else { Join-Path $repositoryRoot $candidate }
}

if ($Compatibility -and $PSVersionTable.PSEdition -ne 'Desktop' -and -not $CompatibilityChild) {
    $windowsPowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Compatibility', '-CompatibilityChild', '-ThrottleLimit', $ThrottleLimit)
    if ($Json) { $arguments += '-Json' }
    if ($resolvedPaths.Count -gt 0) { $arguments += '-PathListJson'; $arguments += ($resolvedPaths | ConvertTo-Json -Compress) }
    & $windowsPowerShell @arguments
    exit $LASTEXITCODE
}

$frameworkVersion = [string] $configuration.Version
try {
    Import-Module Pester -RequiredVersion $frameworkVersion -Force -ErrorAction Stop
} catch {
    $message = "Pester $frameworkVersion is required. Run: .\Apply-Workstation.ps1 -Mode Ensure -Module PowerShellTesting"
    if ($Json) {
        [pscustomobject]@{ SchemaVersion = 1; Status = 'dependency-missing'; Runtime = $PSVersionTable.PSEdition; FrameworkVersion = $frameworkVersion; Parallel = $false; ThrottleLimit = 1; TotalCount = 0; PassedCount = 0; FailedCount = 0; SkippedCount = 0; DurationMilliseconds = 0; Failures = @([pscustomobject]@{ Name = 'Pester'; Path = $null; Message = $message }) } | ConvertTo-Json -Depth 6
    } else {
        Write-Error $message -ErrorAction Continue
    }
    exit 1
}

$minimumParallelVersion = [version]::new(7, 4)
$parallel = (-not $Compatibility -and $PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion -ge $minimumParallelVersion)
$fallbackReason = if ($parallel) {
    $null
} elseif ($Compatibility -or $PSVersionTable.PSEdition -eq 'Desktop') {
    'Windows PowerShell compatibility lane is sequential.'
} else {
    'Parallel Pester execution requires PowerShell 7.4 or newer.'
}

$pesterConfiguration = New-PesterConfiguration
$pesterConfiguration.Run.Path = @($resolvedPaths)
$pesterConfiguration.Run.PassThru = $true
$pesterConfiguration.Run.Exit = $false
$pesterConfiguration.Run.Throw = $false
$pesterConfiguration.Run.Parallel = $parallel
$pesterConfiguration.Run.ParallelThrottleLimit = if ($parallel) { $ThrottleLimit } else { 1 }
$pesterConfiguration.Output.Verbosity = if ($Json) { 'None' } else { 'Normal' }

$result = Invoke-Pester -Configuration $pesterConfiguration
$failures = @($result.Failed | Select-Object -First $failureRecordLimit | ForEach-Object {
    $message = if ($_.ErrorRecord) { [string] $_.ErrorRecord } elseif ($_.StandardOutput) { [string] $_.StandardOutput } else { 'Test failed without an error record.' }
    if ($message.Length -gt $failureMessageLimit) { $message = $message.Substring(0, $failureMessageLimit) + '…' }
    [pscustomobject]@{
        Name = [string] $_.ExpandedName
        Path = [string] $_.Path
        Message = $message
    }
})
$failed = ([int] $result.FailedCount -gt 0 -or [int] $result.TotalCount -eq 0)
$summary = [pscustomobject]@{
    SchemaVersion = 1
    Status = if ($failed) { 'failed' } else { 'passed' }
    Runtime = "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
    FrameworkVersion = $frameworkVersion
    Compatibility = [bool] $Compatibility
    Parallel = $parallel
    ThrottleLimit = if ($parallel) { $ThrottleLimit } else { 1 }
    FallbackReason = $fallbackReason
    TotalCount = [int] $result.TotalCount
    PassedCount = [int] $result.PassedCount
    FailedCount = [int] $result.FailedCount
    SkippedCount = [int] $result.SkippedCount
    NotRunCount = [int] $result.NotRunCount
    DurationMilliseconds = [math]::Round($result.Duration.TotalMilliseconds)
    Failures = $failures
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 6
} else {
    Write-Host ("PowerShell tests: {0}; {1} passed, {2} failed, {3} skipped in {4} ms" -f $summary.Status, $summary.PassedCount, $summary.FailedCount, $summary.SkippedCount, $summary.DurationMilliseconds)
    Write-Host ("  Runtime: {0}; Pester {1}; parallel={2}; throttle={3}" -f $summary.Runtime, $summary.FrameworkVersion, $summary.Parallel, $summary.ThrottleLimit)
    if ($summary.FallbackReason) { Write-Host "  Sequential reason: $($summary.FallbackReason)" }
}

if ($failed) { exit 1 }
exit 0
