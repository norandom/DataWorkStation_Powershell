BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:profileConfiguration = Join-Path $repositoryRoot 'profile\Config.ps1'
}

Describe 'Profile PATH normalization' {
    It 'recovers CMD command resolution from an inherited PATH over 8191 characters' {
        $originalPath = $env:PATH
        try {
            $systemDirectory = Join-Path $env:SystemRoot 'System32'
            $env:PATH = (($systemDirectory + ';') * 500)
            $env:PATH.Length | Should -BeGreaterThan 8191
            . $script:profileConfiguration
            $env:PATH.Length | Should -BeLessThan 8191
            $output = & (Join-Path $systemDirectory 'cmd.exe') /d /c 'where.exe cmd.exe'
            $LASTEXITCODE | Should -Be 0
            $output | Should -Contain (Join-Path $systemDirectory 'cmd.exe')
        } finally { $env:PATH = $originalPath }
    }

    It 'preserves first-match precedence and handles case, quotes and trailing separators' {
        $originalPath = $env:PATH
        try {
            $env:PATH = 'C:\First\;"c:\FIRST";C:\Second;C:\SECOND\;' + (Join-Path $env:SystemRoot 'System32')
            . $script:profileConfiguration
            $priorityPaths = @($env:PATH -split ';' | Where-Object { $_ -match '^C:\\(First|Second)' })
            $priorityPaths | Should -Be @('C:\First\', 'C:\Second')
            $firstResult = $env:PATH
            . $script:profileConfiguration
            $env:PATH | Should -BeExactly $firstResult
        } finally { $env:PATH = $originalPath }
    }

    It 'warns about distinct paths near the CMD limit without silently truncating them' {
        $originalPath = $env:PATH
        Mock Write-Warning {}
        try {
            $distinctPaths = @(1..120 | ForEach-Object { 'C:\Distinct-tool-directory-with-a-long-name-and-no-duplicate-{0:D4}\bin' -f $_ })
            $env:PATH = ($distinctPaths + (Join-Path $env:SystemRoot 'System32')) -join ';'
            . $script:profileConfiguration
            foreach ($distinctPath in $distinctPaths) { ($env:PATH -split ';') | Should -Contain $distinctPath }
            Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -like '*PATH*8191*npm/npx*' }
        } finally { $env:PATH = $originalPath }
    }
}
