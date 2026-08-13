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
            InspectCommands = @('crashes', 'problems', 'dump-open <dump>')
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
    )
}
