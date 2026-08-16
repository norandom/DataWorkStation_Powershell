BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-NativeForensicVerification.ps1'
    $script:runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') {
        Join-Path $PSHOME 'powershell.exe'
    } else {
        (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
}

Describe 'Native forensic verification US1 and US2 contracts' -Tag 'NativeForensics-US1-US2' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'HumanInterface' }, @{ Section = 'NativeWindowsBoundary' },
        @{ Section = 'Planning' }, @{ Section = 'EvidenceReadOnly' },
        @{ Section = 'SegmentInventory' }, @{ Section = 'SegmentIntegrity' },
        @{ Section = 'MediaDigests' }, @{ Section = 'HashlessEvidence' },
        @{ Section = 'FormatCertification' }, @{ Section = 'InvocationEvidence' },
        @{ Section = 'ReportContract' }, @{ Section = 'JsonParity' },
        @{ Section = 'HostileOutput' }, @{ Section = 'HistoricalAttribution' },
        @{ Section = 'OfflineExecution' }, @{ Section = 'ReportPersistence' },
        @{ Section = 'RuntimeCompatibility' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}

Describe 'Native forensic verification later-phase contracts' -Tag 'NativeForensics-Later' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'CatalogSchema' }, @{ Section = 'InstallIntegrity' },
        @{ Section = 'ToolDrift' }, @{ Section = 'UpdatePolicy' },
        @{ Section = 'UpgradeCertification' }, @{ Section = 'CertificationCorpus' },
        @{ Section = 'DocumentationRouting' },
        @{ Section = 'ReleasePackageContract' }, @{ Section = 'InstallWithoutBuild' },
        @{ Section = 'BuildRevisionPolicy' }, @{ Section = 'ReleaseTrustAnchor' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
