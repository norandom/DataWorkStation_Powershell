@{
    SchemaVersion = 1
    Capabilities = @(
        @{
            Id = 'powershell-environment'
            Title = 'Staged PowerShell bootstrap, dual-runtime profile, and Windows Terminal'
            Triggers = @('powershell 5.1', 'powershell core', 'pwsh', 'bootstrap stage', 'dependency stage', 'windows terminal', 'default terminal', 'terminal profile')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan'
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-WorkstationBaseline.ps1 -Section BootstrapStages'
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-WorkstationBaseline.ps1 -Section PowerShellRuntimes'
                'pwsh -NoProfile -File .\scripts\Set-PowerShellProfile.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-WindowsTerminalState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module WindowsTerminal -Plan'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module PowerShellProfile'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module WindowsTerminal'
            )
            CaptureCommand = 'tricky add {case} <powershell-environment-state.json>'
        }
        @{
            Id = 'powershell-testing'
            Title = 'PowerShell test discovery, parallel execution, and compatibility'
            Triggers = @('pester', 'powershell test', 'parallel tests', 'test framework', 'windows powershell compatibility')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'test-powershell'
                'test-powershell -Json'
                'test-powershell -Compatibility'
                'pwsh -NoProfile -File .\scripts\Invoke-PowerShellTests.ps1 -Json'
                'pwsh -NoProfile -File .\scripts\Set-PesterState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module PowerShellTesting -Plan'
            )
            CaptureCommand = 'tricky add {case} <test-result.json>'
        }
        @{
            Id = 'repository-quality'
            Title = 'Repository linters and non-mutating pre-commit checks'
            Triggers = @('lint', 'pre-commit', 'dockerfile', 'hadolint', 'actionlint', 'yaml', 'json', 'toml', 'merge marker', 'private key')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'lint-powershell [path ...]'
                'lint-python [path ...]'
                'lint-repository [-Category <All|Docker|Actions>] [path ...]'
                'lint-docker [Dockerfile ...]'
                'lint-actions [.github/workflows/*.yml]'
                'precommit-run'
                'pre-commit run <hook-id> --all-files'
            )
            StateCommands = @('precommit-install')
            CaptureCommand = 'tricky add {case} <repository-lint-output.txt>'
        }
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
            Id = 'malware-triage'
            Title = 'Suspicious file triage and isolated analysis'
            Triggers = @('malware', 'suspicious file', 'pdf dissection', 'document dissection', 'disassembly', 'decompile', 'detonate', 'sandbox diff', 'clean sandbox', 'control case', 'behavior diff', 'binary diff', 'patch diff', 'BinExport', 'BinDiff')
            EvidenceKinds = @('Snapshot', 'Sandbox report', 'Canonical evidence', 'Unified diff', 'Disassembly', 'Decompilation', 'Graph export', 'Semantic match database', 'Query sidecar', 'File-handle trace', 'Packet capture', 'Event log', 'ETW trace')
            InspectCommands = @(
                'is-this-malware <path>'
                'malware_hashes <path> [--json]'
                'host-static <path>'
                'sandbox-static <path> -Mode Dissect'
                'wsl-dev [command] (developer tools only; never suspicious content)'
                'wsl-mw [command] (dedicated malware-analysis WSL)'
                'malware-container-status'
                'malware-container-image -Mode Test'
                'malware-container <path>'
                'malware-container-control <path>'
                'wsl-mw podman info --format json'
                'disass <path>'
                'decomp <path>'
                'malware-sandbox <path> -Mode Dissect'
                'malware-control <path> -Mode <Dissect|Disassemble|Decompile|Detonate>'
                'malware-diff -ControlCase <control-case> -TargetCase <target-case> [-ShowDiff]'
                'sandbox-behavior-control <path> [-DurationSeconds <seconds>]'
                'sandbox-behavior-target <path> [-DurationSeconds <seconds>]'
                'sandbox-behavior-diff -ControlCase <control-case> -TargetCase <target-case> [-ShowDiff]'
                'binary-diff -Baseline <old-binary> -Candidate <new-binary>'
                'binary-diff-report -Case <case>'
                'pwsh -NoProfile -File .\scripts\Read-MalwareEvidence.ps1 -Case <case>'
                'pwsh -NoProfile -File .\scripts\Invoke-MalwareAnalysis.ps1 -Action Report -Case <case>'
            )
            ValidationCommands = @(
                'pwsh -NoProfile -File .\scripts\Test-MalwareSandboxIntegration.ps1 -ConfirmSandbox -ConfirmExecution'
                'pwsh -NoProfile -File .\scripts\Test-MalwareSandboxIntegration.ps1 -Case <existing-case>'
                'pwsh -NoProfile -File .\tests\Test-MalwareAnalysis.ps1 -Section Differential'
            )
            StateCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-MalwareHashesState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-MalwareHashesState.ps1 -Mode Ensure'
                'pwsh -NoProfile -File .\scripts\Set-MalwareAnalysisToolsState.ps1 -Mode Test -Tool Handle'
                'pwsh -NoProfile -File .\scripts\Set-MalwareAnalysisToolsState.ps1 -Mode Ensure -Tool Handle'
                'pwsh -NoProfile -File .\scripts\Set-MalwareContainerImageState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-RootlessPodmanState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module MalwareContainerImage -Plan'
                'sandbox-behavior-control <path> -Run -ConfirmSandbox'
                'sandbox-behavior-target <path> -Run -ConfirmSandbox -ConfirmExecution'
                'binary-diff -Baseline <old-binary> -Candidate <new-binary> -Run -ConfirmContainer'
            )
            CaptureCommand = 'malware-sandbox <path> -Mode Detonate -Run -ConfirmSandbox -ConfirmExecution'
        }
        @{
            Id = 'autopsy-forensic-analysis'
            Title = 'Autopsy Windows GUI and native Sleuth Kit analysis'
            Triggers = @('autopsy', 'sleuth kit', 'mmls', 'fls', 'icat', 'fsstat', 'recent activity', 'regripper', 'forensic gui')
            EvidenceKinds = @('Disk image', 'Autopsy case', 'Registry hive', 'TSK command output')
            InspectCommands = @(
                '.\Apply-Workstation.ps1 -Mode Test -Module Autopsy -Plan'
                '.\Apply-Workstation.ps1 -Mode Test -Module Autopsy'
                'autopsy-defender-status'
                'mmls -V'
                'autopsy-regripper -h'
            )
            ValidationCommands = @(
                'pwsh -NoProfile -File .\tests\Test-AutopsyState.ps1 -Section All'
                'pwsh -NoProfile -File .\scripts\Set-SleuthKitState.ps1 -Mode Test'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module Autopsy'
                'autopsy-defender-off'
                'autopsy-defender-on'
            )
            CaptureCommand = 'tricky add {case} <exported-autopsy-or-tsk-report>'
        }
        @{
            Id = 'forensic-evidence-verification'
            Title = 'Read-only native Windows EWF verification'
            Triggers = @('ewf', 'e01', 'forensic image', 'evidence verification', 'ewfverify', 'segment integrity', 'forensic package')
            EvidenceKinds = @('EWF image', 'Verification report', 'Raw native output', 'Provenance snapshot')
            InspectCommands = @(
                'ewf-verify <path.E01> -ReportDirectory <separate-report-root> -Plan'
                'ewf-verify <path.E01> -ReportDirectory <separate-report-root>'
                'ewf-verify <path.E01> -ReportDirectory <separate-report-root> -Json'
                'pwsh -NoProfile -File .\scripts\Set-NativeForensicToolsState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module NativeForensicTools -Plan'
            )
            ValidationCommands = @(
                'pwsh -NoProfile -File .\tests\Test-NativeForensicVerification.ps1 -Section All'
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-NativeForensicVerification.ps1 -Section All'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module NativeForensicTools'
            )
            CaptureCommand = 'tricky add {case} <ewf-report-directory>'
        }
        @{
            Id = 'workstation-help'
            Title = 'Managed command, alias, and skill discovery'
            Triggers = @('list aliases', 'list skills', 'commands', 'workstation help', 'wshelp', 'wget', 'aria2c', 'download alias')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'workstation-help'
                'workstation-help -Type Skills'
                'workstation-help -Json'
                'Get-Command wget, aria2c'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'idle-sleep-inhibition'
            Title = 'Explicit Caffeine idle-sleep inhibition'
            Triggers = @('caffeine', 'stay awake', 'inhibit standby', 'prevent sleep', 'idle sleep')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-CaffeineState.ps1 -Mode Test'
                'Get-Process caffeine -ErrorAction Ignore'
            )
            CaptureCommand = 'caffeine'
        }
        @{
            Id = 'workstation-modules'
            Title = 'Focused desired-state modules and dependency order'
            Triggers = @('module', 'run one module', 'dependency order', 'partial desired state', 'focused ensure', 'skip module', 'update workstation', 'upgrade packages', 'windows update', 'update wsl', 'update homebrew', 'update docker')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                '.\Apply-Workstation.ps1 -Mode Test -Plan'
                '.\Apply-Workstation.ps1 -Mode Test -Module <name> -Plan'
                'update'
                'update -Json'
            )
            StateCommands = @('update -Run', 'update -Target <name> -Run')
            CaptureCommand = 'tricky add {case} <module-plan.json>'
        }
        @{
            Id = 'linux-developer-packages'
            Title = 'Trusted Debian and NixOS WSL developer environments'
            Triggers = @('homebrew', 'brew', 'dagger', 'release pipeline', 'developer package', 'nixos', 'nix', 'helm', 'kubectl', 'pulumi', 'shared ssh config', 'wsl ssh')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-LinuxHomebrewState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-LinuxAutomationState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-DeveloperDockerState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-RootlessPodmanState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-DeveloperToolsState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-NixOsWslState.ps1 -Mode Plan'
                'pwsh -NoProfile -File .\scripts\Set-NixOsWslState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-SharedSshConfigState.ps1 -Mode Test'
                'nixos-check'
                'nixos-check -Json'
                'wsl-nix helm version'
                'wsl-nix kubectl version --client'
                'wsl-nix pulumi version'
                '.\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module NixOsWsl'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module SharedSshConfig'
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'go-development'
            Title = 'Go package, workspace, and toolchain selection'
            Triggers = @('go', 'golang', 'go.mod', 'GOPATH', 'GOBIN', 'GOROOT', 'GOTOOLCHAIN', 'go toolchain')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'go version'
                'go env GOPATH GOBIN GOTOOLCHAIN GOROOT GOENV'
                'pwsh -NoProfile -File .\scripts\Set-GoState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module Go -Plan'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module Go'
            )
            CaptureCommand = 'tricky add {case} <go-state.json>'
        }
        @{
            Id = 'ai-tools-isolation'
            FeatureSpec = 'specs/010-ai-tools-isolation'
            Modules = @('AiTools', 'AiNixOsWsl', 'DeveloperEditor')
            Title = 'AI tools, developer editor, and restricted WSL trust boundaries'
            Triggers = @('opencode', 'claude code', 'antigravity cli', 'cline', 'copilot cli', 'vscode', 'berg theme', 'ai sandbox', 'nono', 'wsl isolation', 'devops keys', 'malware case staging')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Plan'
                'pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test -Json'
                'pwsh -NoProfile -File .\scripts\Set-DeveloperEditorState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Set-AiNixOsWslState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1'
                'pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1 -Json'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module DeveloperEditor'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module AiTools,AiNixOsWsl'
                'pwsh -NoProfile -File .\scripts\Invoke-OpenCodeSandbox.ps1 -Project <path>'
                'pwsh -NoProfile -File .\scripts\Import-MalwareCase.ps1 -Source <path> -CaseId <id>'
                'pwsh -NoProfile -File .\scripts\Export-MalwareCase.ps1 -CaseId <id> -Destination <path>'
            )
            CaptureCommand = 'tricky add {case} <ai-tools-or-wsl-boundary-status.json>'
        }
        @{
            Id = 'native-development'
            Title = 'Native Windows C/C++, CMake, Rust, and Java development'
            Triggers = @('msvc', 'cl.exe', 'msbuild', 'cmake', 'ninja', 'rust', 'rustup', 'java', 'javac', 'jdk', 'JAVA_HOME', 'native development')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                '.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan'
                'pwsh -NoProfile -File .\scripts\Set-NativeDevelopmentState.ps1 -Mode Test'
                'Get-Command cl.exe,link.exe,msbuild.exe,cmake.exe,ninja.exe,rustc.exe,cargo.exe,java.exe,javac.exe'
                'Get-ChildItem Env:CC,Env:CXX,Env:CMAKE_GENERATOR,Env:CARGO_HOME,Env:RUSTUP_HOME,Env:JAVA_HOME'
            )
            ValidationCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-NativeDevelopmentState.ps1 -Mode Smoke'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module MsvcBuildTools'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module CMake'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module RustToolchain'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module JavaToolchain'
                '.\Apply-Workstation.ps1 -Mode Ensure -Module NativeDevelopment'
            )
            CaptureCommand = 'tricky add {case} <native-development-state.json>'
        }
        @{
            Id = 'spec-driven-development'
            Title = 'EARS requirements and test traceability with Spec Kit'
            Triggers = @('spec kit', 'speckit', 'ears', 'requirements', 'traceability', 'spec-driven development', 'tdd')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test'
                'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test'
                'pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1'
                'pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1 -Json'
                '.\Apply-Workstation.ps1 -Mode Test -Module SpecDrivenDevelopment -Plan'
                'ears-sdd status --phase final'
                'ears-sdd status --phase final --json'
            )
            CaptureCommand = 'tricky add {case} <ears-sdd-status.json>'
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
            Id = 'native-text-tools'
            Title = 'Native awk and sed for PowerShell'
            Triggers = @('awk', 'sed', 'native text tools', 'busybox', 'git bash', 'mingit', 'msys', 'msys2', 'cygwin')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'pwsh -NoProfile -File .\scripts\Set-NativeTextToolsState.ps1 -Mode Test'
                '.\Apply-Workstation.ps1 -Mode Test -Module NativeTextTools -Plan'
                "'alpha beta' | awk '{print `$2}'"
                "'abc' | sed 's/b/B/'"
            )
            CaptureCommand = 'tricky add {case} <exported-state.json>'
        }
        @{
            Id = 'contour-terminal'
            Title = 'Official Contour MSI and terminal desired state'
            Triggers = @('contour', 'contour msi', 'terminal theme', 'terminal font', 'blueterm', 'terminal package', 'scoop contour migration', 'opengl', 'glsl', 'display driver', 'terminal tabs', 'tab switching', 'terminal scrollback', 'terminal keybindings', 'psreadline', 'copy on select', 'clipboard', 'status line', 'statusline', 'byobu', 'vertical line marks', 'clickable links', 'osc 8')
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
            Id = 'windows-exploit-protection'
            FeatureSpec = 'specs/011-exploit-protection'
            Modules = @('ExploitProtection')
            Title = 'Windows process and memory exploit mitigations'
            Triggers = @('exploit protection', 'aslr', 'dep', 'sehop', 'cfg', 'control flow guard', 'shadow stack', 'process mitigation')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Plan'
                'powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Plan -Json'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Test'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Test -Profile CapturedDefault'
            )
            ValidationCommands = @(
                'powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-ExploitProtectionState.ps1 -Section All'
                'pwsh -NoProfile -File .\tests\Test-ExploitProtectionState.ps1 -Section All'
            )
            StateCommands = @(
                '.\Apply-Workstation.ps1 -Mode Ensure -Module ExploitProtection'
                'sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Ensure -Profile CapturedDefault'
            )
            CaptureCommand = 'tricky add {case} <exported-exploit-protection-state.json>'
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
        @{
            Id = 'quant-research-environment'
            Title = 'Independent uv/OpenBB quantitative research overlays'
            Triggers = @('quant research', 'openbb', 'pyxll', 'excel plots', 'jupyter', 'notebook', 'uv overlay', 'thesis environment', 'source relocation plan')
            EvidenceKinds = @('Snapshot')
            InspectCommands = @(
                'quant-status'
                'quant-status -Json'
                'pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project All'
                'pwsh -NoProfile -File .\scripts\Set-QuantResearchEnvironmentState.ps1 -Mode Test -Project Base'
                'source-relocation-plan -Target D:\Source'
                'source-relocation-plan -Target D:\Source -Json'
            )
            StateCommands = @(
                'quant-sync -Project thesis'
                'quant-sync -Project Base -ConfirmPyXllInstall'
                'quant-rebuild -Project thesis'
                'quant-overlay -Name <name> -Dependency <package> -Run'
                'quant-notebook -Project thesis'
            )
            CaptureCommand = 'tricky add {case} <quant-research-status.json>'
        }
    )
}
