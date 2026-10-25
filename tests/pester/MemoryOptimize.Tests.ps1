[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '', Justification = 'These tests intentionally exercise the public MemoryOptimize alias and its double-dash arguments.')]
[CmdletBinding()]
param()

BeforeAll {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    . (Join-Path $repositoryRoot 'profile\Tools.ps1')
    Set-Alias -Name MemoryOptimize -Value Invoke-MemoryOptimization
}

Describe 'MemoryOptimize' {
    BeforeEach {
        Mock Find-NativeTool { 'C:\Tools\WinMemoryCleaner.exe' }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        $script:sample = 0
        Mock Get-CimInstance {
            $script:sample++
            [pscustomobject]@{ TotalVisibleMemorySize = 16 * 1MB; FreePhysicalMemory = $script:sample * 1MB }
        }
    }

    It 'accepts double-dash now, waits for headless exit, and measures before and after' {
        $result = MemoryOptimize --now -Json | ConvertFrom-Json
        $result.Before.UsedGiB | Should -Be 15
        $result.After.AvailableGiB | Should -Be 2
        $result.AvailableChangeGiB | Should -Be 1
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $Verb -eq 'RunAs' -and $WindowStyle -eq 'Hidden' -and $Wait -and $PassThru -and
            ($ArgumentList -join ' ') -eq '/ModifiedFileCache /StandbyList /WorkingSet'
        }
        Should -Invoke Get-CimInstance -Times 2 -Exactly
    }

    It 'opens the GUI without cleanup arguments for double-dash run' {
        MemoryOptimize --run
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter { -not $ArgumentList -and -not $Wait -and $Verb -eq 'RunAs' }
        Should -Invoke Get-CimInstance -Times 0 -Exactly
    }

    It 'shows help without starting a process by default' {
        (MemoryOptimize) -join ' ' | Should -Match 'MemoryOptimize --now'
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'rejects contradictory modes and unknown arguments before starting a process' {
        { MemoryOptimize --now --run } | Should -Throw '*Choose either*'
        { MemoryOptimize --typo } | Should -Throw
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'does not clean during WhatIf' {
        MemoryOptimize --now -WhatIf
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Get-CimInstance -Times 0 -Exactly
    }

    It 'reports missing installations' {
        Mock Find-NativeTool { $null }
        { MemoryOptimize --now } | Should -Throw '*winget install*'
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It 'does not report successful after measurements on launch failure' {
        Mock Start-Process { throw 'UAC cancelled' }
        { MemoryOptimize --now -Json } | Should -Throw '*UAC cancelled*'
        Should -Invoke Get-CimInstance -Times 1 -Exactly
    }

    It 'reports a failing process exit' {
        Mock Start-Process { [pscustomobject]@{ ExitCode = 1 } }
        { MemoryOptimize -Now -Json } | Should -Throw '*code 1*'
        Should -Invoke Get-CimInstance -Times 1 -Exactly
    }

    It 'preserves a negative measured change' {
        Mock Get-CimInstance {
            $script:sample++
            [pscustomobject]@{ TotalVisibleMemorySize = 16 * 1MB; FreePhysicalMemory = (4 - $script:sample) * 1MB }
        }
        (MemoryOptimize -Now -Json | ConvertFrom-Json).AvailableChangeGiB | Should -Be -1
    }
}
