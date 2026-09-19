[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure')][string] $Mode = 'Test',
    [switch] $Json
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$policy = Import-PowerShellDataFile (Join-Path $root 'config\lasso-responsiveness.psd1')
$ini = Join-Path $env:ProgramData 'ProcessLasso\config\prolasso.ini'
$text = [IO.File]::ReadAllText($ini)
$drift = [Collections.Generic.List[string]]::new()
foreach ($key in $policy.Settings.Keys) {
    $match = [regex]::Match($text, '(?m)^' + [regex]::Escape($key) + '=([^\r\n]*)')
    if (-not $match.Success -or $match.Groups[1].Value -ine $policy.Settings[$key]) { $drift.Add($key) }
}
$exclusionMatch = [regex]::Match($text, '(?m)^OocExclusions=([^\r\n]*)')
$exclusions = @($exclusionMatch.Groups[1].Value -split ',' | Where-Object { $_ })
foreach ($processName in $policy.ProtectedProcesses) { if ($processName -notin $exclusions) { $drift.Add('Exclude:' + $processName) } }
$service = Get-CimInstance Win32_Service -Filter "Name='ProcessGovernor'"
if ($service.StartMode -ne 'Auto' -or $service.StartName -ne 'LocalSystem' -or $service.State -ne 'Running') { $drift.Add('Automatic LocalSystem service') }
$backup = $null
if ($Mode -eq 'Ensure') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run Ensure through sudo.' }
    if (-not $service -or $service.StartName -ne 'LocalSystem') { throw 'Configure the vendor governor as a LocalSystem service first.' }
    if ($drift.Count) {
        $backup = $ini + '.responsiveness-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
        Copy-Item -LiteralPath $ini -Destination $backup
        $updated = $text
        foreach ($key in $policy.Settings.Keys) {
            $pattern = '(?m)^' + [regex]::Escape($key) + '=[^\r\n]*'
            if ([regex]::Matches($updated, $pattern).Count -ne 1) { throw "Expected one existing key: $key" }
            $updated = [regex]::Replace($updated, $pattern, $key + '=' + $policy.Settings[$key])
        }
        $merged = @($exclusions + $policy.ProtectedProcesses | Sort-Object -Unique) -join ','
        if (-not $exclusionMatch.Success) { throw 'Expected existing OocExclusions key.' }
        $updated = [regex]::Replace($updated, '(?m)^OocExclusions=[^\r\n]*', 'OocExclusions=' + $merged)
        if ([IO.File]::ReadAllText($ini) -cne $text) { throw 'Lasso configuration changed during editing; no changes made.' }
        [IO.File]::WriteAllText($ini, $updated, [Text.Encoding]::Unicode)
        Set-Service -Name ProcessGovernor -StartupType Automatic
        Restart-Service -Name ProcessGovernor
        (Get-Service ProcessGovernor).WaitForStatus('Running', [timespan]::FromSeconds(15))
    }
    & sc.exe failure ProcessGovernor reset= 86400 actions= restart/5000/restart/15000/restart/60000 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Service recovery setup failed.' }
    if ($backup) { Write-Host "Lasso backup: $backup" }
    & $PSCommandPath -Mode Test -Json:$Json
    exit $LASTEXITCODE
}
$result = [pscustomobject]@{
    State = if ($drift.Count) { 'drift detected' } else { 'compliant' }
    ServiceAccount = $service.StartName
    Startup = $service.StartMode
    Differences = @($drift)
    IniPath = $ini
    Settings = $policy.Settings
    ProtectedProcesses = $policy.ProtectedProcesses
}
if ($Json) { $result | ConvertTo-Json -Depth 5 } else { $result | Format-List | Out-Host }
if ($drift.Count) { exit 1 }
