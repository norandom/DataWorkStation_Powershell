[CmdletBinding()]
param(
    [ValidateSet('Plan', 'Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$asJson = [bool] $Json
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'DeveloperEditor.Core.ps1')
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\developer-editor.psd1')
$packageFile = Join-Path $repositoryRoot $configuration.PackageConfiguration
$settingsPath = [Environment]::ExpandEnvironmentVariables($configuration.SettingsPath)
$bergDirectory = [Environment]::ExpandEnvironmentVariables($configuration.Berg.InstallDirectory)

function Get-CodePath {
    $stable = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
    if (Test-Path -LiteralPath $stable -PathType Leaf) { return $stable }
    $command = Get-Command code.cmd,code.exe -ErrorAction Ignore | Select-Object -First 1
    if ($command) { return $command.Source }
    $null
}

function Get-CodeRoot {
    param([Parameter(Mandatory = $true)][string] $CodePath)
    Split-Path -Parent (Split-Path -Parent $CodePath)
}

function Get-CodeExtensionInventory {
    param([Parameter(Mandatory = $true)][string] $CodePath)
    $identities = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($identity in @(& $CodePath --list-extensions 2>$null)) {
        if ($identity) { [void] $identities.Add(([string] $identity).Trim()) }
    }

    $codeRoot = Get-CodeRoot $CodePath
    $candidates = @((Get-Item -LiteralPath $codeRoot)) + @(Get-ChildItem -LiteralPath $codeRoot -Directory -ErrorAction Ignore)
    foreach ($candidate in $candidates) {
        $builtInExtensionRoot = Join-Path $candidate.FullName 'resources\app\extensions'
        if (-not (Test-Path -LiteralPath $builtInExtensionRoot -PathType Container)) { continue }
        foreach ($extensionDirectory in @(Get-ChildItem -LiteralPath $builtInExtensionRoot -Directory -ErrorAction Ignore)) {
            $manifestPath = Join-Path $extensionDirectory.FullName 'package.json'
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
            try {
                $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($manifest.publisher -and $manifest.name) { [void] $identities.Add("$($manifest.publisher).$($manifest.name)") }
            } catch {
                Write-Verbose "Ignoring an unreadable built-in VS Code extension manifest: $manifestPath"
            }
        }
    }
    @($identities)
}

function Test-StableCode {
    param([AllowNull()][string] $CodePath)
    if (-not $CodePath) { return $false }
    $executable = Join-Path (Get-CodeRoot $CodePath) 'Code.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { return $false }
    $item = Get-Item -LiteralPath $executable
    $signature = Get-AuthenticodeSignature -LiteralPath $executable
    $item.VersionInfo.ProductName -eq 'Visual Studio Code' -and
        $item.VersionInfo.CompanyName -eq 'Microsoft Corporation' -and
        $signature.Status -eq 'Valid' -and
        $signature.SignerCertificate.Subject -match 'CN=Microsoft Corporation'
}

function Get-LiveState {
    $codePath = Get-CodePath
    $extensions = if ($codePath) { @(Get-CodeExtensionInventory $codePath) } else { @() }
    $font = Get-DeveloperEditorFont $repositoryRoot $configuration
    $settings = Get-DeveloperEditorSettings $settingsPath
    $bergTheme = Join-Path $bergDirectory 'themes\Berg Theme-color-theme.json'
    $bergHash = if (Test-Path -LiteralPath $bergTheme -PathType Leaf) { (Get-FileHash $bergTheme -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    $checks = [ordered]@{
        StableCode = Test-StableCode $codePath
        Extensions = @($configuration.Extensions | Where-Object { $_ -notin $extensions }).Count -eq 0
        Berg = $bergHash -eq $configuration.Berg.Sha256
        Theme = $settings['workbench.colorTheme'] -eq $configuration.Berg.ThemeLabel
        FontInstalled = [bool] $font.InstalledFont
        EditorFont = $settings['editor.fontFamily'] -eq $font.Family
        TerminalFont = $settings['terminal.integrated.fontFamily'] -eq $font.Family
    }
    [pscustomobject]@{
        SchemaVersion = 1
        Category = 'DeveloperEditor'
        Status = if (@($checks.GetEnumerator() | Where-Object { -not $_.Value }).Count -eq 0) { 'compliant' } else { 'drifted' }
        CodePath = $codePath
        Extensions = $extensions
        Berg = [pscustomobject]@{ Commit = $configuration.Berg.Commit; ExpectedSha256 = $configuration.Berg.Sha256; ActualSha256 = $bergHash }
        Font = $font
        SettingsPath = $settingsPath
        Checks = [pscustomobject] $checks
    }
}

function Write-State {
    param($State)
    if ($asJson) { $State | ConvertTo-Json -Depth 8; return }
    Write-Host "Developer editor: $($State.Status)"
    foreach ($check in $State.Checks.PSObject.Properties) { Write-Host "  $($check.Name): $($check.Value)" }
    Write-Host "  Font: $($State.Font.Family) ($($State.Font.Source))"
}

$before = Get-LiveState
if ($Mode -eq 'Plan') { Write-State $before; exit 0 }
if ($Mode -eq 'Test') { Write-State $before; if ($before.Status -eq 'compliant') { exit 0 } else { exit 1 } }

& winget.exe configure --file $packageFile --accept-configuration-agreements --disable-interactivity
if ($LASTEXITCODE -ne 0) { throw 'Stable VS Code WinGet configuration failed.' }
$codePath = Get-CodePath
if (-not $codePath) { throw 'Stable VS Code command was not found after installation.' }
$installedExtensions = @(Get-CodeExtensionInventory $codePath)
foreach ($extension in @($configuration.Extensions)) {
    if ($extension -in $installedExtensions) { continue }
    & $codePath --install-extension $extension
    if ($LASTEXITCODE -ne 0) { throw "VS Code failed to install extension '$extension'." }
}

$themeDirectory = Join-Path $bergDirectory 'themes'
New-Item -ItemType Directory -Path $themeDirectory -Force | Out-Null
$themePath = Join-Path $themeDirectory 'Berg Theme-color-theme.json'
Invoke-WebRequest -UseBasicParsing -Uri $configuration.Berg.Uri -OutFile $themePath
if ((Get-FileHash $themePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $configuration.Berg.Sha256) {
    throw 'Berg theme SHA-256 mismatch.'
}
$package = [ordered]@{
    name = 'berg'
    displayName = $configuration.Berg.DisplayName
    version = $configuration.Berg.ExtensionVersion
    publisher = 'dataworkstation'
    engines = @{ vscode = '^1.80.0' }
    contributes = @{ themes = @(@{ label = $configuration.Berg.ThemeLabel; uiTheme = 'vs-dark'; path = './themes/Berg Theme-color-theme.json' }) }
}
$package | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $bergDirectory 'package.json') -Encoding utf8

$font = Get-DeveloperEditorFont $repositoryRoot $configuration
if (-not $font.InstalledFont) { throw "Selected editor font '$($font.Family)' is not installed." }
$settings = Get-DeveloperEditorSettings $settingsPath
$merged = Merge-DeveloperEditorSettings $settings $font.Family $configuration.Berg.ThemeLabel
$settingsDirectory = Split-Path -Parent $settingsPath
New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
    $backupDirectory = Join-Path $repositoryRoot $configuration.BackupDirectory
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $backupDirectory "settings-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).json")
}
$merged | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding utf8

$after = Get-LiveState
Write-State $after
if ($after.Status -ne 'compliant') { throw 'Developer editor did not reach the declared state.' }
