[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Test', 'Ensure')][string] $Mode = 'Test',
    [string] $Root = [Environment]::GetEnvironmentVariable('DEVELOPER_STORAGE_ROOT', 'User'),
    [switch] $MigrateCaches
)
$ErrorActionPreference = 'Stop'
if (-not $Root) { throw 'Specify -Root, for example D:\BuildArtifacts.' }
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if ($Root -match '^[A-Za-z]:$') { throw 'Use a dedicated directory, not a drive root.' }
$settings = [ordered]@{
    DEVELOPER_STORAGE_ROOT = $Root
    UV_CACHE_DIR = Join-Path $Root 'uv'
    npm_config_cache = Join-Path $Root 'npm'
    CARGO_HOME = Join-Path $Root 'cargo'
    CARGO_TARGET_DIR = Join-Path $Root 'cargo-target'
    PIP_CACHE_DIR = Join-Path $Root 'pip'
    BUN_INSTALL_CACHE_DIR = Join-Path $Root 'bun'
    DEVELOPER_TEMP = Join-Path $Root 'Temp'
    GOCACHE = Join-Path $Root 'go-build'
    GOMODCACHE = Join-Path $Root 'go-mod'
    NUGET_PACKAGES = Join-Path $Root 'nuget\packages'
    PLAYWRIGHT_BROWSERS_PATH = Join-Path $Root 'playwright'
    DENO_DIR = Join-Path $Root 'deno'
    _NT_SYMBOL_PATH = 'srv*' + (Join-Path $Root 'symbols') + '*https://msdl.microsoft.com/download/symbols'
}
$sources = @(
    @{ Source = Join-Path $env:LOCALAPPDATA 'uv\cache'; Destination = $settings.UV_CACHE_DIR }
    @{ Source = Join-Path $env:LOCALAPPDATA 'npm-cache'; Destination = $settings.npm_config_cache }
    @{ Source = Join-Path $env:USERPROFILE '.cargo'; Destination = $settings.CARGO_HOME }
    @{ Source = Join-Path $env:LOCALAPPDATA 'pip\Cache'; Destination = $settings.PIP_CACHE_DIR }
    @{ Source = Join-Path $env:USERPROFILE '.bun\install\cache'; Destination = $settings.BUN_INSTALL_CACHE_DIR }
    @{ Source = Join-Path $env:LOCALAPPDATA 'pnpm\store'; Destination = Join-Path $Root 'pnpm' }
    @{ Source = Join-Path $env:LOCALAPPDATA 'go-build'; Destination = $settings.GOCACHE }
    @{ Source = Join-Path $env:USERPROFILE 'go\pkg\mod'; Destination = $settings.GOMODCACHE }
    @{ Source = Join-Path $env:USERPROFILE '.nuget\packages'; Destination = $settings.NUGET_PACKAGES }
    @{ Source = Join-Path $env:LOCALAPPDATA 'ms-playwright'; Destination = $settings.PLAYWRIGHT_BROWSERS_PATH }
    @{ Source = Join-Path $env:LOCALAPPDATA 'deno'; Destination = $settings.DENO_DIR }
)
foreach ($setting in $settings.GetEnumerator()) {
    if ($Mode -eq 'Test') {
        [pscustomobject]@{ Variable = $setting.Key; Desired = $setting.Value; Compliant = [Environment]::GetEnvironmentVariable($setting.Key, 'User') -eq $setting.Value }
    }
}
if ($Mode -eq 'Test') { return }
if (-not $PSCmdlet.ShouldProcess($Root, 'Configure developer storage; optionally migrate caches and keep compatibility junctions')) { return }
New-Item -ItemType Directory -Path $Root -Force | Out-Null
if ((Get-Item -LiteralPath $Root).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Storage root must be a real directory.' }
if ($MigrateCaches) {
    foreach ($entry in $sources) {
        $source = [IO.Path]::GetFullPath($entry.Source)
        $destination = [IO.Path]::GetFullPath($entry.Destination)
        if (-not $destination.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination escaped the storage root.' }
        if (-not (Test-Path -LiteralPath $source)) { continue }
        $sourceItem = Get-Item -LiteralPath $source -Force
        if ($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if ($sourceItem.Target -contains $destination) { continue }
            throw "Source already redirects elsewhere: $source"
        }
        Write-Host "Migrating $source -> $destination"
        # Copy first; only remove source files which robocopy successfully transfers.
        & robocopy.exe $source $destination /E /MOVE /XJ /SL /COPY:DAT /DCOPY:DAT /MT:8 /R:1 /W:1 /NFL /NDL /NP
        if ($LASTEXITCODE -lt 0 -or $LASTEXITCODE -ge 8) { throw "Cache migration failed ($LASTEXITCODE). Both locations may contain data; rerun to resume." }
        # /XJ intentionally leaves reparse points. Move symbolic links themselves,
        # never traverse their targets. Windows requires elevation for this step.
        if (Test-Path -LiteralPath $source) {
            $remaining = @(Get-ChildItem -LiteralPath $source -Recurse -Force)
            $links = @($remaining | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
            foreach ($link in $links) {
                $relative = $link.FullName.Substring($source.Length).TrimStart('\')
                $linkDestination = [IO.Path]::GetFullPath((Join-Path $destination $relative))
                if (-not $linkDestination.StartsWith($destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Link destination escaped cache directory.' }
                New-Item -ItemType Directory -Path (Split-Path -Parent $linkDestination) -Force | Out-Null
                if ($link.LinkType -eq 'SymbolicLink') {
                    Move-Item -LiteralPath $link.FullName -Destination $linkDestination -Force -ErrorAction Stop
                } elseif ($link.LinkType -eq 'Junction') {
                    $originalTarget = [IO.Path]::GetFullPath([string] $link.Target)
                    if (-not $originalTarget.StartsWith($source + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Junction points outside this cache: $($link.FullName)" }
                    $newTarget = Join-Path $destination $originalTarget.Substring($source.Length).TrimStart('\')
                    if (-not (Test-Path -LiteralPath $newTarget -PathType Container)) { throw "Transferred junction target is missing: $newTarget" }
                    New-Item -ItemType Junction -Path $linkDestination -Target $newTarget | Out-Null
                    # Delete the old junction entry only, never its target directory.
                    [IO.Directory]::Delete($link.FullName)
                } else { throw "Unsupported reparse point: $($link.FullName)" }
            }
            # Remove only empty source directories after successful transfers.
            foreach ($directory in @($remaining | Where-Object PSIsContainer | Sort-Object { $_.FullName.Length } -Descending)) {
                if (Test-Path -LiteralPath $directory.FullName) {
                    if (-not @(Get-ChildItem -LiteralPath $directory.FullName -Force).Count) { Remove-Item -LiteralPath $directory.FullName -Force }
                }
            }
            if (-not @(Get-ChildItem -LiteralPath $source -Force).Count) { Remove-Item -LiteralPath $source -Force }
        }
        if (Test-Path -LiteralPath $source) { throw "Source was not emptied; inspect before creating a junction: $source" }
        New-Item -ItemType Junction -Path $source -Target $destination | Out-Null
    }
}
foreach ($setting in $settings.GetEnumerator()) {
    if ($setting.Key -notin @('DEVELOPER_STORAGE_ROOT', '_NT_SYMBOL_PATH')) { New-Item -ItemType Directory -Path $setting.Value -Force | Out-Null }
    [Environment]::SetEnvironmentVariable($setting.Key, $setting.Value, 'User')
    [Environment]::SetEnvironmentVariable($setting.Key, $setting.Value, 'Process')
}
New-Item -ItemType Directory -Path (Join-Path $Root 'symbols') -Force | Out-Null
$pnpm = Get-Command pnpm.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
& $pnpm.Source config set store-dir (Join-Path $Root 'pnpm') --global
if ($LASTEXITCODE -ne 0) { throw 'pnpm store configuration failed.' }
Write-Host 'Developer storage configured. Open a new developer shell for the new environment and Temp directory.'
