BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $repositoryRoot 'scripts\Invoke-WslCompaction.ps1') -Distribution unused
}

Describe 'WSL compaction target validation' {
    BeforeEach {
        Mock Get-ChildItem { [pscustomobject]@{ Name = 'registration' } }
        Mock Get-ItemProperty { [pscustomobject]@{ DistributionName = 'Debian'; Version = 2; BasePath = 'C:\WSL\Debian'; VhdFileName = 'ext4.vhdx' } }
        Mock Get-Item { [pscustomobject]@{ FullName = 'C:\WSL\Debian\ext4.vhdx'; Length = 100GB; PSIsContainer = $false; Attributes = [IO.FileAttributes]::Archive } }
    }
    It 'accepts a case-insensitive registered name' {
        (Get-WslCompactionTarget -Name debian).Distribution | Should -BeExactly 'Debian'
    }
    It 'rejects unknown names before opening a disk' {
        { Get-WslCompactionTarget -Name missing } | Should -Throw '*not found*'
        Should -Invoke Get-Item -Times 0
    }
    It 'rejects WSL 1' {
        Mock Get-ItemProperty { [pscustomobject]@{ DistributionName = 'Debian'; Version = 1 } }
        { Get-WslCompactionTarget -Name Debian } | Should -Throw '*WSL 2*'
    }
    It 'rejects a registered filename escaping the distribution directory' {
        Mock Get-ItemProperty { [pscustomobject]@{ DistributionName = 'Debian'; Version = 2; BasePath = 'C:\WSL\Debian'; VhdFileName = '..\other.vhdx' } }
        { Get-WslCompactionTarget -Name Debian } | Should -Throw '*filename is invalid*'
        Should -Invoke Get-Item -Times 0
    }
    It 'does not silently change sparse disks' {
        Mock Get-Item { [pscustomobject]@{ PSIsContainer = $false; Attributes = [IO.FileAttributes]::SparseFile } }
        { Get-WslCompactionTarget -Name Debian } | Should -Throw '*sparse*'
    }
}

