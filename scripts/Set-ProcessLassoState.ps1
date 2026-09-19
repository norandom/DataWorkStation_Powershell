[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\process-lasso.psd1')

function Get-ProcessLassoState {
    param([Parameter(Mandatory)][string] $InstallDirectory)

    $guiPath = Join-Path $InstallDirectory $configuration.GuiExecutable
    $governorPath = Join-Path $InstallDirectory $configuration.GovernorExecutable
    $gui = Get-Item -LiteralPath $guiPath -ErrorAction Ignore
    $installed = $gui -and -not $gui.PSIsContainer -and (Test-Path -LiteralPath $governorPath -PathType Leaf)
    [pscustomobject]@{
        SchemaVersion = 1
        Resource = 'ProcessLassoPackage'
        State = if ($installed) { 'compliant' } else { 'drift detected' }
        PackageId = $configuration.PackageId
        Optional = $true
        LicenseRequirement = $configuration.LicenseRequirement
        LicenseUrl = $configuration.LicenseUrl
        LicenseStatus = 'not checked; activation is managed by the operator'
        Path = $guiPath
        Version = if ($gui) { $gui.VersionInfo.ProductVersion } else { $null }
        Homepage = $configuration.Homepage
    }
}

if ($Mode -ne 'Test') {
    $packageFile = Join-Path $repositoryRoot '.config\process-lasso.winget'
    & winget.exe configure --file $packageFile --accept-configuration-agreements --disable-interactivity | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "Process Lasso WinGet Configuration failed with exit code $LASTEXITCODE." }
}

$installDirectory = Join-Path $env:ProgramFiles 'Process Lasso'
$uninstallKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ProcessLasso'
$registered = Get-ItemProperty -LiteralPath $uninstallKey -ErrorAction Ignore
if ($registered.InstallLocation) { $installDirectory = $registered.InstallLocation }
$result = Get-ProcessLassoState -InstallDirectory $installDirectory
if ($Json) { $result | ConvertTo-Json -Depth 4 }
else {
    $result | Format-Table Resource,State,Version,Optional,Path -AutoSize -Wrap | Out-Host
    Write-Host $result.LicenseRequirement
    Write-Host "License status: $($result.LicenseStatus). $($result.LicenseUrl)"
}
if ($Mode -ne 'Test' -and $result.State -ne 'compliant') { throw 'Process Lasso package did not become compliant.' }
if ($Mode -eq 'Test' -and $result.State -ne 'compliant') { exit 1 }
