[CmdletBinding()]
param()

function Test-SublimeTextState {
    $ErrorActionPreference = 'Stop'
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $runtime = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $apply = Join-Path $repositoryRoot 'Apply-Workstation.ps1'
    foreach ($selection in @(@(), @('-Module', 'All'))) {
        $plan = & $runtime -NoProfile -File $apply -Mode Test -Plan -Json @selection | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or 'SublimeText' -in $plan.ExecutionOrder.Name) { throw 'SublimeText must be excluded from default and All plans.' }
    }
    $focused = & $runtime -NoProfile -File $apply -Mode Ensure -Module SublimeText -Plan -Json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or ($focused.ExecutionOrder.Name -join ',') -ne 'PowerShell7,SublimeText') { throw 'Unexpected SublimeText dependency plan.' }

    $resource = Join-Path $repositoryRoot 'scripts\Set-SublimeTextState.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($resource, [ref] $tokens, [ref] $parseErrors)
    if ($parseErrors.Count) { throw 'Sublime resource does not parse.' }
    foreach ($name in 'Test-SublimeTextPathEntry','Get-SublimeTextUserPath','Get-SublimeTextState') {
        $functionAst = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $false)
        . ([scriptblock]::Create($functionAst.Extent.Text))
    }
    $configuration = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\sublime-text.psd1')
    $directory = 'C:\Program Files\Sublime Text'
    $original = 'C:\First;C:\Tools With Spaces;'
    $merged = Get-SublimeTextUserPath -PathValue $original -Directory $directory
    if ($merged -cne 'C:\First;C:\Tools With Spaces;C:\Program Files\Sublime Text') { throw 'PATH merge lost unrelated entries.' }
    if ((Get-SublimeTextUserPath -PathValue $merged -Directory $directory) -cne $merged) { throw 'Repeated merge is not idempotent.' }
    $equivalent = 'C:\First;"c:\program files\sublime text\";C:\Last'
    if ((Get-SublimeTextUserPath -PathValue $equivalent -Directory $directory) -cne $equivalent) { throw 'Equivalent PATH entry was duplicated.' }
    if ((Get-SublimeTextUserPath -PathValue $null -Directory $directory) -cne $directory) { throw 'Empty PATH is not supported.' }

    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('sublime-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $previousUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $previousProcessPath = $env:Path
    try {
        $missing = Get-SublimeTextState -Directory $fixture -UserPath $fixture
        if ($missing.State -ne 'drift detected' -or $missing.Installed) { throw 'Missing executable was accepted.' }
        New-Item -ItemType File -Path (Join-Path $fixture $configuration.Command) | Out-Null
        $offPath = Get-SublimeTextState -Directory $fixture -UserPath 'C:\Other'
        if ($offPath.State -ne 'drift detected' -or $offPath.OnUserPath) { throw 'Missing PATH entry was accepted.' }
        $complete = Get-SublimeTextState -Directory $fixture -UserPath $fixture | ConvertTo-Json | ConvertFrom-Json
        if ($complete.State -ne 'compliant' -or -not $complete.Optional) { throw 'Complete state or JSON contract failed.' }

        # A fresh child with an absent configured installation must remain observational or refuse mutation.
        $fixtureScripts = Join-Path $fixture 'scripts'
        $fixtureConfig = Join-Path $fixture 'config'
        New-Item -ItemType Directory -Path $fixtureScripts,$fixtureConfig | Out-Null
        $fixtureResource = Join-Path $fixtureScripts 'Set-SublimeTextState.ps1'
        Copy-Item -LiteralPath $resource -Destination $fixtureResource
        $missingDirectory = (Join-Path $fixture 'missing').Replace("'", "''")
        Set-Content -LiteralPath (Join-Path $fixtureConfig 'sublime-text.psd1') -Value "@{ InstallDirectory = '$missingDirectory'; Command = 'subl.exe' }"
        $result = & $runtime -NoProfile -File $fixtureResource -Mode Test -Json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 1 -or $result.Installed -or $result.State -ne 'drift detected') { throw 'Test must report missing installation as drift.' }
        if ([Environment]::GetEnvironmentVariable('Path', 'User') -cne $previousUserPath -or $env:Path -cne $previousProcessPath) { throw 'Test changed PATH.' }
        $failure = & $runtime -NoProfile -File $fixtureResource -Mode Ensure 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $failure -notmatch 'Sublime Text is not installed') { throw 'Ensure did not reject the absent installation.' }
        if ([Environment]::GetEnvironmentVariable('Path', 'User') -cne $previousUserPath -or $env:Path -cne $previousProcessPath) { throw 'Failed Ensure changed PATH.' }
    } finally {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolved.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Write-Host 'Sublime Text opt-in planning, state, PATH preservation, and failure safety checks passed.'
}

Test-SublimeTextState
