[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('razer-startup-test-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $fixtureRoot 'DataWorkStation\RazerRgb'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$savedLocalAppData = $env:LOCALAPPDATA
try {
    $openRgbDirectory = Join-Path $root 'OpenRGB-1.0\OpenRGB Windows 64-bit'
    New-Item -ItemType Directory -Path $openRgbDirectory -Force | Out-Null
    $startupExe = Join-Path $root 'RazerStartup.exe'
    & $compiler /nologo /target:winexe ('/out:' + $startupExe) (Join-Path $repositoryRoot 'scripts\razer-rgb\RazerStartup.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Startup compilation failed.' }
    # Both child stand-ins report whether Windows allocated a console. No hardware is accessed.
    $probeSource = Join-Path $fixtureRoot 'Probe.cs'
    @'
using System;
using System.IO;
using System.Runtime.InteropServices;
public static class Probe {
    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    public static void Main(string[] args) {
        string exe = System.Reflection.Assembly.GetExecutingAssembly().Location;
        File.WriteAllText(exe + ".result", GetConsoleWindow().ToInt64() + "\n" + String.Join("\n", args));
        // Stay alive after PowerShell exits to catch inherited-pipe or process-tree waits.
        string release = Path.Combine(Environment.GetEnvironmentVariable("LOCALAPPDATA"), "release-probes");
        DateTime deadline = DateTime.UtcNow.AddSeconds(30);
        while (!File.Exists(release) && DateTime.UtcNow < deadline) System.Threading.Thread.Sleep(25);
    }
}
'@ | Set-Content -LiteralPath $probeSource
    $fakeOpenRgb = Join-Path $openRgbDirectory 'OpenRGB.exe'
    & $compiler /nologo /target:exe ('/out:' + $fakeOpenRgb) $probeSource
    if ($LASTEXITCODE -ne 0) { throw 'Probe compilation failed.' }
    $fakeHelper = Join-Path $root 'RazerReactive.exe'
    Copy-Item -LiteralPath $fakeOpenRgb -Destination $fakeHelper
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'scripts\Start-RazerRgb.ps1') -Destination $root
    @{ Port = 6743; DurationMilliseconds = 2000; BaseColor = '0000FF'; PressColor = 'FFFFFF' } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'theme.json')
    $env:LOCALAPPDATA = $fixtureRoot
    $child = Start-Process -FilePath $startupExe -ArgumentList ('"' + (Join-Path $PSHOME 'pwsh.exe') + '"') -WindowStyle Hidden -PassThru
    if (-not $child.WaitForExit(15000)) { throw 'Startup fixture timed out.' }
    if ($child.ExitCode -ne 0) { throw "Startup failed: $(Get-Content (Join-Path $root 'startup.log') -Raw)" }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    while ((-not (Test-Path ($fakeOpenRgb + '.result')) -or -not (Test-Path ($fakeHelper + '.result'))) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    foreach ($path in @($fakeOpenRgb, $fakeHelper)) {
        $result = Get-Content -LiteralPath ($path + '.result')
        if ($result[0] -ne '0') { throw "Child received a console: $path" }
    }
    $rgbArguments = Get-Content -LiteralPath ($fakeOpenRgb + '.result')
    if ($rgbArguments[2] -ne (Join-Path $root 'config')) { throw 'Config path with spaces must remain one argument.' }
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'release-probes') -Value 'done'
    # A failing script must return its failure status and record that status.
    Set-Content -LiteralPath (Join-Path $root 'Start-RazerRgb.ps1') -Value 'exit 7'
    $child = Start-Process -FilePath $startupExe -ArgumentList ('"' + (Join-Path $PSHOME 'pwsh.exe') + '"') -WindowStyle Hidden -PassThru
    if (-not $child.WaitForExit(15000)) { throw 'Failure fixture timed out.' }
    $log = Get-Content -LiteralPath (Join-Path $root 'startup.log') -Raw
    if ($child.ExitCode -ne 7 -or $log -notmatch 'Launcher exit code: 7') { throw 'Startup failures must be logged and returned.' }
} finally {
    $env:LOCALAPPDATA = $savedLocalAppData
    if (Test-Path -LiteralPath $fixtureRoot) {
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'release-probes') -Value 'done'
        foreach ($probe in @(Get-Process OpenRGB,RazerReactive -ErrorAction Ignore | Where-Object { $_.Path -in @($fakeOpenRgb, $fakeHelper) })) {
            if (-not $probe.WaitForExit(5000)) { throw 'Fixture probe did not finish.' }
        }
    }
    # Only this unique temporary fixture is removed; no live installation is touched.
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedFixture.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped the temporary directory.' }
    if (Test-Path -LiteralPath $resolvedFixture) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
}
Write-Output 'Razer startup: both children have no console, spaced paths survive, and failures are logged.'
