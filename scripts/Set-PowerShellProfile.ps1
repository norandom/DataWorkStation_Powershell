[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$templatePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\profile\Shell.ps1'))
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
        return [regex]::Replace($existing, $blockPattern, [Text.RegularExpressions.MatchEvaluator]{ param($match) $template })
    }
    return $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $template
}

$driftedTargets = @()
foreach ($target in $targets) {
    $existing = if (Test-Path -LiteralPath $target) { (Get-Content -LiteralPath $target -Raw).TrimEnd() } else { '' }
    $desired = (Get-DesiredProfileContent -Path $target).TrimEnd()
    if ($existing -cne $desired) { $driftedTargets += $target }
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
    $changed = $Mode -eq 'Reinitialize' -or $target -in $driftedTargets
    if (-not $changed) {
        Write-Host "Unchanged profile: $target"
        continue
    }

    $targetDirectory = Split-Path -Parent $target
    New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    if (Test-Path -LiteralPath $target) {
        Copy-Item -LiteralPath $target -Destination "$target.$timestamp.bak" -Force
    }
    Set-Content -LiteralPath $target -Value $desired -Encoding UTF8
    Write-Host "Updated profile: $target"
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

