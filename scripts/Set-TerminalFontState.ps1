[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\terminal-fonts.psd1')
$package = $configuration.Package
$installDirectory = [Environment]::ExpandEnvironmentVariables($configuration.InstallDirectory)
$registryPath = $configuration.RegistryPath
$backupDirectory = Join-Path $repositoryRoot $configuration.BackupDirectory

function Get-TerminalFontState {
    $registry = if (Test-Path -LiteralPath $registryPath) { Get-ItemProperty -LiteralPath $registryPath } else { $null }
    $items = foreach ($font in $configuration.Fonts) {
        $path = Join-Path $installDirectory $font.FileName
        $fileHash = if (Test-Path -LiteralPath $path -PathType Leaf) {
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        } else { '' }
        $registeredPath = if ($registry) { [string] $registry.($font.RegistryName) } else { '' }
        [pscustomobject]@{
            FileName = $font.FileName
            Path = $path
            FileCompliant = $fileHash -eq $font.Sha256
            RegistryName = $font.RegistryName
            RegisteredPath = $registeredPath
            RegistryCompliant = [string]::Equals($registeredPath, $path, [StringComparison]::OrdinalIgnoreCase)
        }
    }
    [pscustomobject]@{
        Package = "$($package.Name) $($package.Version)"
        Items = @($items)
        Compliant = @($items | Where-Object { -not $_.FileCompliant -or -not $_.RegistryCompliant }).Count -eq 0
    }
}

function Write-TerminalFontState {
    param([pscustomobject] $State)

    $State.Items | ForEach-Object {
        [pscustomobject]@{
            Font = $_.RegistryName
            State = if ($_.FileCompliant -and $_.RegistryCompliant) { 'compliant' } else { 'drift detected' }
            Detail = $_.Path
        }
    } | Format-Table -AutoSize -Wrap
}

function Send-FontChangeNotification {
    if (-not ('TerminalFontChangeNotifier' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TerminalFontChangeNotifier {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
    public static void Notify() {
        IntPtr result;
        SendMessageTimeout(new IntPtr(0xffff), 0x001D, IntPtr.Zero, null, 0x0002, 5000, out result);
    }
}
'@
    }
    [TerminalFontChangeNotifier]::Notify()
}

$state = Get-TerminalFontState
if ($Mode -eq 'Test') {
    Write-TerminalFontState $state
    if (-not $state.Compliant) { exit 1 }
    exit 0
}

if ($state.Compliant -and $Mode -ne 'Reinitialize') {
    Write-TerminalFontState $state
    Write-Host "$($state.Package) terminal fonts are unchanged."
    exit 0
}

$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) "terminal-fonts-$([guid]::NewGuid().ToString('N'))"
$archivePath = Join-Path $temporaryDirectory 'FiraCode.zip'
$expandedDirectory = Join-Path $temporaryDirectory 'expanded'
try {
    New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
    Invoke-WebRequest -Uri $package.Uri -OutFile $archivePath -UseBasicParsing
    $archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($archiveHash -ne $package.Sha256) {
        throw "Fira Code archive SHA-256 mismatch. Expected $($package.Sha256), got $archiveHash."
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $expandedDirectory
    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    New-Item -Path $registryPath -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    foreach ($font in $configuration.Fonts) {
        $source = Join-Path $expandedDirectory "ttf\$($font.FileName)"
        $destination = Join-Path $installDirectory $font.FileName
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Fira Code archive is missing $($font.FileName)." }
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -ne $font.Sha256) {
            throw "$($font.FileName) SHA-256 mismatch. Expected $($font.Sha256), got $sourceHash."
        }
        if (Test-Path -LiteralPath $destination -PathType Leaf) {
            $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($destinationHash -ne $font.Sha256) {
                Copy-Item -LiteralPath $destination -Destination (Join-Path $backupDirectory "$($font.FileName).$timestamp.bak")
            }
        }
        Copy-Item -LiteralPath $source -Destination $destination -Force
        Set-ItemProperty -LiteralPath $registryPath -Name $font.RegistryName -Value $destination -Type String
    }
    Send-FontChangeNotification
} finally {
    if (Test-Path -LiteralPath $temporaryDirectory -PathType Container) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
    }
}

$result = Get-TerminalFontState
Write-TerminalFontState $result
if (-not $result.Compliant) { throw "$($result.Package) did not reach the declared per-user font state." }
Write-Host "$($result.Package) installed per-user from the hash-pinned official release."
