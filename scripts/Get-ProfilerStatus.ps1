[CmdletBinding()]
param([switch] $Json)

$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\profiling-tools.psd1')

$wptRoot = $configuration.WPT.InstallRoot
$paths = [ordered]@{
    WPA = Join-Path $wptRoot 'wpa.exe'
    WPR = Join-Path $wptRoot 'wpr.exe'
    Xperf = Join-Path $wptRoot 'xperf.exe'
    WPAExporter = Join-Path $wptRoot 'wpaexporter.exe'
    QView = Join-Path $env:LOCALAPPDATA 'Programs\qView\qView.exe'
    PySpy = Join-Path $env:USERPROFILE '.local\bin\py-spy.exe'
    DotNetTrace = Join-Path $env:USERPROFILE '.dotnet\tools\dotnet-trace.exe'
    Speedscope = Join-Path $env:APPDATA 'npm\speedscope.cmd'
    AmdUProf = Join-Path $configuration.AmdUProf.InstallRoot 'AMDuProf.exe'
    AmdUProfCLI = Join-Path $configuration.AmdUProf.InstallRoot 'AMDuProfCLI.exe'
}

$purpose = @{
    WPA = 'Interactive ETW visualization'
    WPR = 'Native and system-wide trace capture'
    Xperf = 'ETW command-line compatibility'
    WPAExporter = 'Headless WPA table export'
    QView = 'Lightweight native SVG flame-graph viewer'
    PySpy = 'Python sampled stacks and SVG flame graphs'
    DotNetTrace = '.NET EventPipe trace capture'
    Speedscope = 'Local interactive flame-graph viewer'
    AmdUProf = 'AMD hardware-counter GUI (explicit EULA install)'
    AmdUProfCLI = 'AMD hardware-counter CLI (explicit EULA install)'
}

$rows = foreach ($entry in $paths.GetEnumerator()) {
    $present = Test-Path -LiteralPath $entry.Value -PathType Leaf
    $version = $null
    if ($present) {
        try {
            if ($entry.Key -eq 'Speedscope') { $version = $configuration.Speedscope.Version }
            elseif ($entry.Key -eq 'PySpy') { $version = (& $entry.Value --version 2>$null) -replace '^py-spy\s+', '' }
            else { $version = (Get-Item -LiteralPath $entry.Value).VersionInfo.ProductVersion }
        } catch { Write-Verbose "Unable to read $($entry.Key) version: $($_.Exception.Message)" }
    }
    [pscustomobject]@{
        Tool = $entry.Key
        Installed = $present
        Required = $entry.Key -notlike 'AmdUProf*'
        Version = $version
        Path = $entry.Value
        Purpose = $purpose[$entry.Key]
    }
}

if ($Json) { $rows | ConvertTo-Json -Depth 3 } else { $rows }
