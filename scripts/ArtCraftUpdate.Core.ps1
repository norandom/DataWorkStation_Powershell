function Resolve-ArtCraftRelease {
    param([hashtable] $App, [object] $Release)
    if ($Release.draft -or $Release.prerelease -or $Release.tag_name -notmatch '^v?(\d+\.\d+\.\d+)$') {
        throw 'Expected a stable numeric release.'
    }
    $version = $Matches[1]
    $name = "$($App.Stem)-$version-windows-x64.msi"
    $assets = @($Release.assets | Where-Object name -CEQ $name)
    if ($assets.Count -ne 1) { throw "Expected exactly one $name asset." }
    $asset = $assets[0]
    $expectedUrl = "https://github.com/storytold/$($App.Repository)/releases/download/$($Release.tag_name)/$name"
    if ($asset.browser_download_url -cne $expectedUrl -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw 'Release asset must have the official URL and a SHA-256 digest.'
    }
    [pscustomobject]@{ Version = $version; Name = $name; Url = $expectedUrl; Sha256 = $Matches[1] }
}

function Assert-ArtCraftHash {
    param([string] $Path, [string] $Expected)
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Expected) { throw 'Downloaded MSI SHA-256 mismatch.' }
}

function Invoke-ArtCraftBatch {
    param(
        [hashtable] $Catalog, [object[]] $Inventory, [switch] $Run,
        [scriptblock] $ReleaseFetcher, [scriptblock] $RunningProbe, [scriptblock] $Installer
    )
    $rows = foreach ($app in $Catalog.Applications) {
        $row = [pscustomobject]@{ Name = $app.Name; Installed = $null; Available = $null; Status = 'not-installed'; Detail = ''; RestartRequired = $false }
        try {
            $installed = @($Inventory | Where-Object { $_.DisplayName -ceq $app.Name -and $_.Publisher -ceq $Catalog.Publisher -and $_.WindowsInstaller -eq 1 })
            if ($installed.Count -gt 1) { throw 'Multiple MSI registrations found; resolve installation scope before updating.' }
            if ($installed.Count -eq 1) {
                $row.Installed = $installed[0].DisplayVersion
                if ($installed[0].Architecture -ne 'x64') { throw 'Installed MSI is not verified as x64; inspect its cached package before updating.' }
                $release = & $ReleaseFetcher $app
                $package = Resolve-ArtCraftRelease -App $app -Release $release
                $row.Available = $package.Version
                if ([version] $row.Installed -ge [version] $package.Version) { $row.Status = 'current' }
                elseif (-not $Run) { $row.Status = 'update-available' }
                elseif (& $RunningProbe $app) { $row.Status = 'blocked-running'; $row.Detail = 'Close this app and retry; no process was stopped.' }
                else {
                    $result = & $Installer $app $package
                    if ($result.ExitCode -notin @(0, 3010)) { throw "MSI failed with exit code $($result.ExitCode). Log: $($result.Log)" }
                    $row.RestartRequired = $result.ExitCode -eq 3010
                    $row.Status = if ($row.RestartRequired) { 'restart-required' } else { 'updated' }
                    $row.Detail = "MSI log: $($result.Log)"
                }
            }
        } catch { $row.Status = 'failed'; $row.Detail = $_.Exception.Message }
        $row
    }
    [pscustomobject]@{
        Applications = @($rows)
        Succeeded = @($rows | Where-Object Status -in @('failed', 'blocked-running')).Count -eq 0
        RestartRequired = @($rows | Where-Object RestartRequired).Count -gt 0
    }
}
