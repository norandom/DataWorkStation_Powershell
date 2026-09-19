[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile (Join-Path $root 'config\workload-memory-limits.psd1')
if ($policy.LimitGiB -ne 8) { throw 'Expected the reviewed 8 GiB workload budget.' }
if ($policy.MachineEnvironment.PYTEST_XDIST_AUTO_NUM_WORKERS -cne '3') { throw 'Expected three automatic pytest workers.' }
foreach ($name in @('python.exe', 'pythonw.exe', 'dotnet.exe')) {
    if ($name -in $policy.ProcessOnlyExecutables) { throw "Expected a shared tree budget: $name" }
}
foreach ($name in @('codex.exe', 'claude.exe', 'node.exe', 'bun.exe', 'agent.exe')) {
    if ($name -notin $policy.ProcessOnlyExecutables) { throw "Expected sandbox-compatible process limits: $name" }
}
foreach ($name in @('python.exe', 'pythonw.exe', 'dotnet.exe', 'codex.exe', 'claude.exe', 'opencode.exe', 'agy.exe', 'grok.exe', 'copilot.exe', 'cline.exe')) {
    if ($name -notin $policy.Executables) { throw "Missing workload: $name" }
}
foreach ($name in @('node.exe', 'java.exe', 'javaw.exe', 'chrome.exe', 'msedge.exe', 'vivaldi.exe', 'svchost.exe', 'pwsh.exe')) {
    if ($name -in $policy.Executables) { throw "Unscoped host or application: $name" }
}
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$buildDirectory = Join-Path ([IO.Path]::GetTempPath()) ('dws-memory-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildDirectory | Out-Null
$executable = Join-Path $buildDirectory 'MemoryLimits.exe'
& $compiler /nologo /platform:x64 /target:exe /r:System.ServiceProcess.dll /r:System.Management.dll /r:System.Web.Extensions.dll "/out:$executable" (Join-Path $root 'scripts\memory-limits\MemoryLimits.cs')
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
& $executable --self-test
if ($LASTEXITCODE -ne 0) { throw 'Kernel allocation-denial test failed.' }
Write-Host 'Workload targeting and kernel allocation-denial checks passed.'
