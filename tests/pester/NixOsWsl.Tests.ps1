BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-NixOsWsl.ps1'
    $script:runtime = (Get-Command pwsh.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
}

Describe 'NixOS WSL and shared SSH contracts' {
    It 'keeps the system reproducible and the SSH boundaries explicit' {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
