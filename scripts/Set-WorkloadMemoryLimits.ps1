[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Remove')][string] $Mode = 'Test',
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workload-memory-limits.psd1')
$installDirectory = Join-Path $env:ProgramFiles $policy.ServiceName
$stateDirectory = Join-Path $env:ProgramData $policy.ServiceName
$executable = Join-Path $installDirectory 'MemoryLimits.exe'
$policyPath = Join-Path $installDirectory 'policy.json'
$source = Join-Path $PSScriptRoot 'memory-limits\MemoryLimits.cs'
$guardSource = Join-Path $PSScriptRoot 'memory-limits\EarlyOom.cs'
$sourceHash = ((Get-FileHash -LiteralPath $source, $guardSource -Algorithm SHA256).Hash -join ':')
$desiredPolicy = [ordered]@{
    LimitGiB = $policy.LimitGiB
    PollMilliseconds = $policy.PollMilliseconds
    Executables = $policy.Executables
    RuntimeExecutables = $policy.RuntimeExecutables
    ProcessOnlyExecutables = $policy.ProcessOnlyExecutables
    RuntimeMarkers = $policy.RuntimeMarkers
    EarlyOom = [ordered]@{
        Mode = $policy.EarlyOom.Mode
        AvailablePhysicalPercent = $policy.EarlyOom.AvailablePhysicalPercent
        CommitHeadroomPercent = $policy.EarlyOom.CommitHeadroomPercent
        EmergencyCommitHeadroomPercent = $policy.EarlyOom.EmergencyCommitHeadroomPercent
        SustainSeconds = $policy.EarlyOom.SustainSeconds
        CooldownSeconds = $policy.EarlyOom.CooldownSeconds
        MinimumCandidateMiB = $policy.EarlyOom.MinimumCandidateMiB
        ExcludedExecutables = $policy.EarlyOom.ExcludedExecutables
    }
}
$serializedPolicy = $desiredPolicy | ConvertTo-Json -Depth 5
$service = Get-Service -Name $policy.ServiceName -ErrorAction SilentlyContinue

if ($Mode -ne 'Test') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Use sudo pwsh -NoProfile -File scripts/Set-WorkloadMemoryLimits.ps1 -Mode $Mode"
    }
}
if ($Mode -eq 'Ensure') {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $buildDirectory = Join-Path ([IO.Path]::GetTempPath()) ('dws-memory-limits-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $buildDirectory | Out-Null
    $builtExecutable = Join-Path $buildDirectory 'MemoryLimits.exe'
    & $compiler /nologo /platform:x64 /target:exe /optimize+ /r:System.ServiceProcess.dll /r:System.Management.dll /r:System.Web.Extensions.dll "/out:$builtExecutable" $source $guardSource
    if ($LASTEXITCODE -ne 0) { throw 'Memory service build failed.' }
    & $builtExecutable --self-test
    if ($LASTEXITCODE -ne 0) { throw 'Kernel memory-limit test failed; service not installed.' }

    if ($service) { Stop-Service -Name $policy.ServiceName }
    New-Item -ItemType Directory -Path $installDirectory, $stateDirectory -Force | Out-Null
    foreach ($directory in @($installDirectory, $stateDirectory)) {
        & icacls.exe $directory /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Cannot secure service directory: $directory" }
    }
    if (Test-Path -LiteralPath $executable) { Copy-Item -LiteralPath $executable -Destination ($executable + '.previous') -Force }
    Copy-Item -LiteralPath $builtExecutable -Destination $executable -Force
    $serializedPolicy | Set-Content -LiteralPath $policyPath -Encoding UTF8
    $sourceHash | Set-Content -LiteralPath (Join-Path $installDirectory 'source.sha256')
    if (-not $service) {
        New-Service -Name $policy.ServiceName -BinaryPathName ('"' + $executable + '"') -DisplayName 'DataWorkStation workload memory limits' -StartupType Automatic | Out-Null
    } else { Set-Service -Name $policy.ServiceName -StartupType Automatic }
    & sc.exe failure $policy.ServiceName reset= 86400 actions= restart/5000/restart/15000/restart/60000 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot configure memory service recovery.' }
    Start-Service -Name $policy.ServiceName
    (Get-Service -Name $policy.ServiceName).WaitForStatus('Running', [timespan]::FromSeconds(15))
    foreach ($name in $policy.MachineEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, [string]$policy.MachineEnvironment[$name], 'Machine')
    }
    Start-Sleep -Seconds 2
    Write-Verbose "Build retained at $buildDirectory"
}
if ($Mode -eq 'Remove') {
    if ($service) { Stop-Service -Name $policy.ServiceName }
    if (Test-Path -LiteralPath $executable) {
        & $executable --release
        if ($LASTEXITCODE -ne 0) { throw 'Could not release existing job limits.' }
    }
    if ($service) {
        & sc.exe delete $policy.ServiceName | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove memory service.' }
    }
}
$serviceState = Get-CimInstance Win32_Service -Filter "Name='$($policy.ServiceName)'"
$installedPolicy = if (Test-Path -LiteralPath $policyPath) { Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json } else { $null }
$runtimePath = Join-Path $stateDirectory 'status.json'
$runtime = if (Test-Path -LiteralPath $runtimePath) { Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json } else { $null }
$installedHashPath = Join-Path $installDirectory 'source.sha256'
$sourceMatches = (Test-Path -LiteralPath $installedHashPath) -and (Get-Content -LiteralPath $installedHashPath -Raw).Trim() -eq $sourceHash
$policyMatches = $installedPolicy -and (($installedPolicy | ConvertTo-Json -Depth 5 -Compress) -ceq ($desiredPolicy | ConvertTo-Json -Depth 5 -Compress))
$runtimeHealthy = $runtime -and ([datetime]::UtcNow - [datetime]$runtime.utc).TotalSeconds -lt 20 -and @($runtime.errors).Count -eq 0
$guardHealthy = $runtime -and $runtime.earlyOom -and $runtime.earlyOom.mode -eq $policy.EarlyOom.Mode -and $runtime.earlyOom.state -ne 'Faulted'
$environmentState = foreach ($name in $policy.MachineEnvironment.Keys) {
    [pscustomobject]@{ Name = $name; Expected = $policy.MachineEnvironment[$name]; Machine = [Environment]::GetEnvironmentVariable($name, 'Machine') }
}
$environmentMatches = @($environmentState | Where-Object { $_.Machine -cne $_.Expected }).Count -eq 0
$result = [pscustomobject]@{
    Service = $policy.ServiceName
    State = if ($Mode -eq 'Remove' -and -not $serviceState) { 'removed' } elseif ($serviceState.State -eq 'Running' -and $serviceState.StartMode -eq 'Auto' -and $serviceState.StartName -eq 'LocalSystem' -and $policyMatches -and $sourceMatches -and $runtimeHealthy -and $guardHealthy -and $environmentMatches) { 'compliant' } else { 'drift detected' }
    StartMode = $serviceState.StartMode
    Account = $serviceState.StartName
    LimitGiB = $policy.LimitGiB
    Executables = $policy.Executables
    PollMilliseconds = $policy.PollMilliseconds
    PolicyMatches = [bool]$policyMatches
    SourceMatches = [bool]$sourceMatches
    RuntimeHealthy = [bool]$runtimeHealthy
    EarlyOomHealthy = [bool]$guardHealthy
    EarlyOom = $policy.EarlyOom
    MachineEnvironment = @($environmentState)
    Runtime = $runtime
    Log = Join-Path $stateDirectory 'events.jsonl'
}
if ($Json) { $result | ConvertTo-Json -Depth 8 } else { $result | Format-List | Out-Host }
if ($result.State -eq 'drift detected') { exit 1 }
