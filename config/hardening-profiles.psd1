@{
    SchemaVersion = 1
    DefaultProfile = 'DeveloperBaseline'
    Profiles = @{
        DeveloperBaseline = @{
            DisplayName = 'Windows 11 developer hardening baseline'
            RegistryValues = @(
                @{ Id = 'uac-enabled'; Category = 'UAC'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'EnableLUA'; Type = 'DWord'; Value = 1; RestartRequired = $true }
                @{ Id = 'uac-admin-consent'; Category = 'UAC'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'ConsentPromptBehaviorAdmin'; Type = 'DWord'; Value = 2 }
                @{ Id = 'uac-secure-desktop'; Category = 'UAC'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'PromptOnSecureDesktop'; Type = 'DWord'; Value = 1 }
                @{ Id = 'uac-filter-remote-local-admin'; Category = 'UAC'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'LocalAccountTokenFilterPolicy'; Type = 'DWord'; Value = 0 }

                @{ Id = 'disable-llmnr'; Category = 'Name resolution'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'EnableMulticast'; Type = 'DWord'; Value = 0 }
                @{ Id = 'disable-smart-name-resolution'; Category = 'Name resolution'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'; Name = 'DisableSmartNameResolution'; Type = 'DWord'; Value = 1 }
                @{ Id = 'ignore-netbios-name-release'; Category = 'Name resolution'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters'; Name = 'NoNameReleaseOnDemand'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-ipv4-source-routing'; Category = 'TCP/IP'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'; Name = 'DisableIPSourceRouting'; Type = 'DWord'; Value = 2; RestartRequired = $true }
                @{ Id = 'disable-ipv6-source-routing'; Category = 'TCP/IP'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'; Name = 'DisableIPSourceRouting'; Type = 'DWord'; Value = 2; RestartRequired = $true }
                @{ Id = 'disable-icmp-redirects'; Category = 'TCP/IP'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'; Name = 'EnableICMPRedirect'; Type = 'DWord'; Value = 0; RestartRequired = $true }

                @{ Id = 'disable-smb1-server'; Category = 'SMB'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'SMB1'; Type = 'DWord'; Value = 0; RestartRequired = $true }
                @{ Id = 'disable-smb1-client-driver'; Category = 'SMB'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10'; Name = 'Start'; Type = 'DWord'; Value = 4; RestartRequired = $true }
                @{ Id = 'restrict-null-sessions'; Category = 'SMB'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'; Name = 'RestrictNullSessAccess'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-smb-plaintext-passwords'; Category = 'SMB'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'; Name = 'EnablePlainTextPassword'; Type = 'DWord'; Value = 0 }
                @{ Id = 'disable-smb-insecure-guest'; Category = 'SMB'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation'; Name = 'AllowInsecureGuestAuth'; Type = 'DWord'; Value = 0 }

                @{ Id = 'restrict-anonymous-sam'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RestrictAnonymousSAM'; Type = 'DWord'; Value = 1 }
                @{ Id = 'restrict-anonymous'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RestrictAnonymous'; Type = 'DWord'; Value = 1 }
                @{ Id = 'exclude-anonymous-from-everyone'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'EveryoneIncludesAnonymous'; Type = 'DWord'; Value = 0 }
                @{ Id = 'restrict-remote-sam'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RestrictRemoteSAM'; Type = 'String'; Value = 'O:BAG:BAD:(A;;RC;;;BA)' }
                @{ Id = 'use-machine-identity'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'UseMachineId'; Type = 'DWord'; Value = 1 }
                @{ Id = 'limit-blank-passwords'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LimitBlankPasswordUse'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-null-session-fallback'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0'; Name = 'allownullsessionfallback'; Type = 'DWord'; Value = 0 }
                @{ Id = 'ntlmv2-only'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LmCompatibilityLevel'; Type = 'DWord'; Value = 5; RestartRequired = $true }
                @{ Id = 'disable-wdigest-password-caching'; Category = 'Credentials'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest'; Name = 'UseLogonCredential'; Type = 'DWord'; Value = 0; RestartRequired = $true }
                @{ Id = 'allow-protected-credentials'; Category = 'Credentials'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'; Name = 'AllowProtectedCreds'; Type = 'DWord'; Value = 1 }

                @{ Id = 'disable-remote-assistance'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'fAllowToGetHelp'; Type = 'DWord'; Value = 0 }
                @{ Id = 'require-rdp-rpc-encryption'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'fEncryptRPCTraffic'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-rdp-drive-redirection'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'; Name = 'fDisableCdm'; Type = 'DWord'; Value = 1 }
                @{ Id = 'require-rdp-nla'; Category = 'Remote access'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'; Name = 'UserAuthentication'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-winrm-unencrypted'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service'; Name = 'AllowUnencryptedTraffic'; Type = 'DWord'; Value = 0 }
                @{ Id = 'disable-winrm-digest'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client'; Name = 'AllowDigest'; Type = 'DWord'; Value = 0 }
                @{ Id = 'restrict-unauthenticated-rpc'; Category = 'Remote access'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Rpc'; Name = 'RestrictRemoteClients'; Type = 'DWord'; Value = 1; RestartRequired = $true }

                @{ Id = 'safe-dll-search'; Category = 'Execution'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'; Name = 'SafeDLLSearchMode'; Type = 'DWord'; Value = 1; RestartRequired = $true }
                @{ Id = 'keep-explorer-dep'; Category = 'Execution'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'NoDataExecutionPrevention'; Type = 'DWord'; Value = 0 }
                @{ Id = 'keep-heap-termination'; Category = 'Execution'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'NoHeapTerminationOnCorruption'; Type = 'DWord'; Value = 0 }
                @{ Id = 'disable-nonvolume-autoplay'; Category = 'Autorun'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'NoAutoplayfornonVolume'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-drive-autorun'; Category = 'Autorun'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoDriveTypeAutoRun'; Type = 'DWord'; Value = 255 }
                @{ Id = 'disable-autorun-commands'; Category = 'Autorun'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoAutorun'; Type = 'DWord'; Value = 1 }

                @{ Id = 'disable-printer-web-pnp'; Category = 'Printing'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'; Name = 'DisableWebPnPDownload'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-http-printing'; Category = 'Printing'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'; Name = 'DisableHTTPPrinting'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-oem-wifi-autoconnect'; Category = 'Wireless'; Path = 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config'; Name = 'AutoConnectAllowedOEM'; Type = 'DWord'; Value = 0 }
                @{ Id = 'minimize-simultaneous-connections'; Category = 'Wireless'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy'; Name = 'fMinimizeConnections'; Type = 'DWord'; Value = 1 }

                @{ Id = 'disable-lock-screen-camera'; Category = 'Lock screen'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name = 'NoLockScreenCamera'; Type = 'DWord'; Value = 1 }
                @{ Id = 'disable-voice-activation'; Category = 'Lock screen'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsActivateWithVoice'; Type = 'DWord'; Value = 2 }
                @{ Id = 'disable-voice-above-lock'; Category = 'Lock screen'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'; Name = 'LetAppsActivateWithVoiceAboveLock'; Type = 'DWord'; Value = 2 }
            )
            OptionalFeatures = @(
                @{ Id = 'disable-smb1-feature'; Category = 'Optional features'; FeatureName = 'SMB1Protocol'; DesiredState = 'Disabled'; AllowAbsent = $true }
                @{ Id = 'disable-powershell-v2-root'; Category = 'Optional features'; FeatureName = 'MicrosoftWindowsPowerShellV2Root'; DesiredState = 'Disabled'; AllowAbsent = $true }
                @{ Id = 'disable-powershell-v2-engine'; Category = 'Optional features'; FeatureName = 'MicrosoftWindowsPowerShellV2'; DesiredState = 'Disabled'; AllowAbsent = $true }
            )
            SmbClient = @{
                EnableSecuritySignature = $true
                RequireSecuritySignature = $true
                EnableInsecureGuestLogons = $false
            }
            SmbServer = @{
                EnableSMB1Protocol = $false
                RequireSecuritySignature = $true
                RejectUnencryptedAccess = $true
            }
            Netbios = @{
                Id = 'disable-netbios-on-ip-adapters'
                Category = 'Name resolution'
                DesiredOption = 2
            }
            ObservedRegistryValues = @(
                @{ Id = 'lsa-protected-process'; Category = 'Observed'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'RunAsPPL' }
                @{ Id = 'lsa-protection-audit'; Category = 'Observed'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe'; Name = 'AuditLevel' }
            )
        }
    }
}
