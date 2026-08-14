[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $DumpPath,

    [string] $OutputPath,

    [string] $SymbolCache = (Join-Path $env:LOCALAPPDATA 'DataWorkStation\symbols'),

    [ValidatePattern('^https://')]
    [string] $SymbolServer = 'https://msdl.microsoft.com/download/symbols',

    [ValidateRange(30, 3600)]
    [int] $TimeoutSeconds = 600,

    [string[]] $Module,

    [switch] $NoisySymbols
)

$ErrorActionPreference = 'Stop'
$resolvedDump = (Resolve-Path -LiteralPath $DumpPath -ErrorAction Stop).Path
$debugger = (Get-Command cdbX64.exe -CommandType Application -ErrorAction Stop).Source
$resolvedSymbolCache = [IO.Path]::GetFullPath(
    [Environment]::ExpandEnvironmentVariables($SymbolCache)
)
New-Item -ItemType Directory -Path $resolvedSymbolCache -Force | Out-Null

if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($resolvedDump, '.windbg.txt')
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedOutput) -Force | Out-Null

$moduleNames = @(
    $Module |
        ForEach-Object { $_ -split ',' } |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)
foreach ($moduleName in $moduleNames) {
    if ($moduleName -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Invalid module name '$moduleName'. Use letters, digits, dot, underscore, or hyphen."
    }
}

$commands = [Collections.Generic.List[string]]::new()
if ($NoisySymbols) { $commands.Add('!sym noisy') }
$commands.Add('!analyze -v')
$commands.Add('.exr -1')
$commands.Add('.ecxr')
$commands.Add('r')
$commands.Add('kv')
foreach ($moduleName in $moduleNames) { $commands.Add("lmvm $moduleName") }
$commands.Add('lm')
$commands.Add('q')

$symbolPath = "srv*$resolvedSymbolCache*$SymbolServer"
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $debugger
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in @(
    '-logo', $resolvedOutput,
    '-y', $symbolPath,
    '-z', $resolvedDump,
    '-c', ($commands -join ';')
)) {
    [void] $startInfo.ArgumentList.Add($argument)
}

$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
$timedOut = $false
try {
    if (-not $process.Start()) { throw 'cdbX64 did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $timedOut = $true
        $process.Kill($true)
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
} finally {
    $process.Dispose()
}

$log = if (Test-Path -LiteralPath $resolvedOutput -PathType Leaf) {
    Get-Content -LiteralPath $resolvedOutput -Raw
} else {
    ''
}
$analysisComplete = $log -match '(?m)^\*+\s+Exception Analysis\s+\*+\s*$' -and
    $log -match '(?m)^STACK_TEXT:\s*$'
$symbolErrors = @(
    [regex]::Matches($log, '(?m)^([A-Za-z0-9_.-]+)\s+The system cannot find the file specified\s*$') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
)

$result = [pscustomobject]@{
    Dump = $resolvedDump
    Log = $resolvedOutput
    Debugger = $debugger
    SymbolCache = $resolvedSymbolCache
    SymbolServer = $SymbolServer
    ExitCode = $exitCode
    TimedOut = $timedOut
    AnalysisComplete = $analysisComplete
    ThirdPartySymbolGaps = $symbolErrors
}
$result | Format-List

if ($timedOut) {
    throw "Headless dump analysis exceeded $TimeoutSeconds seconds. The partial log was retained at $resolvedOutput. Re-run with a longer timeout or -NoisySymbols before changing the target."
}
if ($exitCode -ne 0) {
    $detail = @($stderr, $stdout) -join [Environment]::NewLine
    throw "cdbX64 failed with exit code $exitCode. Log: $resolvedOutput`n$detail"
}
if (-not $analysisComplete) {
    throw "cdbX64 exited without a complete exception analysis and stack. Inspect $resolvedOutput"
}

Write-Host "Headless dump analysis completed. Public symbols were cached at $resolvedSymbolCache."
