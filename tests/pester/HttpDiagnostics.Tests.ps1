BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:httpContract = Join-Path $repositoryRoot 'tests\Test-HttpDiagnostics.ps1'
    $script:httpRuntime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source }
}
Describe 'HTTP diagnostic evidence and command safety' {
    It 'Redaction, correlation, coverage, plans and case journaling pass without capture' {
        $output = @(& $script:httpRuntime -NoLogo -NoProfile -File $script:httpContract 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
