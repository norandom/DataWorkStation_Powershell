BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-RootlessDockerState.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh).Source }
}

Describe 'Rootless Podman desired-state contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'Inspection' }, @{ Section = 'PodmanState' }, @{ Section = 'Boundary' },
        @{ Section = 'MigrationOrder' }, @{ Section = 'ModuleContract' }, @{ Section = 'LegacyCleanup' },
        @{ Section = 'CommandSurface' }, @{ Section = 'Documentation' }, @{ Section = 'Validation' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
