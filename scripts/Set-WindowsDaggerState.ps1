[CmdletBinding()]
param([ValidateSet('Test', 'Ensure', 'Reinitialize')][string] $Mode = 'Test')
$ErrorActionPreference = 'Stop'
$configuration = (Import-PowerShellDataFile (Join-Path $PSScriptRoot '../config/developer-tools.psd1')).Dagger
$install = Join-Path $env:LOCALAPPDATA "Programs/Dagger/$($configuration.Version)"
$binary = Join-Path $install 'dagger.exe'
$shimDirectory = Join-Path $env:USERPROFILE '.local/bin'
$shim = Join-Path $shimDirectory 'dagger.cmd'
$launcher = Join-Path $PSScriptRoot 'Invoke-Dagger.ps1'
$shimContent = "@echo off`r`npwsh.exe -NoLogo -NoProfile -File `"$launcher`" %*`r`nexit /b %errorlevel%`r`n"
$podman = Join-Path $env:ProgramFiles 'RedHat/Podman/podman.exe'
if ($Mode -ne 'Test') {
    if (-not (Test-Path $binary)) {
        $storage = if ($env:DEVELOPER_STORAGE_ROOT) { $env:DEVELOPER_STORAGE_ROOT } else { 'D:\BuildArtifacts' }
        $download = Join-Path $storage 'PowerShell/dagger'
        New-Item -ItemType Directory -Force $download | Out-Null
        $archive = Join-Path $download "dagger-$($configuration.Version).zip"
        Invoke-WebRequest "https://github.com/dagger/dagger/releases/download/v$($configuration.Version)/dagger_v$($configuration.Version)_windows_amd64.zip" -OutFile $archive
        if ((Get-FileHash $archive -Algorithm SHA256).Hash -ne $configuration.Sha256) { throw 'Dagger archive checksum mismatch.' }
        Expand-Archive $archive $install -Force
    }
    New-Item -ItemType Directory -Force $shimDirectory | Out-Null
    Set-Content -LiteralPath $shim -Value $shimContent -NoNewline -Encoding ascii
}
$checks = [ordered]@{
    NativeCli = Test-Path $binary
    Launcher = ((Test-Path $shim) -and (Get-Content $shim -Raw) -eq $shimContent)
    RootfulMachine = $false
}
if ($checks.NativeCli) {
    $version = & pwsh.exe -NoLogo -NoProfile -File $launcher version
    $checks.NativeCli = $LASTEXITCODE -eq 0 -and "$version" -match "dagger v$([regex]::Escape($configuration.Version))(?:\s|$)"
}
if (Test-Path $podman) {
    $machine = & $podman machine inspect $configuration.Machine | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) { $checks.RootfulMachine = [bool]$machine.Rootful }
}
$checks.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }
if ($checks.Values -contains $false) { throw 'Windows Dagger state incomplete. Install Podman and explicitly configure its machine with podman machine set --rootful.' }
if ($Mode -ne 'Test') {
    & pwsh.exe -NoLogo -NoProfile -File $launcher core version
    if ($LASTEXITCODE) { throw 'Dagger engine verification failed.' }
}
