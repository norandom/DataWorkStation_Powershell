# Current-user registration only. Windows owns the protected UserChoice keys.
function Get-MpvAssociationRegistryValues {
    param([hashtable] $Policy, [string] $Executable)

    $progId = [string] $Policy.ProgId
    $capabilities = 'HKCU:\' + $Policy.CapabilitiesPath
    @(
        @{ Path = "HKCU:\Software\Classes\$progId"; Name = ''; Value = 'mpv video' }
        @{ Path = "HKCU:\Software\Classes\$progId\DefaultIcon"; Name = ''; Value = '"' + $Executable + '",0' }
        @{ Path = "HKCU:\Software\Classes\$progId\shell\open\command"; Name = ''; Value = '"' + $Executable + '" -- "%1"' }
        @{ Path = $capabilities; Name = 'ApplicationName'; Value = $Policy.ApplicationName }
        @{ Path = $capabilities; Name = 'ApplicationDescription'; Value = 'Play video files with mpv' }
        @{ Path = 'HKCU:\Software\RegisteredApplications'; Name = $Policy.ApplicationName; Value = $Policy.CapabilitiesPath }
        foreach ($extension in $Policy.Extensions) {
            if ($extension -notmatch '^\.[a-z0-9]+$') { throw "Invalid video extension: $extension" }
            @{ Path = "$capabilities\FileAssociations"; Name = $extension; Value = $progId }
            @{ Path = "HKCU:\Software\Classes\$extension"; Name = ''; Value = $progId }
            @{ Path = "HKCU:\Software\Classes\$extension\OpenWithProgids"; Name = $progId; Value = '' }
        }
    )
}

function Get-MpvRegistryValue {
    param([string] $Path, [string] $Name)
    $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($key) {
        try { $key.GetValue($Name, $null) }
        finally { $key.Dispose() }
    }
}

function Initialize-MpvShellInterop {
    if ('DataWorkStation.MpvShell' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace DataWorkStation {
    public static class MpvShell {
        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern int AssocQueryStringW(uint flags, uint str, string assoc,
            string extra, StringBuilder output, ref uint length);
        [DllImport("shell32.dll")]
        public static extern void SHChangeNotify(uint change, uint flags, IntPtr item1, IntPtr item2);
        public static string Executable(string extension) {
            uint length = 0;
            AssocQueryStringW(0, 2, extension, "open", null, ref length);
            if (length == 0) return "";
            var output = new StringBuilder((int)length);
            return AssocQueryStringW(0, 2, extension, "open", output, ref length) == 0
                ? output.ToString() : "";
        }
    }
}
'@
}

function Get-MpvEffectiveExecutable {
    param([string] $Extension)
    Initialize-MpvShellInterop
    [DataWorkStation.MpvShell]::Executable($Extension)
}

function Get-MpvAssociationState {
    param([hashtable] $Policy, [string] $Executable)
    $drift = @(Get-MpvAssociationRegistryValues -Policy $Policy -Executable $Executable | Where-Object {
        (Get-MpvRegistryValue -Path $_.Path -Name $_.Name) -cne $_.Value
    })
    $extensions = @(foreach ($extension in $Policy.Extensions) {
        $effective = Get-MpvEffectiveExecutable -Extension $extension
        [pscustomobject]@{
            Extension = $extension
            EffectiveExecutable = $effective
            IsMpv = [bool] $Executable -and $effective -ieq $Executable
        }
    })
    [pscustomobject]@{
        RegistrationCompliant = $drift.Count -eq 0
        DefaultsCompliant = @($extensions | Where-Object { -not $_.IsMpv }).Count -eq 0
        Extensions = $extensions
        SettingsUri = 'ms-settings:defaultapps?registeredAppUser=' + [uri]::EscapeDataString($Policy.ApplicationName)
    }
}

function Set-MpvAssociations {
    param([hashtable] $Policy, [string] $Executable, [string] $BackupDirectory)
    $changes = @(Get-MpvAssociationRegistryValues -Policy $Policy -Executable $Executable | Where-Object {
        (Get-MpvRegistryValue -Path $_.Path -Name $_.Name) -cne $_.Value
    })
    if ($changes.Count -eq 0) { return }
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    @($changes | ForEach-Object {
        [pscustomobject]@{ Path = $_.Path; Name = $_.Name; PreviousValue = Get-MpvRegistryValue -Path $_.Path -Name $_.Name }
    }) | Export-Clixml -LiteralPath (Join-Path $BackupDirectory "associations-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')).xml")
    foreach ($entry in $changes) {
        if (-not (Test-Path -LiteralPath $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
        if ($entry.Name -eq '') {
            Set-Item -LiteralPath $entry.Path -Value $entry.Value
        } else {
            New-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -Value $entry.Value -PropertyType String -Force | Out-Null
        }
    }
    Initialize-MpvShellInterop
    [DataWorkStation.MpvShell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}
