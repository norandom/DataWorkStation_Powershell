[CmdletBinding()]
param(
    [ValidateSet('Test', 'Smoke')]
    [string] $Mode = 'Test',
    [ValidateSet('All', 'Compiler', 'CMake', 'MsBuild', 'Rust', 'Java')]
    [string] $Fixture = 'All',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Invoke-StateTest {
    param([string] $Name, [string] $Script)
    $output = @(& (Get-Command pwsh.exe -ErrorAction Stop).Source -NoLogo -NoProfile -File (Join-Path $repositoryRoot $Script) -Mode Test -Json 2>&1)
    $code = $LASTEXITCODE
    [pscustomobject]@{
        Name = $Name
        State = if ($code -eq 0) { 'compliant' } else { 'drift detected' }
        Changed = $false
        Detail = (@($output | Select-Object -Last 20) -join "`n")
    }
}

function Invoke-CommandResult {
    param([string] $FilePath, [string[]] $ArgumentList)
    $started = Get-Date
    $output = @(& $FilePath @ArgumentList 2>&1)
    [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        DurationMilliseconds = [int] ((Get-Date) - $started).TotalMilliseconds
        Output = (@($output | Select-Object -Last 20) -join "`n")
    }
}

function Invoke-CompilerSmoke {
    param([string] $Root)
    Set-Content -LiteralPath (Join-Path $Root 'hello.c') -Encoding ASCII -Value "#include <stdio.h>`nint main(void){puts(`"c-ok`");return 0;}"
    Set-Content -LiteralPath (Join-Path $Root 'hello.cpp') -Encoding ASCII -Value "#include <iostream>`nint main(){std::cout << `"cpp-ok`";return 0;}"
    $c = Invoke-CommandResult -FilePath 'cl.exe' -ArgumentList @('/nologo', "/Fo:$(Join-Path $Root 'hello-c.obj')", "/Fe:$(Join-Path $Root 'hello-c.exe')", (Join-Path $Root 'hello.c'))
    if ($c.ExitCode -ne 0) { return $c }
    $cRun = Invoke-CommandResult -FilePath (Join-Path $Root 'hello-c.exe') -ArgumentList @()
    if ($cRun.ExitCode -ne 0) { return $cRun }
    $cpp = Invoke-CommandResult -FilePath 'cl.exe' -ArgumentList @('/nologo', '/EHsc', "/Fo:$(Join-Path $Root 'hello-cpp.obj')", "/Fe:$(Join-Path $Root 'hello-cpp.exe')", (Join-Path $Root 'hello.cpp'))
    if ($cpp.ExitCode -ne 0) { return $cpp }
    Invoke-CommandResult -FilePath (Join-Path $Root 'hello-cpp.exe') -ArgumentList @()
}

function Invoke-CMakeSmoke {
    param([string] $Root)
    $source = Join-Path $Root 'cmake'
    New-Item -ItemType Directory -Path $source -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'CMakeLists.txt') -Encoding UTF8 -Value "cmake_minimum_required(VERSION 3.20)`nproject(smoke LANGUAGES CXX)`nadd_executable(cmake_hello main.cpp)"
    Set-Content -LiteralPath (Join-Path $source 'main.cpp') -Encoding ASCII -Value "#include <iostream>`nint main(){std::cout << `"cmake-ok`";return 0;}"
    $build = Join-Path $source 'build'
    $configure = Invoke-CommandResult -FilePath 'cmake.exe' -ArgumentList @('-S', $source, '-B', $build)
    if ($configure.ExitCode -ne 0) { return $configure }
    $compile = Invoke-CommandResult -FilePath 'cmake.exe' -ArgumentList @('--build', $build)
    if ($compile.ExitCode -ne 0) { return $compile }
    Invoke-CommandResult -FilePath (Join-Path $build 'cmake_hello.exe') -ArgumentList @()
}

function Invoke-MsBuildSmoke {
    param([string] $Root)
    Set-Content -LiteralPath (Join-Path $Root 'msbuild-hello.cpp') -Encoding ASCII -Value "#include <iostream>`nint main(){std::cout << `"msbuild-ok`";return 0;}"
    $project = @'
<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Target Name="Build">
    <Exec Command="cl.exe /nologo /EHsc /Fe:msbuild-hello.exe msbuild-hello.cpp" />
  </Target>
</Project>
'@
    Set-Content -LiteralPath (Join-Path $Root 'smoke.proj') -Encoding UTF8 -Value $project
    Push-Location $Root
    try {
        $build = Invoke-CommandResult -FilePath 'msbuild.exe' -ArgumentList @('smoke.proj', '/nologo', '/verbosity:minimal')
        if ($build.ExitCode -ne 0) { return $build }
        Invoke-CommandResult -FilePath (Join-Path $Root 'msbuild-hello.exe') -ArgumentList @()
    } finally { Pop-Location }
}

function Invoke-RustSmoke {
    param([string] $Root)
    Set-Content -LiteralPath (Join-Path $Root 'hello.rs') -Encoding ASCII -Value 'fn main(){println!("rust-ok");}'
    $compile = Invoke-CommandResult -FilePath 'rustc.exe' -ArgumentList @((Join-Path $Root 'hello.rs'), '-o', (Join-Path $Root 'rust-hello.exe'))
    if ($compile.ExitCode -ne 0) { return $compile }
    $run = Invoke-CommandResult -FilePath (Join-Path $Root 'rust-hello.exe') -ArgumentList @()
    if ($run.ExitCode -ne 0) { return $run }
    $crate = Join-Path $Root 'cargo-smoke'
    $new = Invoke-CommandResult -FilePath 'cargo.exe' -ArgumentList @('new', '--lib', '--quiet', $crate)
    if ($new.ExitCode -ne 0) { return $new }
    Push-Location $crate
    try { Invoke-CommandResult -FilePath 'cargo.exe' -ArgumentList @('test', '--quiet') } finally { Pop-Location }
}

function Invoke-JavaSmoke {
    param([string] $Root)
    $source = @'
public class Hello {
    public static void main(String[] args) { System.out.println("java-ok"); }
}
'@
    Set-Content -LiteralPath (Join-Path $Root 'Hello.java') -Encoding ASCII -Value $source
    $compile = Invoke-CommandResult -FilePath 'javac.exe' -ArgumentList @((Join-Path $Root 'Hello.java'))
    if ($compile.ExitCode -ne 0) { return $compile }
    Invoke-CommandResult -FilePath 'java.exe' -ArgumentList @('-cp', $Root, 'Hello')
}

if ($Mode -eq 'Test') {
    $resources = @(
        Invoke-StateTest -Name 'MsvcBuildTools' -Script 'scripts\Set-MsvcBuildToolsState.ps1'
        Invoke-StateTest -Name 'CMake' -Script 'scripts\Set-CMakeState.ps1'
        Invoke-StateTest -Name 'RustToolchain' -Script 'scripts\Set-RustState.ps1'
        Invoke-StateTest -Name 'JavaToolchain' -Script 'scripts\Set-JavaState.ps1'
    )
    $result = [pscustomobject]@{
        SchemaVersion = 1; Mode = 'Test'; State = if ('drift detected' -in $resources.State) { 'drift detected' } else { 'compliant' }
        Changed = $false; Resources = $resources
    }
    if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $resources | Format-Table Name,State,Changed -AutoSize | Out-Host }
    if ($result.State -ne 'compliant') { exit 1 }
    exit 0
}

. (Join-Path $repositoryRoot 'profile\NativeDevelopment.ps1')
Import-MsvcBuildEnvironment
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("DataWorkStation-native-" + [guid]::NewGuid().ToString('N'))
$resolvedTempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$resolvedTemporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
if (-not $resolvedTemporaryRoot.StartsWith($resolvedTempBase, [StringComparison]::OrdinalIgnoreCase)) { throw 'Refusing an unsafe smoke workspace.' }
New-Item -ItemType Directory -Path $resolvedTemporaryRoot -Force | Out-Null
try {
    $fixtures = if ($Fixture -eq 'All') { @('Compiler', 'CMake', 'MsBuild', 'Rust', 'Java') } else { @($Fixture) }
    $results = foreach ($name in $fixtures) {
        $fixtureRoot = Join-Path $resolvedTemporaryRoot $name
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
        try {
            $commandResult = & (Get-Command "Invoke-$name`Smoke" -CommandType Function) -Root $fixtureRoot
            [pscustomobject]@{ Fixture = $name; Status = if ($commandResult.ExitCode -eq 0) { 'passed' } else { 'failed' }; ExitCode = $commandResult.ExitCode; DurationMilliseconds = $commandResult.DurationMilliseconds; Output = $commandResult.Output }
        } catch {
            [pscustomobject]@{ Fixture = $name; Status = 'failed'; ExitCode = $null; DurationMilliseconds = 0; Output = $_.Exception.Message }
        }
    }
    $result = [pscustomobject]@{ SchemaVersion = 1; Mode = 'Smoke'; State = if ('failed' -in $results.Status) { 'failed' } else { 'passed' }; Changed = $false; Results = @($results) }
    if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $results | Format-Table Fixture,Status,ExitCode,DurationMilliseconds -AutoSize | Out-Host }
    if ($result.State -ne 'passed') { exit 1 }
} finally {
    if ($resolvedTemporaryRoot.StartsWith($resolvedTempBase, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTemporaryRoot)) {
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}
