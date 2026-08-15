[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$profileSourceDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\profile'))
$templatePath = Join-Path $profileSourceDirectory 'Shell.ps1'
$componentNames = @('Config.ps1', 'Tools.ps1', 'Aliases.ps1', 'NativeDevelopment.ps1')
$beginMarker = '# BEGIN CODEX LINUX SHELL'
$endMarker = '# END CODEX LINUX SHELL'
$blockPattern = '(?s)' + [regex]::Escape($beginMarker) + '.*?' + [regex]::Escape($endMarker)
$template = Get-Content -LiteralPath $templatePath -Raw
$documents = [Environment]::GetFolderPath('MyDocuments')
$targets = @(
    (Join-Path $documents 'WindowsPowerShell\profile.ps1')
    (Join-Path $documents 'PowerShell\profile.ps1')
)

function Get-DesiredProfileContent {
    param([string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $template }
    $existing = Get-Content -LiteralPath $Path -Raw
    if ($existing -match [regex]::Escape($beginMarker)) {
        return [regex]::Replace($existing, $blockPattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $null = $match; $template })
    }
    return $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $template
}

function Test-ComponentDrift {
    param([string] $ProfilePath)

    $componentDirectory = Join-Path (Split-Path -Parent $ProfilePath) 'LinuxShell'
    foreach ($componentName in $componentNames) {
        $source = Join-Path $profileSourceDirectory $componentName
        $target = Join-Path $componentDirectory $componentName
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { return $true }
        if ((Get-Content -LiteralPath $source -Raw).TrimEnd() -cne (Get-Content -LiteralPath $target -Raw).TrimEnd()) {
            return $true
        }
    }
    return $false
}

$driftedTargets = @()
foreach ($target in $targets) {
    $existing = if (Test-Path -LiteralPath $target) { (Get-Content -LiteralPath $target -Raw).TrimEnd() } else { '' }
    $desired = (Get-DesiredProfileContent -Path $target).TrimEnd()
    if ($existing -cne $desired -or (Test-ComponentDrift -ProfilePath $target)) { $driftedTargets += $target }
}

if ($Mode -eq 'Test') {
    if ($driftedTargets.Count -eq 0) {
        Write-Host 'PowerShell profiles: compliant.'
        exit 0
    }
    Write-Host 'PowerShell profiles: drift detected.'
    $driftedTargets | ForEach-Object { Write-Host "- $_" }
    exit 1
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($target in $targets) {
    $desired = Get-DesiredProfileContent -Path $target
    $existing = if (Test-Path -LiteralPath $target) { (Get-Content -LiteralPath $target -Raw).TrimEnd() } else { '' }
    $profileChanged = $Mode -eq 'Reinitialize' -or $existing -cne $desired.TrimEnd()
    $componentDirectory = Join-Path (Split-Path -Parent $target) 'LinuxShell'
    $changedComponents = @($componentNames | Where-Object {
        $source = Join-Path $profileSourceDirectory $_
        $destination = Join-Path $componentDirectory $_
        $Mode -eq 'Reinitialize' -or
            -not (Test-Path -LiteralPath $destination -PathType Leaf) -or
            (Get-Content -LiteralPath $source -Raw).TrimEnd() -cne (Get-Content -LiteralPath $destination -Raw).TrimEnd()
    })

    if (-not $profileChanged -and $changedComponents.Count -eq 0) {
        Write-Host "Unchanged profile: $target"
        continue
    }

    $targetDirectory = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    if ($profileChanged) {
        if (Test-Path -LiteralPath $target) {
            Copy-Item -LiteralPath $target -Destination "$target.$timestamp.bak" -Force
        }
        Set-Content -LiteralPath $target -Value $desired -Encoding UTF8
        Write-Host "Updated profile loader: $target"
    }

    New-Item -ItemType Directory -Path $componentDirectory -Force | Out-Null
    foreach ($componentName in $changedComponents) {
        Copy-Item -LiteralPath (Join-Path $profileSourceDirectory $componentName) -Destination (Join-Path $componentDirectory $componentName) -Force
        Write-Host "Updated profile component: $(Join-Path $componentDirectory $componentName)"
    }
}

# Keep the btop process list focused on RAM consumers.
$btopConfig = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\aristocratos.btop4win_*\btop4win\btop.conf') -File -ErrorAction Ignore |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($btopConfig) {
    $current = Get-Content -LiteralPath $btopConfig.FullName -Raw
    $desired = $current -replace '(?m)^proc_sorting\s*=\s*\\?"[^"]*\\?"\s*$', 'proc_sorting = "memory"'
    if ($desired -cne $current) {
        Copy-Item -LiteralPath $btopConfig.FullName -Destination ($btopConfig.FullName + '.pre-memory-sort.bak') -Force
        [IO.File]::WriteAllText($btopConfig.FullName, $desired, [Text.UTF8Encoding]::new($false))
        Write-Host "Configured btop memory sorting: $($btopConfig.FullName)"
    }
}
