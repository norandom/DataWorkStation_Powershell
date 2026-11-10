# Native Windows entry point: usable by humans and agents with -NoProfile.
$ErrorActionPreference = 'Stop'
$configuration = (Import-PowerShellDataFile (Join-Path $PSScriptRoot '../config/developer-tools.psd1')).Dagger
$binary = Join-Path $env:LOCALAPPDATA "Programs/Dagger/$($configuration.Version)/dagger.exe"
if (-not (Test-Path -LiteralPath $binary)) { throw 'Run scripts/Set-WindowsDaggerState.ps1 -Mode Ensure first.' }
$podman = Join-Path $env:ProgramFiles 'RedHat/Podman'
$oldPath = $env:PATH
$oldRunner = $env:_EXPERIMENTAL_DAGGER_RUNNER_HOST
$oldTheme = $env:FORCE_DARK_MODE
$originalLocation = Get-Location
# Dagger filesync cannot resolve ancestor directory junctions on Windows.
$workingPath = $originalLocation.Path
$ancestor = Get-Item -LiteralPath $workingPath
while ($ancestor) {
    if ($ancestor.LinkType -eq 'Junction' -or $ancestor.LinkType -eq 'SymbolicLink') {
        $suffix = $workingPath.Substring($ancestor.FullName.Length).TrimStart('\', '/')
        $workingPath = Join-Path ($ancestor.ResolveLinkTarget($true).FullName) $suffix
        break
    }
    $ancestor = $ancestor.Parent
}
try {
    Set-Location -LiteralPath $workingPath
    $env:PATH = "$podman;$oldPath"
    $env:_EXPERIMENTAL_DAGGER_RUNNER_HOST = "image+podman://$($configuration.EngineImage)"
    # Avoid blocking terminal-theme detection in noninteractive Windows agents.
    $env:FORCE_DARK_MODE = '1'
    & $binary @args
    $result = $LASTEXITCODE
} finally {
    $env:PATH = $oldPath
    $env:_EXPERIMENTAL_DAGGER_RUNNER_HOST = $oldRunner
    $env:FORCE_DARK_MODE = $oldTheme
    Set-Location -LiteralPath $originalLocation.Path
}
exit $result
