Describe 'Safe-Chain desired state' {
    It 'keeps release pins, trusted boundaries, orchestration, and routing aligned' {
        $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $contract = Join-Path $repositoryRoot 'tests\Test-SafeChainState.ps1'
        $output = @(& pwsh.exe -NoLogo -NoProfile -File $contract 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    }
}
