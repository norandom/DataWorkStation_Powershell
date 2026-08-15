#pester:no-parallel

Describe 'Exclusive test lane marker' {
    It 'runs as a valid sequential Pester file' {
        $true | Should -BeTrue
    }
}
