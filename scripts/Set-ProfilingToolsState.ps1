[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\profiling-tools.psd1')
$wptRoot = $configuration.WPT.InstallRoot
$wptExecutables = @('wpa.exe', 'wpr.exe', 'xperf.exe', 'wpaexporter.exe')
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Stop).Source
$dotnet = (Get-Command dotnet.exe -CommandType Application -ErrorAction Stop).Source

function Get-Aria2Path {
    $command = Get-Command aria2c.exe -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }
    Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter aria2c.exe -File -ErrorAction Ignore |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

function Get-NpmPath {
    $command = Get-Command npm.cmd -CommandType Application -ErrorAction Ignore
    if ($command) { return $command.Source }
    $candidate = 'C:\Program Files\nodejs\npm.cmd'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
}

function Test-Wpt {
    foreach ($name in $wptExecutables) {
        if (-not (Test-Path -LiteralPath (Join-Path $wptRoot $name) -PathType Leaf)) { return $false }
    }
    $installedVersion = (Get-Item -LiteralPath (Join-Path $wptRoot 'wpr.exe')).VersionInfo.ProductVersion
    try { return [version]$installedVersion -ge [version]$configuration.WPT.ToolVersion } catch { return $false }
}

function Test-PySpy {
    $output = & $uv tool list 2>$null
    $LASTEXITCODE -eq 0 -and $output -match "(?m)^py-spy v$([regex]::Escape($configuration.PySpy.Version))$"
}

function Test-DotNetTrace {
    $output = & $dotnet tool list --global 2>$null
    $LASTEXITCODE -eq 0 -and $output -match "(?m)^dotnet-trace\s+$([regex]::Escape($configuration.DotNetTrace.Version))\s+"
}

function Test-Speedscope {
    $npm = Get-NpmPath
    if (-not $npm) { return $false }
    $json = & $npm list --global --depth=0 --json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) { return $false }
    try {
        $state = $json | ConvertFrom-Json
        return $state.dependencies.speedscope.version -eq $configuration.Speedscope.Version
    } catch { return $false }
}

function Test-AmdUProf {
    Test-Path -LiteralPath (Join-Path $configuration.AmdUProf.InstallRoot 'AMDuProf.exe') -PathType Leaf
}

function Install-Wpt {
    $downloadDirectory = Join-Path $env:LOCALAPPDATA 'PowerShellWorkstation\downloads'
    New-Item -ItemType Directory -Path $downloadDirectory -Force | Out-Null
    $installer = Join-Path $downloadDirectory "adksetup-$($configuration.WPT.Version).exe"
    $aria2 = Get-Aria2Path
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        if ($aria2) {
            & $aria2 --continue=true --max-connection-per-server=3 --split=3 --dir=$downloadDirectory --out=(Split-Path -Leaf $installer) $configuration.WPT.Url
        } else {
            & curl.exe --fail --location --retry 3 --output $installer $configuration.WPT.Url
        }
        if ($LASTEXITCODE -ne 0) { throw "WPT bootstrap download failed: $LASTEXITCODE" }
    }

    $actualHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $configuration.WPT.Sha256) { throw "ADK installer hash mismatch: $actualHash" }
    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notlike 'CN=Microsoft Corporation*') {
        throw "ADK installer signature validation failed: $($signature.Status)"
    }

    $started = Get-Date
    & sudo.exe $installer /quiet /ceip off /features OptionId.WindowsPerformanceToolkit
    if ($LASTEXITCODE -ne 0) { throw "WPT bootstrap failed to launch: $LASTEXITCODE" }

    $deadline = (Get-Date).AddMinutes(20)
    do {
        Start-Sleep -Seconds 5
        $workers = @(Get-Process adksetup -ErrorAction Ignore | Where-Object {
            try { $_.StartTime -ge $started.AddSeconds(-5) } catch { $true }
        })
        if ($workers.Count -eq 0 -and (Test-Wpt)) { return }
    } while ((Get-Date) -lt $deadline)

    throw 'Windows Performance Toolkit did not finish installing within 20 minutes.'
}

$checks = [ordered]@{
    WPT = Test-Wpt
    PySpy = Test-PySpy
    DotNetTrace = Test-DotNetTrace
    Speedscope = Test-Speedscope
    AmdUProfOptional = Test-AmdUProf
}

if ($Mode -eq 'Test') {
    $checks.GetEnumerator() | ForEach-Object {
        $required = $_.Key -ne 'AmdUProfOptional'
        [pscustomobject]@{
            Tool = $_.Key
            Required = $required
            State = if ($_.Value) { 'compliant' } elseif ($required) { 'drift detected' } else { 'not installed (explicit EULA)' }
        }
    } | Format-Table -AutoSize
    if (@($checks.GetEnumerator() | Where-Object { $_.Key -ne 'AmdUProfOptional' -and -not $_.Value }).Count) { exit 1 }
    exit 0
}

if (-not $checks.WPT) { Install-Wpt }

if (-not $checks.PySpy -or $Mode -eq 'Reinitialize') {
    & $uv tool install --upgrade "py-spy==$($configuration.PySpy.Version)"
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install py-spy: $LASTEXITCODE" }
}

if (-not $checks.DotNetTrace) {
    $installed = & $dotnet tool list --global 2>$null
    if ($installed -match '(?m)^dotnet-trace\s+') {
        & $dotnet tool update --global dotnet-trace --version $configuration.DotNetTrace.Version
    } else {
        & $dotnet tool install --global dotnet-trace --version $configuration.DotNetTrace.Version
    }
    if ($LASTEXITCODE -ne 0) { throw "dotnet failed to install dotnet-trace: $LASTEXITCODE" }
}

if (-not $checks.Speedscope -or $Mode -eq 'Reinitialize') {
    $npm = Get-NpmPath
    if (-not $npm) { throw 'Node.js LTS and npm must be installed before Speedscope.' }
    & $npm install --global "speedscope@$($configuration.Speedscope.Version)"
    if ($LASTEXITCODE -ne 0) { throw "npm failed to install Speedscope: $LASTEXITCODE" }
}

if (-not (Test-Wpt) -or -not (Test-PySpy) -or -not (Test-DotNetTrace) -or -not (Test-Speedscope)) {
    throw 'Profiling tools did not reach the requested state.'
}

if (-not (Test-AmdUProf)) {
    Write-Warning "AMD uProf $($configuration.AmdUProf.Version) remains explicit because AMD requires EULA acceptance. Run: uprof-install"
}
Write-Host "Profiling tool state '$Mode' completed successfully."
