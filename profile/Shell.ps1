# BEGIN CODEX LINUX SHELL

$linuxShellProfileRoot = Join-Path $PSScriptRoot 'LinuxShell'
if (-not (Test-Path -LiteralPath $linuxShellProfileRoot -PathType Container)) {
    # Allows the loader to be dot-sourced directly from the repository too.
    $linuxShellProfileRoot = $PSScriptRoot
}

foreach ($component in 'Config.ps1', 'Tools.ps1', 'Aliases.ps1', 'NativeDevelopment.ps1') {
    $componentPath = Join-Path $linuxShellProfileRoot $component
    if (-not (Test-Path -LiteralPath $componentPath -PathType Leaf)) {
        Write-Warning "PowerShell profile component not found: $componentPath"
        continue
    }
    . $componentPath
}

Remove-Variable linuxShellProfileRoot, component, componentPath -ErrorAction Ignore

# END CODEX LINUX SHELL
