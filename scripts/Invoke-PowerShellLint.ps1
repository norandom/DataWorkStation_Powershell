[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Path
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$settingsPath = Join-Path $repositoryRoot 'PSScriptAnalyzerSettings.psd1'
$requiredVersion = '1.25.0'

$module = Get-Module -ListAvailable PSScriptAnalyzer |
    Where-Object Version -eq $requiredVersion |
    Select-Object -First 1
if (-not $module) {
    throw "PSScriptAnalyzer $requiredVersion is required. Run: pwsh -NoProfile -File .\scripts\Install-PreCommitHook.ps1"
}
Import-Module PSScriptAnalyzer -RequiredVersion $requiredVersion -Force

if (-not $Path -or $Path.Count -eq 0) {
    $Path = @(
        git -C $repositoryRoot ls-files -- '*.ps1' '*.psm1' '*.psd1'
        if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate tracked PowerShell files.' }
    )
}

$findings = [Collections.Generic.List[object]]::new()
foreach ($candidate in @($Path | Sort-Object -Unique)) {
    $resolvedCandidate = if ([IO.Path]::IsPathRooted($candidate)) { $candidate } else { Join-Path $repositoryRoot $candidate }
    if (-not (Test-Path -LiteralPath $resolvedCandidate -PathType Leaf)) { continue }
    foreach ($finding in @(Invoke-ScriptAnalyzer -Path $resolvedCandidate -Settings $settingsPath)) {
        $findings.Add($finding)
    }
}

foreach ($finding in $findings) {
    $relativePath = [IO.Path]::GetRelativePath($repositoryRoot, $finding.ScriptPath)
    Write-Output ("{0}:{1}:{2}: {3} {4}: {5}" -f $relativePath, $finding.Line, $finding.Column, $finding.Severity, $finding.RuleName, $finding.Message)
}

if ($findings.Count -gt 0) {
    Write-Error "PowerShell lint failed with $($findings.Count) finding(s)."
    exit 1
}

Write-Host "PowerShell lint passed for $(@($Path).Count) file(s)."
