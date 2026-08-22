Describe 'mpv desired state' {
    It 'keeps package, GPU configuration, orchestration, and documentation aligned' {
        $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $contract = Join-Path $repositoryRoot 'tests\Test-MpvState.ps1'
        $output = @(& pwsh.exe -NoLogo -NoProfile -File $contract 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join [Environment]::NewLine)
    }
}
