BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-AnalysisDifferencing.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path $PSHOME 'powershell.exe'
    } else {
        (Get-Command pwsh).Source
    }
}

Describe 'Analysis differencing contracts' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'BehaviorInterfaces' }, @{ Section = 'BehaviorPlanning' },
        @{ Section = 'BehaviorSafety' }, @{ Section = 'BehaviorDifferential' },
        @{ Section = 'BinaryPlanning' }, @{ Section = 'BinaryIsolation' },
        @{ Section = 'GraphArtifacts' }, @{ Section = 'GraphSafety' },
        @{ Section = 'GraphSchema' }, @{ Section = 'QuerySchema' },
        @{ Section = 'BinaryReporting' }, @{ Section = 'EvidenceBoundary' },
        @{ Section = 'Interfaces' }, @{ Section = 'Compatibility' },
        @{ Section = 'Documentation' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
