@{
    SchemaVersion = 1
    Modules = @(
        @{
            Name = 'Sudo'
            Order = 10
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Windows sudo inline-mode bootstrap used by privileged modules.'
        }
        @{
            Name = 'Packages'
            Order = 20
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'WinGet Configuration package state.'
        }
        @{
            Name = 'WindowsFeatures'
            Order = 30
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Hyper-V and Windows Sandbox optional features.'
        }
        @{
            Name = 'Hardening'
            Order = 40
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'DeveloperBaseline Windows security controls.'
        }
        @{
            Name = 'DeveloperTools'
            Order = 50
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'CodeQL, Semgrep, TTD, rsync, and PoolMon support.'
        }
        @{
            Name = 'ProfilingTools'
            Order = 60
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'WPT, py-spy, dotnet-trace, and Speedscope.'
        }
        @{
            Name = 'SkillOpt'
            Order = 70
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned SkillOpt installation and conservative configuration.'
        }
        @{
            Name = 'PowerShellProfile'
            Order = 80
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'PowerShell 7 and Windows PowerShell profile components.'
        }
        @{
            Name = 'FocusFollowsMouse'
            Order = 90
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Current-user hover focus without raising windows.'
        }
        @{
            Name = 'DefenderExclusions'
            Order = 100
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Declared Defender path exclusions and performance policy.'
        }
        @{
            Name = 'SmartScreen'
            Order = 110
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Microsoft Defender SmartScreen warning policy.'
        }
        @{
            Name = 'WslMemory'
            Order = 120
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'WSL memory, swap, and reclamation limits.'
        }
        @{
            Name = 'Pagefile'
            Order = 130
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Windows pagefile size policy.'
        }
        @{
            Name = 'EventLogs'
            Order = 140
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Audit channels, retention, and scheduled EVTX exports.'
        }
        @{
            Name = 'Firewall'
            Order = 150
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Managed Windows Firewall profiles and allowlist.'
        }
        @{
            Name = 'Debloat'
            Order = 160
            Default = $false
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure')
            Privileged = $true
            Destructive = $true
            Description = 'Opt-in DeveloperMinimal software removal profile.'
        }
    )
}
