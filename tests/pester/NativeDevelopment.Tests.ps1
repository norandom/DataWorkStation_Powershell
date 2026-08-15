BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-NativeDevelopmentState.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source }
}

Describe 'Native development desired-state contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'ModuleContract' }, @{ Section = 'MsvcContract' },
        @{ Section = 'StateContract' }, @{ Section = 'SafetyContract' },
        @{ Section = 'ProfileContract' }, @{ Section = 'EnvironmentContract' },
        @{ Section = 'DualShellContract' }, @{ Section = 'CMakeContract' },
        @{ Section = 'RustContract' }, @{ Section = 'JavaContract' }, @{ Section = 'IntegrationContract' },
        @{ Section = 'CommandSurface' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
