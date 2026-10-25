[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/ArtCraftUpdate.Core.ps1')

function Test-ArtCraftUpdate {
    $app = @{ Name = 'PdfCraft'; Repository = 'pdfcraft'; Stem = 'pdfcraft' }
    $catalog = @{ Publisher = 'Learning Machines LLC'; Applications = @($app, @{ Name = 'GridCraft'; Repository = 'gridcraft'; Stem = 'gridcraft' }) }
    $inventory = @([pscustomobject]@{ DisplayName = 'PdfCraft'; Publisher = 'Learning Machines LLC'; WindowsInstaller = 1; DisplayVersion = '0.12.0'; Architecture = 'x64' })
    $fetch = {
        param($App)
        [pscustomobject]@{ tag_name = 'v0.13.0'; draft = $false; prerelease = $false; assets = @([pscustomobject]@{
            name = "$($App.Stem)-0.13.0-windows-x64.msi"; digest = ('sha256:' + ('a' * 64))
            browser_download_url = "https://github.com/storytold/$($App.Repository)/releases/download/v0.13.0/$($App.Stem)-0.13.0-windows-x64.msi"
        }) }
    }
    $neverInstall = { throw 'Installer must not run in this scenario.' }
    $plan = Invoke-ArtCraftBatch -Catalog $catalog -Inventory $inventory -ReleaseFetcher $fetch -RunningProbe { $false } -Installer $neverInstall
    if ($plan.Applications[0].Status -ne 'update-available' -or $plan.Applications[1].Status -ne 'not-installed') { throw 'Installed-only check failed.' }
    $blocked = Invoke-ArtCraftBatch -Catalog $catalog -Inventory $inventory -Run -ReleaseFetcher $fetch -RunningProbe { $true } -Installer $neverInstall
    if ($blocked.Succeeded -or $blocked.Applications[0].Status -ne 'blocked-running') { throw 'Running app must block installation.' }
    $restart = Invoke-ArtCraftBatch -Catalog $catalog -Inventory $inventory -Run -ReleaseFetcher $fetch -RunningProbe { $false } -Installer { [pscustomobject]@{ ExitCode = 3010; Log = 'fixture' } }
    if (-not $restart.Succeeded -or -not $restart.RestartRequired) { throw 'MSI restart result was lost.' }
    $inventory += [pscustomobject]@{ DisplayName = 'GridCraft'; Publisher = 'Learning Machines LLC'; WindowsInstaller = 1; DisplayVersion = '0.12.0'; Architecture = 'x64' }
    $mixed = Invoke-ArtCraftBatch -Catalog $catalog -Inventory $inventory -Run -ReleaseFetcher $fetch -RunningProbe { $false } -Installer {
        param($App)
        [pscustomobject]@{ ExitCode = if ($App.Name -eq 'PdfCraft') { 1603 } else { 0 }; Log = 'fixture' }
    }
    if ($mixed.Succeeded -or $mixed.Applications[1].Status -ne 'updated') { throw 'Failure must not block independent apps.' }
    $inventory[0].DisplayVersion = '99.0.0'
    $current = Invoke-ArtCraftBatch -Catalog @{ Publisher = $catalog.Publisher; Applications = @($app) } -Inventory $inventory -Run -ReleaseFetcher $fetch -RunningProbe { $false } -Installer $neverInstall
    if ($current.Applications[0].Status -ne 'current') { throw 'Newer installed versions must not downgrade.' }
    $inventory[0].Architecture = 'Intel'
    $wrongArchitecture = Invoke-ArtCraftBatch -Catalog @{ Publisher = $catalog.Publisher; Applications = @($app) } -Inventory $inventory -Run -ReleaseFetcher $fetch -RunningProbe { $false } -Installer $neverInstall
    if ($wrongArchitecture.Succeeded) { throw 'An x86 installation must not receive an x64 upgrade.' }
    foreach ($bad in @('url', 'digest', 'prerelease', 'missing-asset')) {
        $release = & $fetch $app
        switch ($bad) {
            'url' { $release.assets[0].browser_download_url = 'https://example.com/package.msi' }
            'digest' { $release.assets[0].digest = '' }
            'prerelease' { $release.prerelease = $true }
            'missing-asset' { $release.assets = @() }
        }
        $rejected = $false
        try { $null = Resolve-ArtCraftRelease -App $app -Release $release } catch { $rejected = $true }
        if (-not $rejected) { throw "Unsafe release accepted: $bad" }
    }
    $path = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($path, 'fixture')
        Assert-ArtCraftHash -Path $path -Expected (Get-FileHash $path).Hash
        $rejected = $false
        try { Assert-ArtCraftHash -Path $path -Expected ('0' * 64) } catch { $rejected = $true }
        if (-not $rejected) { throw 'Corrupt download accepted.' }
    } finally { Remove-Item -LiteralPath $path }
    Write-Output 'PASS: installed-only checks, running-app blocking, failure isolation, restart reporting, no downgrade, release validation and download hash verification.'
}
Test-ArtCraftUpdate
