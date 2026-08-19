[CmdletBinding()]
param(
    [string] $CatalogPath,
    [switch] $Json,
    [switch] $PassThru,
    [Parameter(DontShow = $true)][scriptblock] $ReleaseFetcher
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
    $CatalogPath = Join-Path $repositoryRoot 'config\software-updates.psd1'
}

function Get-NestedValue {
    param([Parameter(Mandatory = $true)][object] $InputObject, [Parameter(Mandatory = $true)][string] $Path)

    $value = $InputObject
    foreach ($segment in @($Path -split '\.')) {
        if ($null -eq $value) { throw "Path '$Path' contains a null value before '$segment'." }
        if ($value -is [Collections.IDictionary]) {
            if (-not $value.Contains($segment)) { throw "Path '$Path' does not contain '$segment'." }
            $value = $value[$segment]
        } elseif ($segment -match '^\d+$' -and $value -is [Collections.IList]) {
            $index = [int] $segment
            if ($index -ge $value.Count) { throw "Path '$Path' index $index is out of range." }
            $value = $value[$index]
        } else {
            $property = $value.PSObject.Properties[$segment]
            if (-not $property) { throw "Path '$Path' does not contain '$segment'." }
            $value = $property.Value
        }
    }
    $value
}

function Get-LocationValue {
    param([hashtable] $Location, [string] $ValuePath)

    $configPath = Join-Path $repositoryRoot ([string] $Location.ConfigPath)
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Pinned release config not found: $configPath" }
    $configuration = Import-PowerShellDataFile -LiteralPath $configPath
    $root = $configuration
    if ($Location.CollectionPath) {
        $collection = @(Get-NestedValue -InputObject $configuration -Path ([string] $Location.CollectionPath))
        $selectedLocations = @($collection | Where-Object { [string] $_[$Location.MatchProperty] -eq [string] $Location.MatchValue })
        if ($selectedLocations.Count -ne 1) {
            throw "Pinned release selector '$($Location.MatchProperty)=$($Location.MatchValue)' matched $($selectedLocations.Count) entries in $configPath."
        }
        $root = $selectedLocations[0]
    }
    Get-NestedValue -InputObject $root -Path $ValuePath
}

function Get-GitHubRelease {
    param([hashtable] $Definition, [string] $CurrentVersion)

    if ($ReleaseFetcher) { return & $ReleaseFetcher $Definition $CurrentVersion }
    if ([string] $Definition.Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
        throw "Invalid GitHub repository '$($Definition.Repository)'."
    }
    $headers = @{
        Accept = 'application/vnd.github+json'
        'User-Agent' = 'DataWorkStation-PowerShell-Update-Check'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $env:GITHUB_TOKEN" }
    Invoke-RestMethod -Uri "https://api.github.com/repos/$($Definition.Repository)/releases/latest" -Headers $headers -Method Get
}

function Compare-ReleaseVersion {
    param([string] $Current, [string] $Latest)

    try { return ([version] $Latest).CompareTo([version] $Current) } catch {
        return [string]::Compare($Latest, $Current, [StringComparison]::OrdinalIgnoreCase)
    }
}

function Find-ReleaseAssets {
    param([hashtable] $Definition, [string] $Version, [object] $Release)

    $assets = @($Release.assets)
    $selected = [Collections.Generic.List[object]]::new()
    $nameTemplates = @($Definition.AssetNameTemplates) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }
    foreach ($template in $nameTemplates) {
        $assetName = ([string] $template).Replace('{version}', $Version)
        $assetMatches = @($assets | Where-Object { [string] $_.name -eq $assetName })
        if ($assetMatches.Count -ne 1) { throw "Expected one GitHub asset '$assetName' for $($Definition.Name), found $($assetMatches.Count)." }
        [void] $selected.Add($assetMatches[0])
    }
    $regexTemplates = @($Definition.AssetNameRegexTemplates) | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_) }
    foreach ($template in $regexTemplates) {
        $pattern = ([string] $template).Replace('{version}', [regex]::Escape($Version))
        $assetMatches = @($assets | Where-Object { [string] $_.name -match $pattern })
        if ($assetMatches.Count -ne 1) { throw "Expected one GitHub asset matching '$pattern' for $($Definition.Name), found $($assetMatches.Count)." }
        [void] $selected.Add($assetMatches[0])
    }
    @($selected)
}

function Convert-AssetResult {
    param([object] $Asset)

    $digest = [string] $Asset.digest
    $sha256 = if ($digest -match '^sha256:(?<hash>[A-Fa-f0-9]{64})$') { $Matches.hash.ToLowerInvariant() } else { '' }
    [pscustomobject][ordered]@{
        Name = [string] $Asset.name
        Uri = [string] $Asset.browser_download_url
        Size = [long] $Asset.size
        Sha256 = $sha256
        DigestAvailable = [bool] $sha256
    }
}

