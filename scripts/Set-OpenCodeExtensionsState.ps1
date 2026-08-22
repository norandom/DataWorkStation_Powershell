[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$asJson = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$declaration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\opencode-extensions.psd1')
$configRoot = [Environment]::ExpandEnvironmentVariables($declaration.ConfigRoot)
$installRoot = [Environment]::ExpandEnvironmentVariables($declaration.OpenUltraCode.InstallRoot)
$versionRoot = Join-Path $installRoot $declaration.OpenUltraCode.Version
$cacheRoot = Join-Path $repositoryRoot $declaration.CacheRoot
$backupRoot = Join-Path $cacheRoot 'backups'

function Get-LowerHash {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-InventoryIdentity {
    param([Parameter(Mandatory = $true)][string] $Root)
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return [pscustomobject]@{ FileCount = 0; Sha256 = $null }
    }
    $lines = @(Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($Root.Length + 1).Replace('\', '/')
        "$relative`t$((Get-LowerHash $_.FullName))"
    } | Sort-Object)
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $identity = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
    [pscustomobject]@{ FileCount = $lines.Count; Sha256 = $identity }
}

function Read-JsonHashtable {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [ordered]@{} }
    try { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop }
    catch { throw "Refusing to replace unreadable JSON configuration '$Path': $($_.Exception.Message)" }
}

function Get-OpenCodeConfigPath {
    $jsonc = Join-Path $configRoot 'opencode.jsonc'
    $json = Join-Path $configRoot 'opencode.json'
    if (Test-Path -LiteralPath $jsonc -PathType Leaf) { return $jsonc }
    if (Test-Path -LiteralPath $json -PathType Leaf) { return $json }
    $jsonc
}

function Get-DesiredAgentText {
    param([Parameter(Mandatory = $true)][string] $Source, [Parameter(Mandatory = $true)][string] $Name)
    $text = Get-Content -LiteralPath $Source -Raw
    if ($declaration.OpenUltraCode.FusionModels.ContainsKey($Name)) {
        $model = $declaration.OpenUltraCode.FusionModels[$Name]
        $text = $text -replace '(?m)^model:\s*[^\r\n]+', "model: $model"
    }
    $text
}

function Test-TextContent {
    param([Parameter(Mandatory = $true)][string] $Path, [Parameter(Mandatory = $true)][string] $Expected)
    (Test-Path -LiteralPath $Path -PathType Leaf) -and ((Get-Content -LiteralPath $Path -Raw) -ceq $Expected)
}

