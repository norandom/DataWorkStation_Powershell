Describe 'Process Lasso optional package state' {
    It 'keeps default plans unchanged and detects partial installations' {
        $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $contract = Join-Path $repositoryRoot 'tests\Test-ProcessLassoState.ps1'
        $output = @(& pwsh.exe -NoLogo -NoProfile -File $contract 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    }
}
