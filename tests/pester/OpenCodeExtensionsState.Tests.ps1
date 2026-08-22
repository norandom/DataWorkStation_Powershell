BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:contract = Join-Path $repositoryRoot 'tests\Test-OpenCodeExtensionsState.ps1'
    $script:runtime = (Get-Command pwsh.exe -ErrorAction Stop).Source
}

Describe 'OpenCode extension desired state' -Tag 'OpenCodeExtensions' {
    It '<Section> passes' -ForEach @(
        @{ Section = 'Declaration' }, @{ Section = 'StateContract' },
        @{ Section = 'ModuleRouting' }, @{ Section = 'Documentation' }
    ) {
        $output = @(& $script:runtime -NoLogo -NoProfile -File $script:contract -Section $Section 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
