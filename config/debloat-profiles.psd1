@{
    SchemaVersion = 1
    DefaultProfile = 'DeveloperMinimal'
    Profiles = @{
        DeveloperMinimal = @{
            DisplayName = 'Windows 11 developer minimal-app profile'
            AppxPackages = @(
                @{ Id = 'remove-bing-weather'; NamePattern = 'Microsoft.BingWeather'; Reason = 'Consumer weather application' }
                @{ Id = 'remove-get-help'; NamePattern = 'Microsoft.GetHelp'; Reason = 'Consumer support application' }
                @{ Id = 'remove-get-started'; NamePattern = 'Microsoft.Getstarted'; Reason = 'First-run tips application' }
                @{ Id = 'remove-messaging'; NamePattern = 'Microsoft.Messaging'; Reason = 'Retired consumer messaging application' }
                @{ Id = 'remove-3d-viewer'; NamePattern = 'Microsoft.Microsoft3DViewer'; Reason = 'Legacy 3D viewer' }
                @{ Id = 'remove-office-hub'; NamePattern = 'Microsoft.MicrosoftOfficeHub'; Reason = 'Office promotion hub' }
                @{ Id = 'remove-solitaire'; NamePattern = 'Microsoft.MicrosoftSolitaireCollection'; Reason = 'Consumer game' }
                @{ Id = 'remove-mixed-reality-portal'; NamePattern = 'Microsoft.MixedReality.Portal'; Reason = 'Mixed Reality consumer portal' }
                @{ Id = 'remove-one-connect'; NamePattern = 'Microsoft.OneConnect'; Reason = 'Legacy mobile connectivity application' }
                @{ Id = 'remove-print-3d'; NamePattern = 'Microsoft.Print3D'; Reason = 'Legacy 3D printing application' }
                @{ Id = 'remove-skype'; NamePattern = 'Microsoft.SkypeApp'; Reason = 'Retired inbox Skype application' }
                @{ Id = 'remove-wallet'; NamePattern = 'Microsoft.Wallet'; Reason = 'Retired Wallet application' }
                @{ Id = 'remove-feedback-hub'; NamePattern = 'Microsoft.WindowsFeedbackHub'; Reason = 'Windows Feedback Hub' }
                @{ Id = 'remove-windows-maps'; NamePattern = 'Microsoft.WindowsMaps'; Reason = 'Offline Maps application' }
                @{ Id = 'remove-xbox-tcui'; NamePattern = 'Microsoft.Xbox.TCUI'; Reason = 'Xbox sign-in interface' }
                @{ Id = 'remove-xbox-app'; NamePattern = 'Microsoft.XboxApp'; Reason = 'Legacy Xbox application' }
                @{ Id = 'remove-xbox-game-overlay'; NamePattern = 'Microsoft.XboxGameOverlay'; Reason = 'Xbox game overlay' }
                @{ Id = 'remove-xbox-gaming-overlay'; NamePattern = 'Microsoft.XboxGamingOverlay'; Reason = 'Xbox gaming overlay' }
                @{ Id = 'remove-xbox-identity'; NamePattern = 'Microsoft.XboxIdentityProvider'; Reason = 'Xbox identity provider' }
                @{ Id = 'remove-xbox-speech'; NamePattern = 'Microsoft.XboxSpeechToTextOverlay'; Reason = 'Xbox speech overlay' }
                @{ Id = 'remove-phone-link'; NamePattern = 'Microsoft.YourPhone'; Reason = 'Phone Link and cross-device integration' }
                @{ Id = 'remove-old-feedback'; NamePattern = 'Microsoft.WindowsFeedback'; Reason = 'Retired Windows Feedback application' }
                @{ Id = 'remove-contact-support'; NamePattern = 'Windows.ContactSupport'; Reason = 'Retired contact-support application' }
                @{ Id = 'remove-bing-news'; NamePattern = 'Microsoft.BingNews'; Reason = 'Consumer news application' }
                @{ Id = 'remove-office-sway'; NamePattern = 'Microsoft.Office.Sway'; Reason = 'Office Sway application' }
                @{ Id = 'remove-quick-assist'; NamePattern = 'MicrosoftCorporationII.QuickAssist'; Reason = 'Remote assistance application' }
                @{ Id = 'remove-pandora-promotion'; NamePattern = 'PandoraMedia.*'; Reason = 'Third-party promotional package' }
                @{ Id = 'remove-duolingo-promotion'; NamePattern = 'Duolingo*'; Reason = 'Third-party promotional package' }
                @{ Id = 'remove-actipro-promotion'; NamePattern = 'ActiproSoftware*'; Reason = 'Third-party promotional package' }
                @{ Id = 'remove-eclipse-manager-promotion'; NamePattern = 'EclipseManager*'; Reason = 'Third-party promotional package' }
                @{ Id = 'remove-spotify-promotion'; NamePattern = 'SpotifyAB.SpotifyMusic'; Reason = 'Third-party promotional package' }
                @{ Id = 'remove-king-games'; NamePattern = 'king.com.*'; Reason = 'Third-party promotional games' }
            )
            Capabilities = @(
                @{ Id = 'remove-steps-recorder'; NamePattern = 'App.StepsRecorder*'; Reason = 'Deprecated Steps Recorder' }
                @{ Id = 'remove-internet-explorer'; NamePattern = 'Browser.InternetExplorer*'; Reason = 'Legacy Internet Explorer compatibility capability' }
                @{ Id = 'remove-math-recognizer'; NamePattern = 'MathRecognizer*'; Reason = 'Optional handwriting math recognizer' }
                @{ Id = 'remove-powershell-ise'; NamePattern = 'Microsoft.Windows.PowerShell.ISE*'; Reason = 'Legacy Windows PowerShell editor' }
            )
            OptionalFeatures = @(
                @{ Id = 'disable-tftp'; FeatureName = 'TFTP'; Reason = 'Legacy unauthenticated file-transfer client' }
                @{ Id = 'disable-telnet'; FeatureName = 'TelnetClient'; Reason = 'Legacy plaintext remote terminal client' }
                @{ Id = 'disable-xps-printing'; FeatureName = 'Printing-XPSServices-Features'; Reason = 'Legacy XPS printing support' }
                @{ Id = 'disable-work-folders'; FeatureName = 'WorkFolders-Client'; Reason = 'Enterprise Work Folders synchronization client' }
            )
            ProtectedAppxPatterns = @(
                'Microsoft.DesktopAppInstaller'
                'Microsoft.WindowsStore'
                'Microsoft.StorePurchaseApp'
                'Microsoft.SecHealthUI'
                'Microsoft.NET.Native.*'
                'Microsoft.VCLibs.*'
                'Microsoft.UI.Xaml.*'
                'Microsoft.WindowsAppRuntime*'
                'Microsoft.WebMediaExtensions'
                'Microsoft.WebpImageExtension'
                'Microsoft.AV1VideoExtension'
                'Microsoft.AVCEncoderVideoExtension'
                'Microsoft.HEIFImageExtension'
                'Microsoft.HEVCVideoExtension'
                'Microsoft.MPEG2VideoExtension'
                'Microsoft.RawImageExtension'
                'Microsoft.VP9VideoExtensions'
                'Microsoft.WindowsTerminal'
                'MicrosoftCorporationII.WindowsSubsystemForLinux'
                'TheDebianProject.DebianGNULinux'
                'OpenAI.Codex'
            )
        }
    }
}
