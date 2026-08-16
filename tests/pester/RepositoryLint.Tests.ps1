BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-RepositoryLint.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path $PSHOME 'powershell.exe'
    } else {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
}

Describe 'Repository lint contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'Interfaces' },
        @{ Section = 'Hooks' },
        @{ Section = 'Dependencies' },
        @{ Section = 'Documentation' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
