function global:Import-MsvcBuildEnvironment {
    [CmdletBinding()]
    param([switch] $Force)

    if ($env:VSCMD_VER -and -not $Force) { return }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { return }
    $installationPath = @(& $vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -requires Microsoft.VisualStudio.Component.Windows11SDK.26100 `
        -property installationPath 2>$null | Select-Object -First 1)
    if (-not $installationPath) { return }
    $developerCommand = Join-Path $installationPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $developerCommand -PathType Leaf)) { return }
    $commandLine = "`"$developerCommand`" -no_logo -host_arch=amd64 -arch=amd64 >nul && set"
    $environmentLines = & $env:ComSpec /d /s /c $commandLine
    if ($LASTEXITCODE -ne 0) { return }
    foreach ($line in $environmentLines) {
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) { continue }
        $name = $line.Substring(0, $separator)
        $value = $line.Substring($separator + 1)
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

function Add-ProcessPathEntry {
    param([string] $Entry, [switch] $Prepend)
    if ([string]::IsNullOrWhiteSpace($Entry) -or -not (Test-Path -LiteralPath $Entry -PathType Container)) { return }
    $items = @($env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_.TrimEnd('\') -ine $Entry.TrimEnd('\') })
    $env:Path = if ($Prepend) { (@($Entry) + $items) -join ';' } else { ($items + @($Entry)) -join ';' }
}

foreach ($variableName in @('CC', 'CXX', 'CMAKE_GENERATOR', 'CARGO_HOME', 'RUSTUP_HOME', 'JAVA_HOME')) {
    $userValue = [Environment]::GetEnvironmentVariable($variableName, 'User')
    if (-not [string]::IsNullOrWhiteSpace($userValue)) { [Environment]::SetEnvironmentVariable($variableName, $userValue, 'Process') }
}
if (-not $env:CC) { $env:CC = 'cl.exe' }
if (-not $env:CXX) { $env:CXX = 'cl.exe' }
if (-not $env:CMAKE_GENERATOR) { $env:CMAKE_GENERATOR = 'Ninja' }
if (-not $env:CARGO_HOME) { $env:CARGO_HOME = Join-Path $env:USERPROFILE '.cargo' }
if (-not $env:RUSTUP_HOME) { $env:RUSTUP_HOME = Join-Path $env:USERPROFILE '.rustup' }

Add-ProcessPathEntry -Entry (Join-Path $env:CARGO_HOME 'bin')
if ($env:JAVA_HOME) { Add-ProcessPathEntry -Entry (Join-Path $env:JAVA_HOME 'bin') -Prepend }
Add-ProcessPathEntry -Entry (Join-Path $env:ProgramFiles 'CMake\bin')
$ninjaCommand = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Directory -Filter 'Ninja-build.Ninja_*' -ErrorAction Ignore |
    ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter 'ninja.exe' -Recurse -ErrorAction Ignore } |
    Select-Object -First 1
if ($ninjaCommand) { Add-ProcessPathEntry -Entry (Split-Path -Parent $ninjaCommand.FullName) }
Import-MsvcBuildEnvironment

Remove-Variable variableName, userValue, ninjaCommand -ErrorAction Ignore
