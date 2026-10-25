[CmdletBinding()]
param([switch] $Run, [switch] $Json)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ArtCraftUpdate.Core.ps1')
$catalog = Import-PowerShellDataFile (Join-Path $PSScriptRoot '../config/artcraft.psd1')
$architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
if ($architecture -ne 'AMD64') { throw 'This batch adapter supports Windows x64 MSI installations only.' }
if ($Run) {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this command through Windows sudo for batch installation.' }
}
# Registry inventory avoids Win32_Product, which can trigger MSI repair.
$keys = @('HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/*', 'HKLM:/Software/Microsoft/Windows/CurrentVersion/Uninstall/*')
$inventory = @(Get-ItemProperty $keys -ErrorAction SilentlyContinue)
$windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
foreach ($entry in $inventory) {
    if ($entry.DisplayName -in @($catalog.Applications.Name) -and $entry.WindowsInstaller -eq 1) {
        $packageArchitecture = 'unknown'
        try {
            $cachedPackage = $windowsInstaller.ProductInfo($entry.PSChildName, 'LocalPackage')
            $database = $windowsInstaller.OpenDatabase($cachedPackage, 0)
            $packageArchitecture = ($database.SummaryInformation(0).Property(7) -split ';')[0]
        } catch { Write-Verbose "Cannot inspect cached MSI for $($entry.DisplayName): $_" }
        $entry | Add-Member -NotePropertyName Architecture -NotePropertyValue $packageArchitecture
    }
}
$fetcher = {
    param($App)
    Invoke-RestMethod "https://api.github.com/repos/storytold/$($App.Repository)/releases/latest" -Headers @{ 'User-Agent' = 'DataWorkStation-ArtCraft'; Accept = 'application/vnd.github+json' } -TimeoutSec 60
}
$probe = {
    param($App)
    # A name match is deliberately conservative, including when a process path is inaccessible.
    @(Get-Process -Name $App.Stem -ErrorAction SilentlyContinue).Count -gt 0
}
$installer = {
    param($App, $Package)
    $directory = Join-Path ([IO.Path]::GetTempPath()) ('ArtCraftUpdate-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $directory
    $path = Join-Path $directory $Package.Name
    $log = Join-Path $directory 'install.log'
    Invoke-WebRequest $Package.Url -OutFile $path -TimeoutSec 600
    Assert-ArtCraftHash -Path $path -Expected $Package.Sha256
    $database = $windowsInstaller.OpenDatabase($path, 0)
    if (($database.SummaryInformation(0).Property(7) -split ';')[0] -ne 'x64') { throw 'Downloaded MSI architecture is not x64.' }
    if (& $probe $App) { throw 'Application started during download; close it and retry.' }
    # Never ask Restart Manager to close applications; preserve a required reboot as a result.
    $arguments = @('/i', "`"$path`"", '/qn', '/norestart', 'REBOOT=ReallySuppress', 'MSIRESTARTMANAGERCONTROL=Disable', '/L*v', "`"$log`"")
    if (-not $Json) { Write-Host "Installing $($App.Name) $($Package.Version) with msiexec /qn /norestart. Log: $log" }
    $process = Start-Process -FilePath "$env:SystemRoot/System32/msiexec.exe" -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    [pscustomobject]@{ ExitCode = $process.ExitCode; Log = $log }
}
$result = Invoke-ArtCraftBatch -Catalog $catalog -Inventory $inventory -Run:$Run -ReleaseFetcher $fetcher -RunningProbe $probe -Installer $installer
if ($Json) { $result | ConvertTo-Json -Depth 5 }
else { $result.Applications | Format-Table Name, Installed, Available, Status, Detail -AutoSize -Wrap }
if (-not $result.Succeeded) { exit 1 }
if ($result.RestartRequired) { exit 3010 }