$catalog = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($CatalogPath))
if ([int] $catalog.SchemaVersion -ne 1) { throw "Unsupported pinned software update schema: $($catalog.SchemaVersion)" }
$names = @($catalog.Releases.Name)
if (@($names | Sort-Object -Unique).Count -ne $names.Count) { throw 'Pinned software update names must be unique.' }

$releaseResults = foreach ($definition in @($catalog.Releases)) {
    try {
        $locations = foreach ($location in @($definition.Locations)) {
            $version = [string] (Get-LocationValue -Location $location -ValuePath ([string] $location.VersionPath))
            $integrity = if ($location.IntegrityPath) { [string] (Get-LocationValue -Location $location -ValuePath ([string] $location.IntegrityPath)) } else { '' }
            [pscustomobject][ordered]@{
                ConfigPath = [string] $location.ConfigPath
                VersionPath = [string] $location.VersionPath
                Version = $version
                Integrity = $integrity
            }
        }
        $versions = @($locations.Version | Sort-Object -Unique)
        if ($versions.Count -ne 1) {
            [pscustomobject][ordered]@{
                Name = [string] $definition.Name; Provider = [string] $definition.Provider; Repository = [string] $definition.Repository
                CurrentVersion = $versions -join ', '; LatestVersion = ''; Status = 'inconsistent-pin'; ReleaseUri = ''
                Locations = @($locations); Assets = @(); Review = 'align-version-strings'; Detail = 'Declared version strings disagree.'
            }
            continue
        }
        $currentVersion = [string] $versions[0]
        if ([string] $definition.Provider -ne 'GitHubRelease') { throw "Unsupported release provider '$($definition.Provider)'." }
        $release = Get-GitHubRelease -Definition $definition -CurrentVersion $currentVersion
        $tag = [string] $release.tag_name
        if ($tag -notmatch [string] $definition.TagPattern -or -not $Matches.version) {
            throw "Latest tag '$tag' does not match '$($definition.TagPattern)'."
        }
        $latestVersion = [string] $Matches.version
        $assets = @(Find-ReleaseAssets -Definition $definition -Version $latestVersion -Release $release | ForEach-Object { Convert-AssetResult $_ })
        $comparison = Compare-ReleaseVersion -Current $currentVersion -Latest $latestVersion
        $status = if ($comparison -gt 0) { 'update-available' } elseif ($comparison -eq 0) { 'current' } else { 'ahead' }
        $review = if ($status -eq 'update-available') {
            if ($definition.Review) { [string] $definition.Review } elseif (@($assets | Where-Object DigestAvailable).Count -eq $assets.Count) { 'version-and-integrity-lock' } else { 'version-and-manual-integrity-review' }
        } else { '' }
        [pscustomobject][ordered]@{
            Name = [string] $definition.Name; Provider = [string] $definition.Provider; Repository = [string] $definition.Repository
            CurrentVersion = $currentVersion; LatestVersion = $latestVersion; Status = $status; ReleaseUri = [string] $release.html_url
            Locations = @($locations); Assets = @($assets); Review = $review
            Detail = if ($status -eq 'update-available') { "Change the declared version string, then review and refresh integrity locks ($review)." } elseif ($status -eq 'current') { 'Declared version matches the latest stable release.' } else { 'Declared version is newer than the latest stable release.' }
        }
    } catch {
        [pscustomobject][ordered]@{
            Name = [string] $definition.Name; Provider = [string] $definition.Provider; Repository = [string] $definition.Repository
            CurrentVersion = ''; LatestVersion = ''; Status = 'error'; ReleaseUri = ''; Locations = @(); Assets = @(); Review = 'manual-review'; Detail = $_.Exception.Message
        }
    }
}

$result = [pscustomobject][ordered]@{
    SchemaVersion = 1
    CheckedAtUtc = [DateTime]::UtcNow.ToString('o')
    NetworkAccessed = -not [bool] $ReleaseFetcher
    Releases = @($releaseResults)
    UpdatesAvailable = @($releaseResults | Where-Object Status -eq 'update-available').Count
    ReviewRequired = @($releaseResults | Where-Object Status -in @('update-available', 'inconsistent-pin', 'error')).Count
    Succeeded = @($releaseResults | Where-Object Status -in @('inconsistent-pin', 'error')).Count -eq 0
}

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 10 }
else {
    $result.Releases | Select-Object Name, CurrentVersion, LatestVersion, Status, Review | Format-Table -AutoSize -Wrap
    Write-Host "Pinned release check: $($result.UpdatesAvailable) update(s) available; $($result.ReviewRequired) item(s) require review. No files or software were changed."
}
if (-not $PassThru -and -not $result.Succeeded) { exit 1 }
