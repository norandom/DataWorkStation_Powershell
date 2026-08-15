[CmdletBinding()]
param(
    [ValidateSet('Scan', 'Install')]
    [string] $Action = 'Scan',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Convert-Update {
    param([object] $Update)
    [pscustomobject]@{
        Title = [string] $Update.Title
        Identity = [string] $Update.Identity.UpdateID
        Revision = [int] $Update.Identity.RevisionNumber
        EulaAccepted = [bool] $Update.EulaAccepted
        Downloaded = [bool] $Update.IsDownloaded
        RebootBehavior = [string] $Update.InstallationBehavior.RebootBehavior
    }
}

if ($Action -eq 'Install' -and -not (Test-IsAdministrator)) {
    throw 'Windows software update installation requires an administrator process. Use the managed update command, which invokes this stage through Windows sudo.'
}

$session = New-Object -ComObject Microsoft.Update.Session
$session.ClientApplicationID = 'DataWorkStation PowerShell Update'
$searcher = $session.CreateUpdateSearcher()
$search = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
$available = @($search.Updates | ForEach-Object { Convert-Update $_ })
$acceptedCollection = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($candidate in @($search.Updates)) {
    if ($candidate.EulaAccepted) { [void] $acceptedCollection.Add($candidate) }
}

$status = 'scanned'
$restartRequired = $false
$installed = @()
$skippedEula = @($available | Where-Object { -not $_.EulaAccepted })
$detail = "$($available.Count) applicable software update(s); $($skippedEula.Count) require separate EULA acceptance."

if ($Action -eq 'Install' -and $acceptedCollection.Count -gt 0) {
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $acceptedCollection
    $downloadResult = $downloader.Download()
    if ([int] $downloadResult.ResultCode -notin @(2, 3)) {
        $status = 'failed'
        $detail = "Windows Update download result code: $([int] $downloadResult.ResultCode)."
    } else {
        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $acceptedCollection
        $installResult = $installer.Install()
        $restartRequired = [bool] $installResult.RebootRequired
        for ($index = 0; $index -lt $acceptedCollection.Count; $index++) {
            $itemResult = $installResult.GetUpdateResult($index)
            $installed += [pscustomobject]@{
                Title = [string] $acceptedCollection.Item($index).Title
                ResultCode = [int] $itemResult.ResultCode
                HResult = [int] $itemResult.HResult
            }
        }
        if ([int] $installResult.ResultCode -in @(2, 3)) {
            $status = if ($restartRequired) { 'restart-required' } else { 'succeeded' }
            $detail = "$($installed.Count) accepted software update(s) installed."
        } else {
            $status = 'failed'
            $detail = "Windows Update install result code: $([int] $installResult.ResultCode)."
        }
    }
} elseif ($Action -eq 'Install') {
    $status = if ($skippedEula.Count -gt 0) { 'failed' } else { 'succeeded' }
    $detail = if ($skippedEula.Count -gt 0) { 'Applicable updates require separate EULA acceptance; none were installed.' } else { 'No applicable software updates.' }
}

$result = [pscustomobject][ordered]@{
    SchemaVersion = 1
    Action = $Action
    Status = $status
    Applicable = $available
    Installed = $installed
    SkippedEula = $skippedEula
    RebootRequired = $restartRequired
    Detail = $detail
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Host "Windows software updates: $status"
    Write-Host "  $detail"
    foreach ($update in $available) { Write-Host "  - $($update.Title)" }
    if ($restartRequired) { Write-Warning 'Windows restart required; this command will not restart the host.' }
}

if ($status -eq 'failed') { exit 1 }
