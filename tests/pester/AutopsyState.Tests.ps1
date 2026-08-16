BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-AutopsyState.ps1'
    $script:runtime = (Get-Command pwsh.exe -ErrorAction Stop).Source
}

Describe 'Autopsy forensic workstation contracts' -Tag 'Autopsy' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'CatalogContract' }, @{ Section = 'ModuleContract' },
        @{ Section = 'InstallerContract' }, @{ Section = 'DefenderContract' },
        @{ Section = 'CommandSurface' }, @{ Section = 'DocumentationContract' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
