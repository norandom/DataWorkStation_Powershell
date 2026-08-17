BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-QuantResearchEnvironment.ps1'
    $script:runtime = (Get-Command pwsh).Source
}

Describe 'Quantitative research environment contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'ConfigurationContract' }, @{ Section = 'CommandContract' },
        @{ Section = 'BaseDeclaration' }, @{ Section = 'LockReproducibility' },
        @{ Section = 'RelativeBaseRelationship' }, @{ Section = 'NotebookEntryPoint' },
        @{ Section = 'KernelRegistryIsolation' }, @{ Section = 'OverlayIsolation' },
        @{ Section = 'OverlayMutationIsolation' }, @{ Section = 'OutputParity' },
        @{ Section = 'ObservationalStatus' }, @{ Section = 'OpenBbExtensions' },
        @{ Section = 'FailureAtomicity' }, @{ Section = 'ReconciliationScope' },
        @{ Section = 'UserContentPreservation' }, @{ Section = 'CredentialBoundary' },
        @{ Section = 'CapabilityRouting' }, @{ Section = 'RelocationNonMutation' },
        @{ Section = 'RelocationPlanContract' }, @{ Section = 'RelocationGuard' },
        @{ Section = 'MovedRootRebuild' }, @{ Section = 'FocusedBoundary' },
        @{ Section = 'PyXllDeclaration' }, @{ Section = 'PyXllStatus' },
        @{ Section = 'PyXllActivation' }, @{ Section = 'PyXllLicenseBoundary' },
        @{ Section = 'PyXllInteractivePlots' }, @{ Section = 'PyXllFailureAtomicity' },
        @{ Section = 'PyXllJupyterRibbon' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
