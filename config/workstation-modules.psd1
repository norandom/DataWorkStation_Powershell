@{
    SchemaVersion = 2
    Stages = @(
        @{
            Name = 'Inbox'
            Order = 0
            DependsOn = @()
            Description = 'Bootstrap using only Windows PowerShell 5.1 and native Windows commands already on the host.'
        }
        @{
            Name = 'Core'
            Order = 10
            DependsOn = @('PowerShell7')
            Description = 'Foundational state applied only after the PowerShell 7 dependency is compliant.'
        }
        @{
            Name = 'Extended'
            Order = 20
            DependsOn = @('PowerShell7')
            Description = 'Remaining workstation capabilities applied after every selected earlier stage succeeds.'
        }
    )
    Modules = @(
        @{
            Name = 'Sudo'
            Stage = 'Inbox'
            Runtime = 'Inbox'
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
            Stage = 'Core'
            Runtime = 'Native'
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
            Stage = 'Core'
            Runtime = 'Native'
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
            Stage = 'Inbox'
            Runtime = 'Native'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 19
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Official Go package, user workspace, command PATH, and built-in toolchain selection.'
        }
        @{
            Name = 'PowerShellTesting'
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 21
            Default = $true
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned Pester framework shared by the parallel PowerShell 7 and sequential Windows PowerShell test lanes.'
        }
        @{
            Name = 'Mpv'
            FeatureSpec = 'specs/013-default-workstation-utilities'
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 22
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Official mpv Windows build with safe Radeon hardware decode and Direct3D 11 rendering.'
        }
        @{
            Name = 'NativeTextTools'
            Stage = 'Core'
            Runtime = 'PowerShell7'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 27
            Default = $true
            DependsOn = @('Sudo', 'PowerShell7', 'TerminalFonts')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Official Contour release MSI with the translated BlueTerm theme and graphics-compatibility gate.'
        }
        @{
            Name = 'WindowsTerminal'
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 28
            Default = $true
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Windows Terminal package and merge-preserving PowerShell Core default with shared Blue appearance.'
        }
        @{
            Name = 'WindowsFeatures'
            Stage = 'Extended'
            Runtime = 'Inbox'
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
            Stage = 'Extended'
            Runtime = 'Inbox'
            Order = 40
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'DeveloperBaseline Windows security controls.'
        }
        @{
            Name = 'ExploitProtection'
            FeatureSpec = 'specs/011-exploit-protection'
            Stage = 'Extended'
            Runtime = 'Inbox'
            Order = 41
            Default = $true
            DependsOn = @('Sudo')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Captured and recommended Windows Exploit Protection system mitigations.'
        }
        @{
            Name = 'LinuxHomebrew'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 47
            Default = $false
            DependsOn = @('LinuxHomebrew')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned pyinfra executor inside Debian WSL for local Linux deploy files.'
        }
        @{
            Name = 'NixOsWsl'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 48
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned NixOS-WSL distribution with a locked Helm, kubectl, Pulumi, OpenSSH, and integrity-checking system generation.'
        }
        @{
            Name = 'SharedSshConfig'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 48
            Default = $true
            DependsOn = @('NixOsWsl')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'One Windows OpenSSH client configuration linked only into trusted Debian while excluding DevOps NixOS, AI NixOS, and Debian-MW.'
        }
        @{
            Name = 'AiNixOsWsl'
            FeatureSpec = 'specs/010-ai-tools-isolation'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 48
            Default = $false
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in restricted NixOS-WSL environment for the OpenCode CLI and maintenance-owned nono sandbox.'
        }
        @{
            Name = 'RootlessPodman'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 49
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Dedicated Debian-MW WSL distro with local daemonless rootless Podman for untrusted parsers.'
        }
        @{
            Name = 'DeveloperDocker'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 55
            Default = $true
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Release-pinned Spec Kit EARS/TDD policy tool installed through uv.'
        }
        @{
            Name = 'AiTools'
            FeatureSpec = 'specs/010-ai-tools-isolation'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 51
            Default = $false
            DependsOn = @('Packages')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in native Windows AI clients, including OpenCode Desktop and CLI, through explicitly reviewed channels.'
        }
        @{
            Name = 'DeveloperEditor'
            FeatureSpec = 'specs/010-ai-tools-isolation'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 52
            Default = $true
            DependsOn = @('PowerShell7', 'TerminalFonts')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Stable VS Code, pinned Berg theme, developer extensions, and merge-preserved font settings.'
        }
        @{
            Name = 'OpenCodeExtensions'
            FeatureSpec = 'specs/010-ai-tools-isolation'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 53
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Pinned Cream Blue OpenCode themes with Cobalt selected and verified OpenUltraCode assets.'
        }
        @{
            Name = 'MalwareHashes'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 56
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Hash-pinned malware_hashes Windows executable from its GitHub release.'
        }
        @{
            Name = 'QuantResearchEnvironment'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 58
            Default = $false
            DependsOn = @('Packages', 'PowerShellProfile')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in signed Positron IDE, Quarto/Pandoc with private TinyTeX and quant Python, uv/OpenBB base, PyXLL, and independently locked overlays.'
        }
        @{
            Name = 'MalwareAnalysisTools'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 65
            Default = $false
            DependsOn = @('Packages', 'WindowsFeatures', 'ProfilingTools', 'MalwareHashes', 'JavaToolchain')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in, hash-pinned static-analysis and Sandbox telemetry tools.'
        }
        @{
            Name = 'SleuthKitCli'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 62
            Default = $false
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Official hash-pinned native Windows Sleuth Kit command suite on the user PATH.'
        }
        @{
            Name = 'Autopsy'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 63
            Default = $false
            DependsOn = @('Sudo', 'PowerShell7', 'PowerShellProfile', 'SleuthKitCli')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Official Autopsy Windows GUI MSI, matched TSK CLI, private tool bindings, case root, and Defender exclusions.'
        }
        @{
            Name = 'NativeForensicTools'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 64
            Default = $false
            DependsOn = @('PowerShell7', 'PowerShellProfile')
            SupportedModes = @('Test', 'Ensure')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in, version-pinned native Windows forensic verifier package installed without a local build.'
        }
        @{
            Name = 'MalwareContainerImage'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 66
            Default = $false
            DependsOn = @('RootlessPodman')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Opt-in, locally built rootless static parser image for documents, PDFs, and binaries.'
        }
        @{
            Name = 'LegacyDockerCleanup'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 67
            Default = $false
            DependsOn = @('RootlessPodman')
            SupportedModes = @('Test', 'Ensure')
            Privileged = $false
            Destructive = $true
            Description = 'Opt-in deletion of retained Debian-MW Docker user data after Podman migration.'
        }
        @{
            Name = 'ProfilingTools'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Core'
            Runtime = 'PowerShell7'
            Order = 80
            Default = $true
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'PowerShell 7 and Windows PowerShell profile components.'
        }
        @{
            Name = 'SafeChain'
            FeatureSpec = 'specs/013-default-workstation-utilities'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 81
            Default = $true
            DependsOn = @('PowerShellProfile')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Hash-pinned Safe-Chain protection for supported package managers on Windows and trusted Debian.'
        }
        @{
            Name = 'MsvcBuildTools'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 170
            Default = $false
            DependsOn = @('Sudo', 'PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Standalone MSVC x64/x86 tools, Windows SDK, and MSBuild without the Visual Studio IDE.'
        }
        @{
            Name = 'CMake'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 172
            Default = $false
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Native Windows CMake and Ninja with a compact default generator.'
        }
        @{
            Name = 'RustToolchain'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 174
            Default = $false
            DependsOn = @('MsvcBuildTools', 'PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Official rustup with stable x64 MSVC Rust and project override support.'
        }
        @{
            Name = 'JavaToolchain'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 176
            Default = $false
            DependsOn = @('PowerShell7')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Microsoft OpenJDK 21 LTS with JAVA_HOME and Java development commands.'
        }
        @{
            Name = 'NativeDevelopment'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 178
            Default = $true
            DependsOn = @('MsvcBuildTools', 'CMake', 'RustToolchain', 'JavaToolchain', 'PowerShellProfile')
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $true
            Destructive = $false
            Description = 'Aggregate native Windows C/C++, CMake, Rust, Java, and dual-shell environment gate.'
        }
        @{
            Name = 'FocusFollowsMouse'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
            Order = 90
            Default = $true
            DependsOn = @()
            SupportedModes = @('Test', 'Ensure', 'Reinitialize')
            Privileged = $false
            Destructive = $false
            Description = 'Current-user click-to-focus default with explicit hover-focus toggles.'
        }
        @{
            Name = 'DefenderExclusions'
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'PowerShell7'
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
            Stage = 'Extended'
            Runtime = 'Inbox'
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
