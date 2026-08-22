BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-WorkstationBaseline.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source }
}

Describe 'Workstation baseline contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'HarnessSelfTest' },
        @{ Section = 'Modules' },
        @{ Section = 'ModulePlanning' },
        @{ Section = 'PlanSafety' },
        @{ Section = 'StateSafety' },
        @{ Section = 'WindowsSafety' },
        @{ Section = 'DebloatSafety' },
        @{ Section = 'Capabilities' },
        @{ Section = 'TrickyOutput' },
        @{ Section = 'DiagnosticSkills' },
        @{ Section = 'Contour' },
        @{ Section = 'DeveloperTools' },
        @{ Section = 'SpecDrivenDevelopment' },
        @{ Section = 'BootstrapStages' },
        @{ Section = 'PowerShellRuntimes' },
        @{ Section = 'SecurityCommandFamilies' },
        @{ Section = 'WindowsTerminal' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
