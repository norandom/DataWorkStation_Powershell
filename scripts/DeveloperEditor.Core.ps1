Set-StrictMode -Version Latest

function Test-InstalledFontFamily {
    param([Parameter(Mandatory = $true)][string] $Family)
    $fontKeys = @(
        'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
        'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    )
    foreach ($key in $fontKeys) {
        if (-not (Test-Path $key)) { continue }
        $properties = Get-ItemProperty -Path $key
        if (@($properties.PSObject.Properties.Name | Where-Object { $_ -match [regex]::Escape($Family) }).Count -gt 0) { return $true }
    }
    $false
}

function Get-DeveloperEditorFont {
    param([string] $RepositoryRoot, [hashtable] $Configuration)
    # The portable declaration selects .terminal-fonts when its family is an InstalledFont.
    $preferencePath = Join-Path $RepositoryRoot $Configuration.LocalFontPreference
    if (Test-Path -LiteralPath $preferencePath -PathType Leaf) {
        $family = (Get-Content -LiteralPath $preferencePath -Raw).Trim()
        if ($family -and (Test-InstalledFontFamily $family)) {
            return [pscustomobject]@{ Family = $family; Source = 'local'; InstalledFont = $true }
        }
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
