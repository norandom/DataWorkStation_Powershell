BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-WorkstationUpdate.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source }
}

Describe 'Managed workstation update contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'CommandSurface' }, @{ Section = 'PlanContract' },
        @{ Section = 'OutputContract' }, @{ Section = 'TargetContract' },
        @{ Section = 'SafetyContract' }, @{ Section = 'DependencyContract' },
        @{ Section = 'WindowsContract' }, @{ Section = 'WinGetContract' },
        @{ Section = 'ScoopContract' }, @{ Section = 'WslContract' },
        @{ Section = 'LinuxContract' }, @{ Section = 'HomebrewContract' },
        @{ Section = 'ContainerContract' }, @{ Section = 'ReconciliationContract' },
        @{ Section = 'PrivilegeContract' }, @{ Section = 'ExecutionContract' },
        @{ Section = 'DualShellContract' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
