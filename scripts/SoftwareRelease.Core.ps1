function Get-PinnedSoftwareReleaseDefinition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [string] $CatalogPath
    )

    if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
        $CatalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\software-updates.psd1'
    }
    $catalog = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($CatalogPath))
    $releaseDefinitions = @($catalog.Releases | Where-Object Name -eq $Name)
    if ($releaseDefinitions.Count -ne 1) { throw "Pinned software release '$Name' matched $($releaseDefinitions.Count) catalog entries." }
    $releaseDefinitions[0]
}

function Resolve-PinnedSoftwareReleaseAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $Name,
        [Parameter(Mandatory = $true)][string] $Version,
        [int] $AssetIndex = 0,
        [string] $CatalogPath
    )

    $definition = Get-PinnedSoftwareReleaseDefinition -Name $Name -CatalogPath $CatalogPath
    if ([string] $definition.Provider -ne 'GitHubRelease') { throw "Release URI generation is unsupported for provider '$($definition.Provider)'." }
    if ([string]::IsNullOrWhiteSpace([string] $definition.TagTemplate)) { throw "Release '$Name' has no deterministic tag template." }
    $templates = @($definition.AssetNameTemplates | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) })
    if ($AssetIndex -lt 0 -or $AssetIndex -ge $templates.Count) { throw "Release '$Name' has no deterministic asset template at index $AssetIndex." }

    $tag = ([string] $definition.TagTemplate).Replace('{version}', $Version)
    $assetName = ([string] $templates[$AssetIndex]).Replace('{version}', $Version)
    [pscustomobject][ordered]@{
        Name = $Name
        Version = $Version
        Tag = $tag
        AssetName = $assetName
        Uri = "https://github.com/$($definition.Repository)/releases/download/$([Uri]::EscapeDataString($tag))/$([Uri]::EscapeDataString($assetName))"
    }
}
