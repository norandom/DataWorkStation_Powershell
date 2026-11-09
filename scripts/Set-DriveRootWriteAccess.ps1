[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Test', 'Ensure', 'Restore')][string] $Mode = 'Test',
    [string] $BackupPath
)
$ErrorActionPreference = 'Stop'
function Set-RootDacl {
    param([string] $Path, [Security.AccessControl.DirectorySecurity] $Acl)
    if (-not ('DeveloperStorage.RootSecurity' -as [type])) {
        Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
namespace DeveloperStorage {
    public static class RootSecurity {
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SetFileSecurityW(string path, uint information, byte[] descriptor);
    }
}
'@
    }
    # SetFileSecurityW deliberately does not propagate to children. Set-Acl /
    # SetNamedSecurityInfo can traverse the whole drive, which is unwanted here.
    if (-not [DeveloperStorage.RootSecurity]::SetFileSecurityW($Path, 4, $Acl.GetSecurityDescriptorBinaryForm())) {
        throw [ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}
$roots = @('C:\', 'D:\')
$broadSids = @('S-1-1-0', 'S-1-5-11', 'S-1-5-32-545')
$writeMask = [Security.AccessControl.FileSystemRights]::CreateFiles -bor [Security.AccessControl.FileSystemRights]::CreateDirectories -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor [Security.AccessControl.FileSystemRights]::WriteAttributes -bor [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes
$changes = foreach ($root in $roots) {
    $acl = Get-Acl -LiteralPath $root
    foreach ($rule in $acl.Access) {
        $sid = $rule.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
        if ($sid -in $broadSids -and $rule.AccessControlType -eq 'Allow' -and
            -not $rule.IsInherited -and $rule.InheritanceFlags -eq 'None' -and
            $rule.PropagationFlags -eq 'None' -and ($rule.FileSystemRights -band $writeMask)) {
            [pscustomobject]@{ Root = $root; Identity = $sid; Rights = [string] $rule.FileSystemRights; Rule = $rule }
        }
    }
}
if ($Mode -eq 'Test') {
    if ($changes) { $changes | Select-Object Root, Identity, Rights } else { Write-Host 'Drive roots are protected from broad unelevated write grants.' }
    return
}
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run Ensure/Restore through Windows sudo.' }
if ($Mode -eq 'Restore') {
    if (-not $BackupPath) { throw 'Restore requires the exact -BackupPath.' }
    $backup = @(Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json)
    if ($backup.Count -ne 2 -or @($backup.Root | Sort-Object -Unique).Count -ne 2 -or @($backup | Where-Object Root -notin $roots).Count) { throw 'Backup must contain exactly C:\ and D:\.' }
    foreach ($item in $backup) {
        if ($PSCmdlet.ShouldProcess($item.Root, 'Restore saved root DACL')) {
            $acl = Get-Acl -LiteralPath $item.Root
            $acl.SetSecurityDescriptorSddlForm($item.Dacl, [Security.AccessControl.AccessControlSections]::Access)
            Set-RootDacl -Path $item.Root -Acl $acl
        }
    }
    return
}
if (-not $changes) { Write-Host 'No root-only write grants need changing.'; return }
if (-not $BackupPath) { $BackupPath = Join-Path $env:DEVELOPER_STORAGE_ROOT ('acl-backups\drive-roots-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')) }
if (-not $PSCmdlet.ShouldProcess(($roots -join ', '), "Save DACLs to $BackupPath and remove broad root-only write grants; preserve inheritable rules")) { return }
if (Test-Path -LiteralPath $BackupPath) { throw 'Refusing to overwrite an ACL backup.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $BackupPath) -Force | Out-Null
$backup = foreach ($root in $roots) { [pscustomobject]@{ Root = $root; Dacl = (Get-Acl -LiteralPath $root).GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::Access) } }
$backup | ConvertTo-Json | Set-Content -LiteralPath $BackupPath -Encoding UTF8
foreach ($root in $roots) {
    $acl = Get-Acl -LiteralPath $root
    foreach ($change in @($changes | Where-Object Root -eq $root)) { $acl.RemoveAccessRuleSpecific($change.Rule) }
    Set-RootDacl -Path $root -Acl $acl
}
Write-Host "Drive roots protected. ACL backup: $BackupPath"
