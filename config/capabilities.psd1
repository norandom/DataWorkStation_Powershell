@{
    SchemaVersion = 1
    Capabilities = @(
        @{
            Id = 'memory-pressure'
            Title = 'Memory pressure'
            Triggers = @('memory', 'ram', 'commit', 'leak', 'pool', 'oom', 'out of memory')
            EvidenceKinds = @('Snapshot', 'Native profile')
            InspectCommands = @('mem', 'memapps', 'memproc', 'memtop', 'wslmem', 'poolmon')
            CaptureCommand = 'profile-native-record {case} -Seconds 30'
        }
        @{
            Id = 'network-path'
            Title = 'DNS, IPv6, firewall, ports, and reachability'
            Triggers = @('network', 'dns', 'ipv6', 'firewall', 'port', 'connection', 'timeout', 'tcp', 'udp')
            EvidenceKinds = @('Packet capture')
            InspectCommands = @('ports', 'connections', 'pcap-protocols <capture>', 'pcap-ports <capture>', 'pcap-failures <capture>')
            CaptureCommand = 'pcap-debug-start {case}'
        }
        @{
            Id = 'crash-analysis'
            Title = 'Crash, hang, and silent process exit'
            Triggers = @('crash', 'segfault', 'fault', 'hang', 'freeze', 'exit', 'exception')
            EvidenceKinds = @('Event log', 'Crash dump')
            InspectCommands = @('crashes', 'problems', 'dump-analyze <dump>', 'dump-open <dump>')
            CaptureCommand = 'dump-on-crash -Name {case} -Executable <path>'
        }
        @{
            Id = 'native-performance'
            Title = 'Native and system-wide performance'
            Triggers = @('slow', 'cpu', 'latency', 'native', 'compiled', 'system-wide')
            EvidenceKinds = @('ETW trace')
            InspectCommands = @('profile-status', 'profile-native-open {case}')
            CaptureCommand = 'profile-native-record {case} -Seconds 30'
        }
        @{
            Id = 'python-performance'
            Title = 'Python sampled profiling'
            Triggers = @('python', 'py-spy', 'flamegraph')
            EvidenceKinds = @('Python profile')
            InspectCommands = @('profile-view <svg>')
            CaptureCommand = 'profile-python -ProcessId <pid> -Seconds 30 -Output python-{case}.svg'
        }
        @{
            Id = 'dotnet-performance'
            Title = '.NET EventPipe profiling'
            Triggers = @('.net', 'dotnet', 'c#', 'eventpipe', 'speedscope')
            EvidenceKinds = @('.NET profile')
            InspectCommands = @('profile-dotnet-ps', 'profile-view <speedscope.json>')
            CaptureCommand = 'profile-dotnet -ProcessId <pid> -Seconds 30 -OutputBase dotnet-{case}'
        }
        @{
            Id = 'event-history'
            Title = 'Windows event history'
            Triggers = @('event', 'service', 'login', 'logon', 'audit', 'problem', 'not working')
            EvidenceKinds = @('Event log')
            InspectCommands = @('problems', 'crashes', 'service-errors', 'loginfail')
            CaptureCommand = 'eventlog-start {case} -Executable <path>'
        }
        @{
            Id = 'security-state'
            Title = 'Firewall, Defender, SmartScreen, and SaveZone state'
            Triggers = @('defender', 'smartscreen', 'savezone', 'security', 'blocked')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @('firewall-status', 'defender-status', 'smartscreen-status', 'savezone-status')
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'workstation-help'
            Title = 'Managed command, alias, and skill discovery'
            Triggers = @('list aliases', 'list skills', 'commands', 'workstation help', 'wshelp')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'workstation-help'
                'workstation-help -Type Skills'
                'workstation-help -Json'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'workstation-modules'
            Title = 'Focused desired-state modules and dependency order'
            Triggers = @('module', 'run one module', 'dependency order', 'partial desired state', 'focused ensure', 'skip module')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                '.\Apply-Workstation.ps1 -Mode Test -Plan'
                '.\Apply-Workstation.ps1 -Mode Test -Module <name> -Plan'
            )
            CaptureCommand = 'tricky add {case} <module-plan.json>'
        }
        @{
            Id = 'linux-developer-packages'
            Title = 'Homebrew and Dagger inside Debian WSL'
            Triggers = @('homebrew', 'brew', 'dagger', 'release pipeline', 'developer package')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-LinuxHomebrewState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-LinuxAutomationState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-DeveloperToolsState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'terminal-fonts'
            Title = 'Managed terminal fonts'
            Triggers = @('terminal font', 'fira code', 'font dependency', 'terminal-fonts')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module TerminalFonts -Plan'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'contour-terminal'
            Title = 'Official Contour MSI and terminal desired state'
            Triggers = @('contour', 'contour msi', 'terminal theme', 'terminal font', 'blueterm', 'terminal package', 'scoop contour migration', 'opengl', 'glsl', 'display driver', 'terminal tabs', 'vertical line marks', 'clickable links', 'osc 8')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module ContourTerminal -Plan'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'windows-hardening'
            Title = 'Windows hardening baseline and residual attack surface'
            Triggers = @('hardening', 'uac', 'smb signing', 'netbios', 'llmnr', 'ntlm', 'autorun', 'attack surface')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Test'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'windows-debloat'
            Title = 'Opt-in Windows application and legacy-component removal'
            Triggers = @('debloat', 'bloatware', 'appx removal', 'remove windows apps', 'consumer apps', 'quick assist', 'phone link')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Plan'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-DebloatState.ps1 -Mode Test'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'windows-virtualization'
            Title = 'Hyper-V and Windows Sandbox optional-feature state'
            Triggers = @('hyper-v', 'hyperv', 'sandbox', 'virtualization', 'windows feature')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'powershell -NoProfile -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Plan'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-WindowsFeatureState.ps1 -Mode Test'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'desktop-focus'
            Title = 'Mouse-driven window focus without raising'
            Triggers = @('focus follows mouse', 'xmouse', 'active window tracking', 'raise window', 'hover focus')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-FocusFollowsMouseState.ps1 -Mode Test'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
    )
}