Describe 'WSL compaction execution boundaries' {
    BeforeEach {
        $script:operations = [Collections.Generic.List[string]]::new()
        Mock Get-WslCompactionTarget { [pscustomobject]@{ Distribution = 'Debian'; Path = 'C:\WSL\Debian\ext4.vhdx'; BeforeBytes = 100GB } }
        Mock Test-WslCompactionAdministrator { $true }
        Mock Import-Module {} -ParameterFilter { $Name -eq 'Hyper-V' }
        Mock Get-VHD { [pscustomobject]@{ VhdType = 'Dynamic'; VhdFormat = 'VHDX'; Size = 1TB; Attached = $false } }
        Mock Invoke-WslCompactionCommand { $script:operations.Add($ArgumentList -join ' ') }
        Mock Optimize-VHD { $script:operations.Add('compact') }
        Mock Get-Item { [pscustomobject]@{ Length = 60GB } }
    }
    It 'WhatIf does not elevate, start, trim, stop or compact' {
        Invoke-WslCompaction -Distribution Debian -WhatIf
        Should -Invoke Test-WslCompactionAdministrator -Times 0
        Should -Invoke Invoke-WslCompactionCommand -Times 0
        Should -Invoke Optimize-VHD -Times 0
    }
    It 'trims and syncs before stopping only the selected distribution and compacting' {
        $result = Invoke-WslCompaction -Distribution Debian
        $script:operations.ToArray() | Should -Be @(
            '--distribution Debian --user root --exec /bin/sh -c export PATH="$PATH:/usr/sbin:/sbin"; exec fstrim --verbose /'
            '--distribution Debian --user root --exec sync'
            '--terminate Debian'
            'compact'
        )
        $result.ReclaimedGiB | Should -Be 40
        $result.State | Should -Be 'Stopped'
        Should -Invoke Optimize-VHD -Times 1 -ParameterFilter { $Path -eq 'C:\WSL\Debian\ext4.vhdx' -and $Mode -eq 'Full' }
    }
    It 'releases an idle WSL VM when terminating the distribution leaves its disk attached' {
        $script:attached = $true
        Mock Get-VHD { [pscustomobject]@{ VhdType = 'Dynamic'; VhdFormat = 'VHDX'; Size = 1TB; Attached = $script:attached } }
        Mock Invoke-WslCompactionCommand { '' } -ParameterFilter { $ArgumentList[0] -eq '--list' }
        Mock Invoke-WslCompactionCommand { $script:attached = $false } -ParameterFilter { $ArgumentList[0] -eq '--shutdown' }
        Invoke-WslCompaction -Distribution Debian
        Should -Invoke Invoke-WslCompactionCommand -Times 1 -ParameterFilter { $ArgumentList[0] -eq '--shutdown' }
        Should -Invoke Optimize-VHD -Times 1
    }
    It 'does not shut down a VM with another running distribution or compact its attached disk' {
        Mock Get-VHD { [pscustomobject]@{ VhdType = 'Dynamic'; VhdFormat = 'VHDX'; Size = 1TB; Attached = $true } }
        Mock Invoke-WslCompactionCommand { 'OtherDistro' } -ParameterFilter { $ArgumentList[0] -eq '--list' }
        Mock Start-Sleep { throw 'Disk remains attached' }
        { Invoke-WslCompaction -Distribution Debian } | Should -Throw '*remains attached*'
        Should -Invoke Invoke-WslCompactionCommand -Times 0 -ParameterFilter { $ArgumentList[0] -eq '--shutdown' }
        Should -Invoke Optimize-VHD -Times 0
    }
    It 'does not stop or compact when trim fails' {
        Mock Invoke-WslCompactionCommand { throw 'trim failed' }
        { Invoke-WslCompaction -Distribution Debian } | Should -Throw '*trim failed*'
        Should -Invoke Invoke-WslCompactionCommand -Times 1
        Should -Invoke Optimize-VHD -Times 0
    }
    It 'does not compact when stopping fails' {
        Mock Invoke-WslCompactionCommand { throw 'stop failed' } -ParameterFilter { $ArgumentList[0] -eq '--terminate' }
        { Invoke-WslCompaction -Distribution Debian } | Should -Throw '*stop failed*'
        Should -Invoke Optimize-VHD -Times 0
    }
    It 'fails before starting WSL when the disk is not dynamic' {
        Mock Get-VHD { [pscustomobject]@{ VhdType = 'Fixed'; VhdFormat = 'VHDX' } }
        { Invoke-WslCompaction -Distribution Debian } | Should -Throw '*dynamic VHDX*'
        Should -Invoke Invoke-WslCompactionCommand -Times 0
    }
    It 'uses only one executable when multiple PowerShell applications resolve' {
        Mock Test-WslCompactionAdministrator { $false }
        Mock Get-Command { @([pscustomobject]@{ Source = 'C:\first\pwsh.exe' }, [pscustomobject]@{ Source = 'C:\second\pwsh.exe' }) } -ParameterFilter { $Name -eq 'pwsh.exe' }
        Mock sudo.exe { $script:elevatedArguments = @($args); $global:LASTEXITCODE = 0 }
        Invoke-WslCompaction -Distribution Debian
        $script:elevatedArguments[0] | Should -Be 'C:\first\pwsh.exe'
        $script:elevatedArguments | Should -Not -Contain 'C:\second\pwsh.exe'
        Should -Invoke Invoke-WslCompactionCommand -Times 0
    }
    It 'refuses elevation under another Windows user' {
        { Invoke-WslCompaction -Distribution Debian -ExpectedUserSid 'different-user' } | Should -Throw '*changed the Windows user*'
        Should -Invoke Get-WslCompactionTarget -Times 0
    }
}
