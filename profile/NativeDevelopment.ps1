function global:Import-MsvcBuildEnvironment {
    [CmdletBinding()]
    param([switch] $Force)

    if ($env:VSCMD_VER -and -not $Force) {
        [Environment]::SetEnvironmentVariable('CC', 'cl.exe', 'Process')
        [Environment]::SetEnvironmentVariable('CXX', 'cl.exe', 'Process')
        return
    }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) { throw 'MSVC activation requires vswhere.exe from Visual Studio Build Tools.' }
    $installationPath = @(& $vswhere -latest -products Microsoft.VisualStudio.Product.BuildTools `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -requires Microsoft.VisualStudio.Component.Windows11SDK.26100 `
        -property installationPath 2>$null | Select-Object -First 1)
    if (-not $installationPath) { throw 'No compatible x64 Visual Studio Build Tools instance was found.' }
    $developerCommand = Join-Path $installationPath 'Common7\Tools\VsDevCmd.bat'
    if (-not (Test-Path -LiteralPath $developerCommand -PathType Leaf)) { throw "MSVC developer environment command not found: $developerCommand" }
    $commandLine = "`"$developerCommand`" -no_logo -host_arch=amd64 -arch=amd64 >nul && set"
    $environmentLines = & $env:ComSpec /d /s /c $commandLine
    if ($LASTEXITCODE -ne 0) { throw "MSVC developer environment activation failed with exit code $LASTEXITCODE." }
    foreach ($line in $environmentLines) {
        $separator = $line.IndexOf('=')
        if ($separator -lt 1) { continue }
        $name = $line.Substring(0, $separator)
        $value = $line.Substring($separator + 1)
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
    [Environment]::SetEnvironmentVariable('CC', 'cl.exe', 'Process')
    [Environment]::SetEnvironmentVariable('CXX', 'cl.exe', 'Process')
}

function global:Enable-MsvcBuildEnvironment {
    [CmdletBinding()]
    param([switch] $Force)

    Import-MsvcBuildEnvironment -Force:$Force
    $linker = Get-Command link.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
    Write-Host "MSVC x64 environment active in this shell ($($linker.Source))."
}

Set-Alias -Name msvc-activate -Value Enable-MsvcBuildEnvironment -Scope Global
