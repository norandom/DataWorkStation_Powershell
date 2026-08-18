[CmdletBinding()]
param(
    [ValidateSet('All', 'ModuleContract', 'MsvcContract', 'StateContract', 'SafetyContract', 'ProfileContract', 'EnvironmentContract', 'DualShellContract', 'CMakeContract', 'RustContract', 'JavaContract', 'IntegrationContract', 'CommandSurface', 'CompilerSmoke', 'CMakeSmoke', 'MsBuildSmoke', 'RustSmoke', 'JavaSmoke')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    Get-Content -LiteralPath $path -Raw
}

function Get-NativeConfiguration {
    $path = Join-Path $repositoryRoot 'config\native-development.psd1'
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'native development configuration exists'
    if (Test-Path -LiteralPath $path -PathType Leaf) { Import-PowerShellDataFile -LiteralPath $path }
}

function Invoke-External {
    param([string] $FilePath, [string[]] $ArgumentList)
    $output = @(& $FilePath @ArgumentList 2>&1)
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Test-ModuleContract {
    $catalog = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $expected = @{
        MsvcBuildTools = @('Sudo', 'PowerShell7')
        CMake = @('PowerShell7')
        RustToolchain = @('MsvcBuildTools', 'PowerShell7')
        JavaToolchain = @('PowerShell7')
        NativeDevelopment = @('MsvcBuildTools', 'CMake', 'RustToolchain', 'JavaToolchain', 'PowerShellProfile')
    }
    foreach ($name in $expected.Keys) {
        $module = @($catalog.Modules | Where-Object Name -eq $name)
        Assert-True ($module.Count -eq 1) "module '$name' exists once"
        if ($module.Count -eq 1) {
            Assert-True ($module[0].Stage -eq 'Extended') "module '$name' is Extended stage"
            Assert-True ($module[0].Runtime -eq 'PowerShell7') "module '$name' uses PowerShell 7 orchestration"
            foreach ($dependency in $expected[$name]) {
                Assert-True ($module[0].DependsOn -contains $dependency) "module '$name' depends on '$dependency'"
            }
        }
    }
    $aggregate = @($catalog.Modules | Where-Object Name -eq 'NativeDevelopment')
    if ($aggregate.Count -eq 1) { Assert-True ([bool] $aggregate[0].Default) 'aggregate is selected by the default workstation run' }

    $apply = Get-Source 'Apply-Workstation.ps1'
    foreach ($name in $expected.Keys) {
        Assert-True ($apply -match "'$name'") "orchestrator exposes '$name'"
    }
}

function Test-MsvcContract {
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    Assert-True ($configuration.Msvc.PackageId -eq 'Microsoft.VisualStudio.2022.BuildTools') 'standalone Build Tools package is declared'
    Assert-True ($configuration.Msvc.RequiredComponents -contains 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64') 'latest x64/x86 MSVC component is declared'
    Assert-True ($configuration.Msvc.RequiredComponents -contains 'Microsoft.VisualStudio.Component.Windows11SDK.26100') 'Windows 11 SDK 26100 component is declared'
    Assert-True ($configuration.Msvc.RequiredComponents.Count -eq 2) 'only two explicit Build Tools components are selected'
    foreach ($pattern in @('ARM', 'ATL', 'MFC', 'CLI', 'UWP', 'IDE')) {
        Assert-True (@($configuration.Msvc.ExcludedComponentPatterns | Where-Object { $_ -match $pattern }).Count -gt 0) "excluded component pattern '$pattern' is declared"
    }
    $state = Get-Source 'scripts/Set-MsvcBuildToolsState.ps1'
    Assert-True ($state -match "ValidateSet\('Test', 'Ensure', 'Reinitialize'\)") 'MSVC state exposes supported modes'
    Assert-True ($state -match 'vswhere\.exe') 'MSVC state uses the registered instance locator'
    Assert-True ($state -match 'ConvertTo-Json') 'MSVC state supports bounded JSON'
    Assert-True ($state -match '--norestart') 'MSVC installer suppresses automatic restart'
}

function Test-StateContract {
    foreach ($path in @('scripts/Set-MsvcBuildToolsState.ps1', 'scripts/Set-CMakeState.ps1', 'scripts/Set-RustState.ps1', 'scripts/Set-JavaState.ps1', 'scripts/Set-NativeDevelopmentState.ps1')) {
        $source = Get-Source $path
        Assert-True ($source -match 'if \(\$Mode -eq ''Test''\)') "$path has an observational Test branch"
        Assert-True ($source -match 'Changed') "$path reports whether state changed"
        Assert-True ($source -match 'ConvertTo-Json') "$path supports machine output"
    }
}

function Test-SafetyContract {
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    $joinedPackages = @($configuration.Packages.Values) -join ';'
    Assert-True ($joinedPackages -notmatch 'mingw|msys|cygwin|git') 'package declarations contain no Unix-emulation toolchain'
    Assert-True ($configuration.Rust.Toolchain -eq 'stable-x86_64-pc-windows-msvc') 'Rust declares only the native MSVC host'
    $msvc = Get-Source 'scripts/Set-MsvcBuildToolsState.ps1'
    Assert-True ($msvc -notmatch '--includeRecommended|--includeOptional|Workload\.') 'Build Tools install never expands a workload'
    Assert-True ($msvc -notmatch 'Restart-Computer|shutdown\.exe') 'Build Tools state never restarts Windows'
}

function Test-ProfileContract {
    $profileSource = Get-Source 'profile/NativeDevelopment.ps1'
    Assert-True ($profileSource -match 'function global:Import-MsvcBuildEnvironment') 'profile exposes explicit MSVC environment import'
    Assert-True ($profileSource -match 'function global:Enable-MsvcBuildEnvironment') 'profile separates the human activation surface from silent automation'
    Assert-True ($profileSource -match "Set-Alias -Name msvc-activate -Value Enable-MsvcBuildEnvironment -Scope Global") 'profile exposes the human msvc-activate command'
    Assert-True ($profileSource -match 'VsDevCmd\.bat') 'profile uses the vendor developer environment'
    Assert-True ($profileSource -match 'host_arch=amd64' -and $profileSource -match 'arch=amd64') 'profile selects x64 host and target'
    Assert-True ($profileSource -match 'VSCMD_VER') 'profile avoids repeated initialization'
    Assert-True ($profileSource -match "IndexOf\('='\)") 'profile preserves environment values containing equals signs'
    Assert-True ($profileSource -notmatch '(?m)^\s*Import-MsvcBuildEnvironment\s*$') 'profile does not activate MSVC during shell startup'
    Assert-True ($profileSource -match "SetEnvironmentVariable\('CC', 'cl\.exe', 'Process'\)" -and
        $profileSource -match "SetEnvironmentVariable\('CXX', 'cl\.exe', 'Process'\)") 'explicit activation adds process-only compiler selectors'
    $deployer = Get-Source 'scripts/Set-PowerShellProfile.ps1'
    Assert-True ($deployer -match 'NativeDevelopment\.ps1') 'profile resource deploys the native development component'
}

function Test-EnvironmentContract {
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    Assert-True (-not $configuration.Environment.ContainsKey('CC')) 'CC is not persisted outside explicit MSVC activation'
    Assert-True (-not $configuration.Environment.ContainsKey('CXX')) 'CXX is not persisted outside explicit MSVC activation'
    Assert-True ($configuration.Environment.CMakeGenerator -eq 'Ninja') 'Ninja is the CMake default'
    Assert-True ($configuration.Environment.CargoHome -eq '.cargo') 'Cargo home is user-relative'
    Assert-True ($configuration.Environment.RustupHome -eq '.rustup') 'Rustup home is user-relative'
    Assert-True (-not $configuration.Environment.ContainsKey('AR')) 'AR is not globally forced'
    Assert-True (-not $configuration.Environment.ContainsKey('LD')) 'LD is not globally forced'
    Assert-True (-not $configuration.Environment.ContainsKey('RUSTUP_TOOLCHAIN')) 'Rust project toolchain is not globally overridden'
    Assert-True (-not $configuration.Environment.ContainsKey('CARGO_BUILD_TARGET')) 'Rust project target is not globally overridden'
    $msvc = Get-Source 'scripts/Set-MsvcBuildToolsState.ps1'
    Assert-True ($msvc -like '*SetEnvironmentVariable(''CC'', $null, ''User'')*' -and
        $msvc -like '*SetEnvironmentVariable(''CXX'', $null, ''User'')*') 'MSVC Ensure removes legacy persistent compiler selectors'
    Assert-True ($msvc -match '\$packageDrift\s*=' -and
        $msvc -match 'if \(\$packageDrift -or \$Mode -eq ''Reinitialize''\)') 'compiler-variable-only drift does not invoke the Build Tools installer'
}

function Test-DualShellContract {
    $profilePath = Join-Path $repositoryRoot 'profile\NativeDevelopment.ps1'
    Assert-True (Test-Path -LiteralPath $profilePath -PathType Leaf) 'native development profile component exists'
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) { return }
    foreach ($runtime in @((Get-Command powershell.exe -ErrorAction Stop).Source, (Get-Command pwsh.exe -ErrorAction Stop).Source)) {
        $escaped = $profilePath.Replace("'", "''")
        $command = "`$env:VSCMD_VER=`$null; `$env:CC=`$null; `$env:CXX=`$null; . '$escaped'; [pscustomobject]@{ ImportCommand=[bool](Get-Command Import-MsvcBuildEnvironment -ErrorAction Ignore); AliasTarget=(Get-Alias msvc-activate -ErrorAction Ignore).Definition; AutoActivated=[bool]`$env:VSCMD_VER; CC=`$env:CC; CXX=`$env:CXX } | ConvertTo-Json -Compress"
        $result = Invoke-External -FilePath $runtime -ArgumentList @('-NoLogo', '-NoProfile', '-Command', $command)
        Assert-True ($result.ExitCode -eq 0) "profile component parses and loads in '$runtime'"
        $jsonLine = @($result.Output | Where-Object { [string] $_ -match '^\s*\{' } | Select-Object -Last 1)
        Assert-True ($jsonLine.Count -eq 1) "'$runtime' produces a structured profile surface"
        if ($jsonLine.Count -eq 1) {
            $surface = $jsonLine[0] | ConvertFrom-Json
            Assert-True $surface.ImportCommand "'$runtime' exposes Import-MsvcBuildEnvironment"
            Assert-True ($surface.AliasTarget -eq 'Enable-MsvcBuildEnvironment') "'$runtime' exposes msvc-activate"
            Assert-True (-not $surface.AutoActivated -and -not $surface.CC -and -not $surface.CXX) "'$runtime' leaves MSVC environment state inactive at startup"
        }
    }
}

function Test-CMakeContract {
    foreach ($path in @('.config/cmake.winget', '.config/ninja.winget')) { Assert-True (Test-Path -LiteralPath (Join-Path $repositoryRoot $path) -PathType Leaf) "$path exists" }
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    Assert-True ($configuration.Packages.CMake -eq 'Kitware.CMake') 'official CMake package is declared'
    Assert-True ($configuration.Packages.Ninja -eq 'Ninja-build.Ninja') 'official Ninja package is declared'
    $state = Get-Source 'scripts/Set-CMakeState.ps1'
    Assert-True ($state -match 'CMAKE_GENERATOR') 'CMake state manages the default generator'
    Assert-True ($state -notmatch 'bash|mingw|msys|cygwin') 'CMake state does not configure a Unix shell'
}

function Test-RustContract {
    Assert-True (Test-Path -LiteralPath (Join-Path $repositoryRoot '.config\rustup.winget') -PathType Leaf) 'rustup package declaration exists'
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    Assert-True ($configuration.Packages.Rustup -eq 'Rustlang.Rustup') 'official rustup package is declared'
    Assert-True ($configuration.Rust.Profile -eq 'default') 'Rust default developer profile is declared'
    Assert-True ($configuration.Rust.Toolchain -eq 'stable-x86_64-pc-windows-msvc') 'stable x64 MSVC toolchain is declared'
    $state = Get-Source 'scripts/Set-RustState.ps1'
    foreach ($name in @('CARGO_HOME', 'RUSTUP_HOME', 'rustup default')) { Assert-True ($state -match [regex]::Escape($name)) "Rust state manages '$name'" }
    Assert-True ($state -notmatch "SetEnvironmentVariable\('RUSTUP_TOOLCHAIN'|SetEnvironmentVariable\('CARGO_BUILD_TARGET'") 'Rust state does not force project override variables'
}

function Test-JavaContract {
    Assert-True (Test-Path -LiteralPath (Join-Path $repositoryRoot '.config\java.winget') -PathType Leaf) 'OpenJDK package declaration exists'
    $configuration = Get-NativeConfiguration
    if (-not $configuration) { return }
    Assert-True ($configuration.Packages.Java -eq 'Microsoft.OpenJDK.21') 'official Microsoft OpenJDK 21 package is declared'
    Assert-True ($configuration.Java.MajorVersion -eq 21) 'Java 21 LTS major is declared'
    Assert-True (@($configuration.Java.Commands) -join ',' -eq 'java.exe,javac.exe,jar.exe,jshell.exe') 'runtime and development commands are declared'
    $state = Get-Source 'scripts/Set-JavaState.ps1'
    foreach ($name in @('JAVA_HOME', 'java.exe', 'javac.exe')) {
        Assert-True ($state -match [regex]::Escape($name)) "Java state manages '$name'"
    }
    Assert-True ($state -match 'configuration\.Java\.Commands') 'Java state validates every data-driven JDK command'
    Assert-True ($state -match 'Get-ChildItem' -and $state -match 'jdk-21') 'Java root is discovered dynamically rather than hard-coded to a patch release'
    Assert-True ($state -match 'SetEnvironmentVariable') 'Java state persists the stable user environment'
    $malware = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\malware-analysis-tools.psd1')
    $ghidraJdk = @($malware.Packages | Where-Object Name -eq 'OpenJDK')
    Assert-True ($ghidraJdk.Count -eq 1 -and $ghidraJdk[0].Id -eq $configuration.Packages.Java) 'Ghidra reuses the independently declared OpenJDK package'
    Assert-True (@($malware.Archives | Where-Object Name -eq 'Ghidra').Count -eq 1) 'Ghidra remains an archive tool without a private JRE declaration'
}

function Test-IntegrationContract {
    $state = Get-Source 'scripts/Set-NativeDevelopmentState.ps1'
    Assert-True ($state -match "ValidateSet\('Test', 'Smoke'\)") 'aggregate resource separates observation from smoke execution'
    foreach ($fixture in @('Compiler', 'CMake', 'MsBuild', 'Rust', 'Java')) { Assert-True ($state -match $fixture) "aggregate resource exposes $fixture smoke" }
    Assert-True ($state -match 'New-Item.*Directory' -and $state -match 'Remove-Item.*Recurse') 'smoke uses and removes a temporary directory'
    Assert-True ($state -notmatch 'Get-ChildItem.*repositoryRoot.*-Recurse') 'smoke never discovers repository source recursively'
}

function Test-CommandSurface {
    $capabilities = Get-Source 'config/capabilities.psd1'
    Assert-True ($capabilities -match "Id = 'native-development'") 'capability route exists'
    foreach ($path in @('README.md', 'docs/desired-state.md', 'docs/workstation-modules.md', 'docs/Aliases.md', 'docs/sample-outputs.md')) {
        $source = Get-Source $path
        Assert-True ($source -match 'NativeDevelopment|native development') "$path documents native development"
    }
}

function Invoke-SmokeSection {
    param([string] $Fixture)
    $scriptPath = Join-Path $repositoryRoot 'scripts\Set-NativeDevelopmentState.ps1'
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'aggregate smoke resource exists'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { return }
    $result = Invoke-External -FilePath (Get-Command pwsh.exe -ErrorAction Stop).Source -ArgumentList @('-NoLogo', '-NoProfile', '-File', $scriptPath, '-Mode', 'Smoke', '-Fixture', $Fixture, '-Json')
    Assert-True ($result.ExitCode -eq 0) "$Fixture smoke passes: $($result.Output -join ' ')"
}

function Test-CompilerSmoke { Invoke-SmokeSection -Fixture Compiler }
function Test-CMakeSmoke { Invoke-SmokeSection -Fixture CMake }
function Test-MsBuildSmoke { Invoke-SmokeSection -Fixture MsBuild }
function Test-RustSmoke { Invoke-SmokeSection -Fixture Rust }
function Test-JavaSmoke { Invoke-SmokeSection -Fixture Java }

$sections = if ($Section -eq 'All') {
    @('ModuleContract', 'MsvcContract', 'StateContract', 'SafetyContract', 'ProfileContract', 'EnvironmentContract', 'DualShellContract', 'CMakeContract', 'RustContract', 'JavaContract', 'IntegrationContract', 'CommandSurface')
} else { @($Section) }
foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "Native development contract tests passed ($script:assertions assertions)."
