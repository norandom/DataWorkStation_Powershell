[CmdletBinding()]
param(
    [ValidateSet('All', 'CatalogContract', 'ModuleContract', 'InstallerContract', 'DefenderContract', 'CommandSurface', 'DocumentationContract')]
    [string] $Section = 'All'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$script:assertions = 0

function Assert-True {
    param([bool] $Condition, [string] $Message)
    $script:assertions++
    if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Get-Source {
    param([string] $RelativePath)
    $path = Join-Path $repositoryRoot $RelativePath
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
    if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Content -LiteralPath $path -Raw }
}

function Test-CatalogContract {
    $autopsy = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\autopsy.psd1')
    $tsk = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\sleuthkit.psd1')
    Assert-True ($autopsy.Package.Version -eq '4.23.1') 'Autopsy stable release is pinned'
    Assert-True ($autopsy.SleuthKitVersion -eq '4.15.0') 'Autopsy declares its matching TSK version'
    Assert-True ($tsk.Package.Version -eq $autopsy.SleuthKitVersion) 'standalone TSK matches Autopsy'
    foreach ($record in @($autopsy.Package, $tsk.Package)) {
        Assert-True ($record.Size -is [long] -or $record.Size -is [int]) 'release size is pinned'
        Assert-True ($record.Sha256 -match '^[A-F0-9]{64}$') 'release SHA-256 is pinned'
        Assert-True ($record.SignatureSha256 -match '^[A-F0-9]{64}$') 'detached signature SHA-256 is pinned'
        Assert-True ($record.SigningKeyFingerprint -eq '0917A7EE58A9308B13D3963338AD602EC7454C8B') 'official signing fingerprint is recorded'
    }
    Assert-True ($autopsy.Package.AuthenticodeThumbprint -match '^[A-F0-9]{40}$') 'MSI Authenticode leaf identity is pinned'
    Assert-True (@($tsk.Commands).Count -ge 20) 'complete TSK CLI inventory is declared'
    Assert-True ($tsk.Package.InstalledFileCount -eq 92) 'installed TSK tree file count is pinned'
    Assert-True ($tsk.Package.InstalledTreeSha256 -match '^[A-F0-9]{64}$') 'installed TSK tree SHA-256 is pinned'
    Assert-True (@($autopsy.PrivateCommands | Where-Object Name -eq 'autopsy-regripper').Count -eq 1) 'Recent Activity RegRipper binding is declared'
    Assert-True (@($autopsy.ManagedFiles).Count -eq 11) 'reviewed Autopsy executable inventory is declared'
    foreach ($file in @($autopsy.ManagedFiles)) {
        Assert-True ($file.Size -is [long] -or $file.Size -is [int]) "installed size is pinned for $($file.RelativePath)"
        Assert-True ($file.Sha256 -match '^[A-F0-9]{64}$') "installed SHA-256 is pinned for $($file.RelativePath)"
    }
}

function Test-ModuleContract {
    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config\workstation-modules.psd1')
    $tsk = @($catalog.Modules | Where-Object Name -eq 'SleuthKitCli')
    $autopsy = @($catalog.Modules | Where-Object Name -eq 'Autopsy')
    Assert-True ($tsk.Count -eq 1 -and -not $tsk[0].Default) 'SleuthKit CLI is an optional focused module'
    Assert-True ($autopsy.Count -eq 1 -and -not $autopsy[0].Default) 'Autopsy is an optional focused module'
    Assert-True ($autopsy[0].DependsOn -contains 'SleuthKitCli') 'complete Autopsy setup pulls in matching TSK CLI'
    Assert-True ($autopsy[0].DependsOn -contains 'Sudo') 'Autopsy declares MSI and Defender privilege dependency'
    Assert-True ($autopsy[0].DependsOn -contains 'PowerShellProfile') 'Autopsy declares command binding dependency'
    Assert-True ($autopsy[0].Privileged -and -not $autopsy[0].Destructive) 'Autopsy is privileged but non-destructive'
    $apply = Get-Source 'Apply-Workstation.ps1'
    Assert-True ($apply -match "'SleuthKitCli'" -and $apply -match 'Set-SleuthKitState\.ps1') 'orchestrator routes Sleuth Kit CLI'
    Assert-True ($apply -match "'Autopsy'" -and $apply -match 'Set-AutopsyState\.ps1') 'orchestrator routes Autopsy'
    Assert-True ($apply -match 'sudo\.exe --inline pwsh\.exe[^\r\n]+\$autopsyScript') 'Autopsy uses the working sudo command boundary rather than a Store executable path'
}

function Test-InstallerContract {
    $source = Get-Source 'scripts/Set-AutopsyState.ps1'
    Assert-True ($source -match 'Get-FileHash.+SHA256') 'Autopsy verifies MSI SHA-256'
    Assert-True ($source -match 'Get-AuthenticodeSignature') 'Autopsy verifies Authenticode'
    Assert-True ($source -match '/qn' -and $source -match '/norestart') 'Autopsy MSI is noninteractive and never restarts Windows'
    Assert-True ($source -match 'PrivateCommandsMissing') 'Autopsy verifies every reviewed private CLI binding'
    Assert-True ($source -match 'ManagedFileDrift' -and $source -match "'Repair'") 'Autopsy verifies installed tool identities and repairs same-version drift'
    Assert-True ($source.IndexOf("Administrator rights are required") -lt $source.IndexOf("if (`$Mode -eq 'Test')")) 'Autopsy state is elevated so Defender exclusions can be read accurately'
    $tsk = Get-Source 'scripts/Set-SleuthKitState.ps1'
    Assert-True ($tsk -match 'Get-FileHash.+SHA256') 'TSK verifies release archive SHA-256'
    Assert-True ($tsk -match 'Get-InstalledTreeIdentity' -and $tsk -match 'InstalledTreeSha256') 'TSK verifies the deterministic installed tree identity'
    Assert-True ($tsk -match 'mmls\.exe' -and $tsk -match '-V') 'TSK has a functional version gate'
    Assert-True ($tsk -match "SetEnvironmentVariable\('Path'.+'User'\)") 'TSK command directory is persisted on the user PATH'
}

function Test-DefenderContract {
    $source = Get-Source 'scripts/Set-AutopsyState.ps1'
    Assert-True ($source -match 'Add-MpPreference -ExclusionPath') 'case output has a durable folder exclusion'
    Assert-True ($source -match 'Add-MpPreference -ExclusionProcess') 'Autopsy has a process exclusion'
    Assert-True ($source -match 'Get-Service WinDefend') 'state verifies Defender remains installed'
    Assert-True ($source -notmatch 'Stop-Service|Set-Service|sc\.exe|Remove-WindowsCapability|Disable-WindowsOptionalFeature') 'Autopsy never removes or stops Defender'
    $defender = Get-Source 'scripts/Set-DefenderState.ps1'
    Assert-True ($defender.IndexOf("if (`$Mode -eq 'Status')") -lt $defender.IndexOf("Administrator rights are required")) 'Defender status is observational and non-elevated'
    Assert-True ($defender -match 'DefenderProcessRunning' -and $defender -match 'DefenderServiceStatus') 'Defender reports protection and process/service state separately'
}

function Test-CommandSurface {
    $profileSource = Get-Source 'profile/ForensicTools.ps1'
    foreach ($command in @('autopsy', 'autopsy-regripper', 'autopsy-ewfexport', 'autopsy-tesseract', 'autopsy-yara', 'autopsy-photorec', 'autopsy-testdisk', 'autopsy-gst-inspect', 'autopsy-log2timeline', 'autopsy-tsk-logical-imager', 'autopsy-defender-off', 'autopsy-defender-on', 'autopsy-defender-status')) {
        Assert-True ($profileSource -match "function global:$([regex]::Escape($command))") "$command is a human-readable command"
    }
    Assert-True ($profileSource -match 'Import-PowerShellDataFile') 'private bindings resolve from the versioned catalog'
}

function Test-DocumentationContract {
    $docs = Get-Source 'docs/autopsy.md'
    Assert-True ($docs -match 'Windows GUI' -and $docs -match 'not\s+the legacy web') 'docs identify the requested Autopsy product'
    Assert-True ($docs -match 'case/output' -and $docs -match 'Defender') 'docs explain the anti-malware boundary'
    Assert-True ($docs -match 'NativeForensicTools' -and $docs -match 'does not replace') 'docs preserve the lightweight verifier choice'
    Assert-True ($docs -match 'Recent Activity' -and $docs -match 'RegRipper') 'docs distinguish the ingest module from its CLI component'
    $capabilities = Get-Source 'config/capabilities.psd1'
    Assert-True ($capabilities -match 'autopsy-forensic-analysis') 'capability routing includes Autopsy'
}

$sections = if ($Section -eq 'All') {
    @('CatalogContract', 'ModuleContract', 'InstallerContract', 'DefenderContract', 'CommandSurface', 'DocumentationContract')
} else { @($Section) }

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "Autopsy contract tests passed ($script:assertions assertions)."