function Get-LiveState {
    $themeChecks = [ordered]@{}
    foreach ($theme in $declaration.Themes.Files) {
        $themeChecks[$theme.Name] = (Get-LowerHash (Join-Path $configRoot "themes\$($theme.File)")) -eq $theme.Sha256
    }
    $tuiPath = Join-Path $configRoot 'tui.json'
    $tui = Read-JsonHashtable $tuiPath
    $inventory = Get-InventoryIdentity $versionRoot

    $assetChecks = [ordered]@{}
    foreach ($name in $declaration.OpenUltraCode.Commands) {
        $source = Join-Path $versionRoot ".opencode\commands\$name"
        $assetChecks["command/$name"] = (Get-LowerHash $source) -eq (Get-LowerHash (Join-Path $configRoot "commands\$name")) -and (Test-Path -LiteralPath $source)
    }
    foreach ($name in $declaration.OpenUltraCode.Agents) {
        $source = Join-Path $versionRoot ".opencode\agents\$name"
        $desired = if (Test-Path -LiteralPath $source) { Get-DesiredAgentText $source $name } else { $null }
        $assetChecks["agent/$name"] = $null -ne $desired -and (Test-TextContent (Join-Path $configRoot "agents\$name") $desired)
    }
    $skillSource = Join-Path $versionRoot ".opencode\skills\$($declaration.OpenUltraCode.SkillRelativePath)"
    $skillTarget = Join-Path $configRoot "skills\$($declaration.OpenUltraCode.SkillRelativePath)"
    $assetChecks['skill/open-ultracode'] = (Get-LowerHash $skillSource) -eq (Get-LowerHash $skillTarget) -and (Test-Path -LiteralPath $skillSource)

    $configPath = Get-OpenCodeConfigPath
    $openCodeConfig = Read-JsonHashtable $configPath
    $pluginPath = (Join-Path $versionRoot $declaration.OpenUltraCode.PluginRelativePath).Replace('\', '/')
    $plugins = @($openCodeConfig.plugin)
    $checks = [ordered]@{
        Themes = @($themeChecks.Values | Where-Object { -not $_ }).Count -eq 0
        DefaultTheme = $tui.theme -eq $declaration.Themes.Default
        OpenUltraCodeRelease = $inventory.FileCount -eq $declaration.OpenUltraCode.FileCount -and $inventory.Sha256 -eq $declaration.OpenUltraCode.InventorySha256
        OpenUltraCodeAssets = @($assetChecks.Values | Where-Object { -not $_ }).Count -eq 0
        OpenUltraCodePlugin = $pluginPath -in $plugins
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Category = 'OpenCodeExtensions'
        Status = if (@($checks.Values | Where-Object { -not $_ }).Count -eq 0) { 'compliant' } else { 'drifted' }
        ConfigRoot = $configRoot
        ConfigPath = $configPath
        InstallRoot = $versionRoot
        DefaultTheme = $declaration.Themes.Default
        Release = $declaration.OpenUltraCode.Version
        Checks = [pscustomobject] $checks
        ThemeChecks = [pscustomobject] $themeChecks
        AssetChecks = [pscustomobject] $assetChecks
    }
}

function Write-State {
    param([Parameter(Mandatory = $true)] $State)
    if ($asJson) { $State | ConvertTo-Json -Depth 8; return }
    Write-Host "OpenCode extensions: $($State.Status)"
    foreach ($check in $State.Checks.PSObject.Properties) { Write-Host "  $($check.Name): $($check.Value)" }
    Write-Host "  Theme: $($State.DefaultTheme)"
    Write-Host "  OpenUltraCode: $($State.Release)"
}

function Backup-File {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $safeName = $Path.Replace(':', '').Replace('\', '_').Replace('/', '_')
    Copy-Item -LiteralPath $Path -Destination (Join-Path $backupRoot "$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-$safeName")
}

function Set-TextFile {
    param([Parameter(Mandatory = $true)][string] $Path, [Parameter(Mandatory = $true)][string] $Content)
    if (Test-TextContent $Path $Content) { return }
    Backup-File $Path
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -NoNewline -Encoding utf8
}

function Get-VerifiedDownload {
    param([Parameter(Mandatory = $true)][string] $Uri, [Parameter(Mandatory = $true)][string] $Path, [Parameter(Mandatory = $true)][string] $Sha256)
    if ((Get-LowerHash $Path) -eq $Sha256) { return $Path }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $temporary = "$Path.download-$([guid]::NewGuid().ToString('N'))"
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $temporary -UseBasicParsing
        if ((Get-LowerHash $temporary) -ne $Sha256) { throw "Downloaded content from '$Uri' failed SHA-256 verification." }
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
    $Path
}

function Install-OpenUltraCodeRelease {
    $inventory = Get-InventoryIdentity $versionRoot
    if ($Mode -ne 'Reinitialize' -and $inventory.FileCount -eq $declaration.OpenUltraCode.FileCount -and $inventory.Sha256 -eq $declaration.OpenUltraCode.InventorySha256) { return }
    $archive = Get-VerifiedDownload $declaration.OpenUltraCode.Uri (Join-Path $cacheRoot "downloads\$($declaration.OpenUltraCode.Asset)") $declaration.OpenUltraCode.Sha256
    $staging = Join-Path $cacheRoot "staging\$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    & tar.exe -xzf $archive -C $staging
    if ($LASTEXITCODE -ne 0) { throw 'OpenUltraCode release extraction failed.' }
    $stagedInventory = Get-InventoryIdentity $staging
    if ($stagedInventory.FileCount -ne $declaration.OpenUltraCode.FileCount -or $stagedInventory.Sha256 -ne $declaration.OpenUltraCode.InventorySha256) {
        throw 'The extracted OpenUltraCode release failed its declared inventory check.'
    }
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    if (Test-Path -LiteralPath $versionRoot) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Move-Item -LiteralPath $versionRoot -Destination (Join-Path $backupRoot "open-ultracode-$($declaration.OpenUltraCode.Version)-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))")
    }
    Move-Item -LiteralPath $staging -Destination $versionRoot
}

function Ensure-DeclaredState {
    New-Item -ItemType Directory -Path $configRoot -Force | Out-Null
    foreach ($theme in $declaration.Themes.Files) {
        $cached = Get-VerifiedDownload $theme.Uri (Join-Path $cacheRoot "downloads\themes\$($theme.File)") $theme.Sha256
        $target = Join-Path $configRoot "themes\$($theme.File)"
        if ((Get-LowerHash $target) -ne $theme.Sha256) {
            Backup-File $target
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            Copy-Item -LiteralPath $cached -Destination $target -Force
        }
    }

    Install-OpenUltraCodeRelease
    foreach ($name in $declaration.OpenUltraCode.Commands) {
        Set-TextFile (Join-Path $configRoot "commands\$name") (Get-Content -LiteralPath (Join-Path $versionRoot ".opencode\commands\$name") -Raw)
    }
    foreach ($name in $declaration.OpenUltraCode.Agents) {
        $source = Join-Path $versionRoot ".opencode\agents\$name"
        Set-TextFile (Join-Path $configRoot "agents\$name") (Get-DesiredAgentText $source $name)
    }
    $skillSource = Join-Path $versionRoot ".opencode\skills\$($declaration.OpenUltraCode.SkillRelativePath)"
    Set-TextFile (Join-Path $configRoot "skills\$($declaration.OpenUltraCode.SkillRelativePath)") (Get-Content -LiteralPath $skillSource -Raw)

    $tuiPath = Join-Path $configRoot 'tui.json'
    $tui = Read-JsonHashtable $tuiPath
    $tui['$schema'] = 'https://opencode.ai/tui.json'
    $tui['theme'] = $declaration.Themes.Default
    Set-TextFile $tuiPath ($tui | ConvertTo-Json -Depth 100)

    $configPath = Get-OpenCodeConfigPath
    $openCodeConfig = Read-JsonHashtable $configPath
    if (-not $openCodeConfig.ContainsKey('$schema')) { $openCodeConfig['$schema'] = 'https://opencode.ai/config.json' }
    $pluginPath = (Join-Path $versionRoot $declaration.OpenUltraCode.PluginRelativePath).Replace('\', '/')
    $plugins = @($openCodeConfig.plugin | Where-Object { $_ -and $_ -notmatch '[\\/]open-ultracode(?:[\\/]\d+\.\d+\.\d+)?[\\/]\.opencode[\\/]plugins[\\/]open-ultracode\.ts$' })
    $openCodeConfig['plugin'] = @($plugins) + $pluginPath
    Set-TextFile $configPath ($openCodeConfig | ConvertTo-Json -Depth 100)
}

$before = Get-LiveState
if ($Mode -eq 'Plan' -or $Mode -eq 'Test') {
    Write-State $before
    if ($Mode -eq 'Test' -and $before.Status -ne 'compliant') { exit 1 }
    exit 0
}

Ensure-DeclaredState
$after = Get-LiveState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'OpenCode extensions did not reach the declared state.' }
