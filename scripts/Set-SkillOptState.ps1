[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Ensure'
)

$ErrorActionPreference = 'Stop'
$configuration = Import-PowerShellDataFile (Join-Path $PSScriptRoot '..\config\skillopt.psd1')
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Stop).Source
$stateDirectory = Join-Path $env:USERPROFILE '.skillopt-sleep'
$configPath = Join-Path $stateDirectory 'config.json'

function Test-SkillOptPackage {
    $output = & $uv tool list --show-version-specifiers 2>$null | Out-String
    $LASTEXITCODE -eq 0 -and $output -match "(?m)^skillopt v$([regex]::Escape($configuration.Version)) \[required: ==$([regex]::Escape($configuration.Version))\]\r?$"
}

function Get-CurrentConfig {
    $values = [ordered]@{}
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $current = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
            foreach ($property in $current.PSObject.Properties) { $values[$property.Name] = $property.Value }
        } catch {
            throw "SkillOpt configuration is not valid JSON: $configPath"
        }
    }
    $values
}

function Test-SkillOptConfig {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { return $false }
    $current = Get-CurrentConfig
    foreach ($entry in $configuration.UserConfig.GetEnumerator()) {
        if (-not $current.Contains($entry.Key)) { return $false }
        if (($current[$entry.Key] | ConvertTo-Json -Compress) -ne ($entry.Value | ConvertTo-Json -Compress)) { return $false }
    }
    $true
}

function Set-SkillOptConfig {
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $values = Get-CurrentConfig
    foreach ($entry in $configuration.UserConfig.GetEnumerator()) { $values[$entry.Key] = $entry.Value }
    $json = $values | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($configPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

$packageOk = Test-SkillOptPackage
$configOk = Test-SkillOptConfig

if ($Mode -eq 'Test') {
    @(
        [pscustomobject]@{ Resource = 'SkillOptPackage'; State = if ($packageOk) { 'compliant' } else { 'drift detected' }; Detail = "skillopt==$($configuration.Version) via uv tool" }
        [pscustomobject]@{ Resource = 'SkillOptSafetyConfig'; State = if ($configOk) { 'compliant' } else { 'drift detected' }; Detail = $configPath }
    ) | Format-Table -AutoSize
    if (-not $packageOk -or -not $configOk) { exit 1 }
    exit 0
}

if (-not $packageOk -or $Mode -eq 'Reinitialize') {
    & $uv tool install --python $configuration.Python --force "$($configuration.Package)==$($configuration.Version)"
    if ($LASTEXITCODE -ne 0) { throw "uv failed to install SkillOpt: $LASTEXITCODE" }
}

if (-not $configOk -or $Mode -eq 'Reinitialize') { Set-SkillOptConfig }

if (-not (Test-SkillOptPackage) -or -not (Test-SkillOptConfig)) {
    throw 'SkillOpt did not reach the requested safe state.'
}

Write-Host "SkillOpt state '$Mode' completed successfully. No transcript harvest, provider call, schedule, or adoption was started."
