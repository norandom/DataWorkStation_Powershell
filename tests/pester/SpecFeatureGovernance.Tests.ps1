#pester:no-parallel
BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-SpecFeatureGovernance.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        (Get-Command powershell.exe -ErrorAction Stop).Source
    } else {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
}

Describe 'Spec feature governance contracts' -Tag 'SpecFeatureGovernance' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'HumanCommand' }, @{ Section = 'OutputParity' },
        @{ Section = 'ModuleReference' }, @{ Section = 'StateRouteReference' },
        @{ Section = 'PathBoundary' }, @{ Section = 'RequiredArtifacts' },
        @{ Section = 'FinalGate' }, @{ Section = 'ActionableFailure' },
        @{ Section = 'PairedReference' }, @{ Section = 'LegacyBoundary' },
        @{ Section = 'LegacyFingerprint' }, @{ Section = 'NonMutation' },
        @{ Section = 'PreCommitHook' }, @{ Section = 'DocumentationAndRouting' },
        @{ Section = 'UnrelatedDraft' }
    ) {
        $arguments = @('-NoLogo', '-NoProfile')
        if ($script:runtime -like '*powershell.exe') { $arguments += @('-ExecutionPolicy', 'Bypass') }
        $arguments += @('-File', $script:contract, '-Section', $Section)
        $output = @(& $script:runtime @arguments 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
