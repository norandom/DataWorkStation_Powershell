Set-StrictMode -Version Latest

function Get-FontFileFamilyNames {
    param([Parameter(Mandatory = $true)][string] $Path)
    Add-Type -AssemblyName PresentationCore
    $directory = Split-Path -Parent $Path
    $directoryUri = [Uri]::new(($directory.TrimEnd('\') + '\'))
    @([Windows.Media.Fonts]::GetFontFamilies($directoryUri, (Split-Path -Leaf $Path)) | ForEach-Object {
        @($_.FamilyNames.Values)
    })
}

function Test-FontFamilyInDirectory {
    param(
        [Parameter(Mandatory = $true)][string] $Family,
        [Parameter(Mandatory = $true)][string] $Directory,
        [scriptblock] $FamilyReader = ${function:Get-FontFileFamilyNames}
    )
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $false }
    foreach ($fontFile in @(Get-ChildItem -LiteralPath $Directory -File -ErrorAction Ignore | Where-Object {
        $_.Extension -in @('.otf', '.ttf', '.ttc')
    })) {
        try {
            foreach ($observedFamily in @(& $FamilyReader $fontFile.FullName)) {
                if ([string]::Equals([string] $observedFamily, $Family, [StringComparison]::OrdinalIgnoreCase)) {
                    return $true
                }
            }
        } catch {
            Write-Verbose "Ignoring unreadable font metadata: $($fontFile.FullName)"
        }
    }
    $false
}

function Test-InstalledFontFamily {
    param([Parameter(Mandatory = $true)][string] $Family)
    $fontKeys = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )
    foreach ($key in $fontKeys) {
        if (-not (Test-Path $key)) { continue }
        $properties = Get-ItemProperty -Path $key
        if (@($properties.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS' -and
                ($_.Name -match [regex]::Escape($Family) -or [string] $_.Value -match [regex]::Escape($Family))
        }).Count -gt 0) { return $true }
    }
    $userFontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (Test-FontFamilyInDirectory -Family $Family -Directory $userFontDirectory) {
        return $true
    }
    $false
}

function Get-BergExtensionState {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary] $Configuration,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]] $ExtensionInventory,
        [Parameter(Mandatory = $true)][string] $ExtensionRoot
    )
    $state = [ordered]@{
        ExtensionId = $Configuration.ExtensionId
        ExpectedVersion = $Configuration.ExtensionVersion
        Installed = $Configuration.ExtensionId -in $ExtensionInventory
        ManifestValid = $false
        ThemeContribution = $false
        ExpectedSha256 = $Configuration.Sha256
        ActualSha256 = $null
        ExtensionPath = $null
        Compliant = $false
    }
    if (-not $state.Installed -or -not (Test-Path -LiteralPath $ExtensionRoot -PathType Container)) {
        return [pscustomobject] $state
    }

    foreach ($directory in @(Get-ChildItem -LiteralPath $ExtensionRoot -Directory -ErrorAction Ignore)) {
        $manifestPath = Join-Path $directory.FullName 'package.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            continue
        }
        $identity = "$($manifest.publisher).$($manifest.name)"
        if (-not [string]::Equals($identity, $Configuration.ExtensionId, [StringComparison]::OrdinalIgnoreCase) -or
            -not [string]::Equals([string] $manifest.version, $Configuration.ExtensionVersion, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        $state.ManifestValid = $true
        $state.ExtensionPath = $directory.FullName
        $theme = @($manifest.contributes.themes | Where-Object {
            [string]::Equals([string] $_.label, $Configuration.ThemeLabel, [StringComparison]::Ordinal)
        } | Select-Object -First 1)
        if ($theme.Count -eq 0 -or -not $theme[0].path) { continue }
        $relativeThemePath = ([string] $theme[0].path).Replace('/', '\').TrimStart('.', '\')
        $extensionPath = [IO.Path]::GetFullPath($directory.FullName).TrimEnd('\') + '\'
        $themePath = [IO.Path]::GetFullPath((Join-Path $directory.FullName $relativeThemePath))
        if (-not $themePath.StartsWith($extensionPath, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $themePath -PathType Leaf)) {
            continue
        }
        $state.ThemeContribution = $true
        $state.ActualSha256 = (Get-FileHash -LiteralPath $themePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $state.Compliant = $state.ActualSha256 -eq $Configuration.Sha256
        if ($state.Compliant) { break }
    }
    [pscustomobject] $state
}

function Get-DeveloperEditorFont {
    param([string] $RepositoryRoot, [hashtable] $Configuration)
    . (Join-Path $PSScriptRoot 'Import-WorkstationConfiguration.ps1')
    $localConfiguration = Import-WorkstationConfiguration -RepositoryRoot $RepositoryRoot
    $family = [string] $localConfiguration.Fonts.TerminalFamily
    if ($family -and (Test-InstalledFontFamily $family)) {
        return [pscustomobject]@{ Family = $family; Source = 'local'; InstalledFont = $true }
    }
    [pscustomobject]@{ Family = $Configuration.PortableFontFamily; Source = 'portable'; InstalledFont = (Test-InstalledFontFamily $Configuration.PortableFontFamily) }
}

function Merge-DeveloperEditorSettings {
    param(
        [AllowNull()][hashtable] $Settings,
        [Parameter(Mandatory = $true)][string] $FontFamily,
        [Parameter(Mandatory = $true)][string] $ThemeLabel
    )
    if (-not $Settings) { $Settings = @{} }
    $Settings['workbench.colorTheme'] = $ThemeLabel
    $Settings['editor.fontFamily'] = $FontFamily
    $Settings['terminal.integrated.fontFamily'] = $FontFamily
    $Settings
}

function Get-DeveloperEditorSettings {
    param([Parameter(Mandatory = $true)][string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @{} }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
    try { $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop } catch {
        throw "VS Code settings could not be parsed safely: $Path. $($_.Exception.Message)"
    }
}
