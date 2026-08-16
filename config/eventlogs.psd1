@{
    RetentionDays     = 14
    ExportWindowHours = 48
    ArchiveRoot       = 'E:\Logs'
    MaxArchiveMiB     = 768
    MinimumFreeMiB    = 128

    Channels = @(
        @{ Name = 'Application'; MaxSizeMiB = 128; Enable = $false }
        @{ Name = 'System'; MaxSizeMiB = 128; Enable = $false }
        @{ Name = 'Security'; MaxSizeMiB = 256; Enable = $false }
        @{ Name = 'Windows PowerShell'; MaxSizeMiB = 128; Enable = $false }
        @{ Name = 'Microsoft-Windows-PowerShell/Operational'; MaxSizeMiB = 256; Enable = $true }
        @{ Name = 'Microsoft-Windows-WMI-Activity/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-TaskScheduler/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'OpenSSH/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-Windows Defender/Operational'; MaxSizeMiB = 128; Enable = $true }
        @{ Name = 'Microsoft-Windows-Windows Firewall With Advanced Security/Firewall'; MaxSizeMiB = 128; Enable = $true }
        @{ Name = 'Microsoft-Windows-CodeIntegrity/Operational'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-AppLocker/EXE and DLL'; MaxSizeMiB = 64; Enable = $true }
        @{ Name = 'Microsoft-Windows-AppLocker/MSI and Script'; MaxSizeMiB = 64; Enable = $true }
    )

    # Apply the minimum balanced audit set and preserve any additional categories.
    AuditSubcategories = @(
        @{ Guid = '{0CCE9210-69AE-11D9-BED3-505054503030}'; Name = 'Security State Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9211-69AE-11D9-BED3-505054503030}'; Name = 'Security System Extension'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9212-69AE-11D9-BED3-505054503030}'; Name = 'System Integrity'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9214-69AE-11D9-BED3-505054503030}'; Name = 'Other System Events'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9215-69AE-11D9-BED3-505054503030}'; Name = 'Logon'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9216-69AE-11D9-BED3-505054503030}'; Name = 'Logoff'; Success = $true; Failure = $false }
        @{ Guid = '{0CCE9217-69AE-11D9-BED3-505054503030}'; Name = 'Account Lockout'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE921B-69AE-11D9-BED3-505054503030}'; Name = 'Special Logon'; Success = $true; Failure = $false }
        @{ Guid = '{0CCE921C-69AE-11D9-BED3-505054503030}'; Name = 'Other Logon/Logoff Events'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9249-69AE-11D9-BED3-505054503030}'; Name = 'Group Membership'; Success = $true; Failure = $false }
        @{ Guid = '{0CCE9245-69AE-11D9-BED3-505054503030}'; Name = 'Removable Storage'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE922B-69AE-11D9-BED3-505054503030}'; Name = 'Process Creation'; Success = $true; Failure = $false }
        @{ Guid = '{0CCE922F-69AE-11D9-BED3-505054503030}'; Name = 'Audit Policy Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9230-69AE-11D9-BED3-505054503030}'; Name = 'Authentication Policy Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9231-69AE-11D9-BED3-505054503030}'; Name = 'Authorization Policy Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9232-69AE-11D9-BED3-505054503030}'; Name = 'Firewall Rule Policy Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9233-69AE-11D9-BED3-505054503030}'; Name = 'Filtering Platform Policy Change'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9235-69AE-11D9-BED3-505054503030}'; Name = 'User Account Management'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE9237-69AE-11D9-BED3-505054503030}'; Name = 'Security Group Management'; Success = $true; Failure = $true }
        @{ Guid = '{0CCE923F-69AE-11D9-BED3-505054503030}'; Name = 'Credential Validation'; Success = $true; Failure = $true }
    )
}
