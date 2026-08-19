BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-CleanupState.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source }
}

Describe 'Cleanup and local configuration contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'LocalConfiguration' },
        @{ Section = 'WindowsCleanup' },
        @{ Section = 'TraceCleanup' },
        @{ Section = 'CommandSurface' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
