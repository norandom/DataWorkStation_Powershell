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
            Name = 'Git'
            Order = 15
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Focused WinGet Configuration state for the Git dependency.'
        }
        @{
            Name = 'Packages'
            Order = 20
            Default = $true
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'WinGet Configuration package state.'
        }
        @{
            Name = 'PowerShell7'
            Order = 18
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Focused WinGet Configuration state for the PowerShell 7 dependency.'
        }
        @{
            Name = 'Go'
            Order = 19
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Official Go package, user workspace, command PATH, and built-in toolchain selection.'
        }
        @{
            Name = 'NativeTextTools'
            Order = 23
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Native Win32 awk and sed applets installed through focused WinGet Configuration.'
        }
        @{
            Name = 'Caffeine'
            Order = 24
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Zhorn Software Caffeine idle-sleep inhibitor with enabled per-user startup.'
        }
        @{
            Name = 'Scoop'
            Order = 25
            Default = $true
            DependsOn = @('Git')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Per-user Scoop installation with official Main and Extras buckets.'
        }
        @{
            Name = 'TerminalFonts'
            Order = 26
            Default = $true
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Hash-pinned per-user Fira Code font installation.'
        }
        @{
            Name = 'ContourTerminal'
            Order = 27
            Default = $true
            DependsOn = @('Sudo', 'PowerShell7', 'TerminalFonts')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Official Contour release MSI with the translated BlueTerm theme and graphics-compatibility gate.'
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
            Name = 'LinuxHomebrew'
            Order = 45
            Default = $false
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Homebrew package manager inside the managed Debian WSL distribution.'
        }
        @{
            Name = 'LinuxAutomation'
            Order = 47
            Default = $false
            DependsOn = @('LinuxHomebrew')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned pyinfra executor inside Debian WSL for local Linux deploy files.'
        }
        @{
            Name = 'RootlessDocker'
            Order = 49
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Dedicated Debian-MW WSL distro with a rootless Docker user daemon for untrusted parsers.'
        }
        @{
            Name = 'DeveloperDocker'
            Order = 49
            Default = $false
            DependsOn = @('LinuxAutomation')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Pyinfra-managed rootful Docker daemon in Debian for Dagger.'
        }
        @{
            Name = 'DeveloperTools'
            Order = 50
            Default = $true
            DependsOn = @('DeveloperDocker', 'Go')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Go, CodeQL, Semgrep, Dagger, TTD, rsync, and PoolMon support.'
        }
        @{
            Name = 'SpecDrivenDevelopment'
            Order = 55
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Release-pinned Spec Kit EARS/TDD policy tool installed through uv.'
        }
        @{
            Name = 'MalwareHashes'
            Order = 56
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Hash-pinned malware_hashes Windows executable from its GitHub release.'
        }
        @{
            Name = 'MalwareAnalysisTools'
            Order = 65
            Default = $false
            DependsOn = @('Packages', 'WindowsFeatures', 'ProfilingTools', 'MalwareHashes')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in, hash-pinned static-analysis and Sandbox telemetry tools.'
        }
        @{
            Name = 'MalwareContainerImage'
            Order = 66
            Default = $false
            DependsOn = @('RootlessDocker')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in, locally built rootless static parser image for documents, PDFs, and binaries.'
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
            DependsOn = @('PowerShell7')
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
