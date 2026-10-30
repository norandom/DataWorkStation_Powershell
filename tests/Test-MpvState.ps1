[CmdletBinding()]
param()

function Test-MpvState {
    $ErrorActionPreference = 'Stop'
    $repositoryRoot = Split-Path -Parent $PSScriptRoot
    $script:assertions = 0

    function Assert-True {
        param([bool] $Condition, [string] $Message)
        $script:assertions++
        if (-not $Condition) { throw "Assertion failed: $Message" }
    }

    function Get-RequiredText {
        param([string] $RelativePath)
        $path = Join-Path $repositoryRoot $RelativePath
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$RelativePath exists"
        if (Test-Path -LiteralPath $path -PathType Leaf) { (Get-Content -LiteralPath $path -Raw) -replace "`r`n", "`n" }
    }

    $package = Get-RequiredText '.config/mpv.winget'
    $configuration = Get-RequiredText 'config/mpv.psd1'
    $managedConfig = Get-RequiredText 'config/mpv.conf'
    $state = Get-RequiredText 'scripts/Set-MpvState.ps1'
    $orchestrator = Get-RequiredText 'Apply-Workstation.ps1'
    $docs = Get-RequiredText 'docs/media-playback.md'

    Assert-True ($package -match 'id:\s*mpv-player\.mpv-CI\.MSVC') 'the official mpv CI/MSVC WinGet package is declared'
    Assert-True ($package -match 'useLatest:\s*true') 'mpv follows ordinary WinGet updates'
    Assert-True ($managedConfig -match '(?m)^vo=gpu-next$') 'the recommended gpu-next renderer is selected'
    Assert-True ($managedConfig -match '(?m)^gpu-api=d3d11$' -and $managedConfig -match '(?m)^gpu-context=d3d11$') 'the Windows Direct3D 11 rendering path is selected'
    Assert-True ($managedConfig -match '(?m)^hwdec=auto-safe$') 'safe automatic hardware decoding is enabled with software fallback'
    Assert-True ($configuration -match 'BEGIN DATAWORKSTATION MPV GPU' -and $configuration -match 'END DATAWORKSTATION MPV GPU' -and $state -match 'Get-DesiredMpvConfiguration') 'the state command preserves settings outside a bounded managed block'
    Assert-True ($configuration -match "RequiredHardwareDecoder\s*=\s*'d3d11va'" -and $state -match '--hwdec=help') 'the state command verifies that the mpv build exposes D3D11VA'
    Assert-True ($configuration -match "CommandPath\s*=\s*'%USERPROFILE%\\\.local\\bin\\mpv\.cmd'" -and $state -match 'Get-DesiredMpvCommand') 'the portable package is exposed through the managed user command directory'
    Assert-True ($orchestrator -match "'Mpv'" -and $orchestrator -match 'Set-MpvState\.ps1') 'Mpv is selectable through the workstation orchestrator'

    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/workstation-modules.psd1')
    $module = @($catalog.Modules | Where-Object Name -eq 'Mpv')
    Assert-True ($module.Count -eq 1 -and $module[0].Default -and -not $module[0].Privileged) 'Mpv is a non-privileged default module'
    Assert-True ($module[0].FeatureSpec -eq 'specs/013-default-workstation-utilities') 'Mpv declares its feature governance owner'

    $capabilities = Get-RequiredText 'config/capabilities.psd1'
    Assert-True ($capabilities -match 'Set-MpvState\.ps1' -and $capabilities -match 'Apply-Workstation\.ps1 -Mode Test -Module Mpv') 'human mpv inspection commands are routed'
    Assert-True ($docs -match 'Radeon 890M' -and $docs -match 'ffmpeg') 'documentation explains the detected AMD GPU and the FFmpeg boundary'

    . (Join-Path $repositoryRoot 'scripts/MpvAssociations.ps1')
    $policy = (Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/mpv.psd1')).VideoAssociations
    $executable = 'C:\Program Files\mpv\mpv.exe'
    $entries = @(Get-MpvAssociationRegistryValues -Policy $policy -Executable $executable)
    $openCommand = @($entries | Where-Object Path -Like '*\shell\open\command')[0]
    Assert-True ($openCommand.Value -ceq '"C:\Program Files\mpv\mpv.exe" -- "%1"') 'Explorer paths with spaces remain quoted and option-like filenames remain operands'
    Assert-True ('.mp4' -in $policy.Extensions -and '.avi' -in $policy.Extensions -and '.mkv' -in $policy.Extensions) 'common video containers are declared'
    Assert-True ('.mp3' -notin $policy.Extensions -and '.jpg' -notin $policy.Extensions -and '.ts' -notin $policy.Extensions) 'audio, images and TypeScript are excluded'
    Assert-True (@($entries | Where-Object Path -NotLike 'HKCU:\*').Count -eq 0) 'registration stays in the current user hive'
    Assert-True (@($entries | Where-Object Path -Like '*UserChoice*').Count -eq 0) 'protected Windows choices are never written'

    # Synthetic registry and shell resolution: no workstation changes in this test.
    $registry = @{}
    foreach ($entry in $entries) { $registry[$entry.Path + '|' + $entry.Name] = $entry.Value }
    $resolved = @{}
    foreach ($extension in $policy.Extensions) { $resolved[$extension] = $executable }
    function Get-MpvRegistryValue {
        param([string] $Path, [string] $Name)
        $registry[$Path + '|' + $Name]
    }
    function Get-MpvEffectiveExecutable {
        param([string] $Extension)
        $resolved[$Extension]
    }
    $report = Get-MpvAssociationState -Policy $policy -Executable $executable
    Assert-True ($report.RegistrationCompliant -and $report.DefaultsCompliant) 'matching registrations and shell resolution converge'
    $resolved['.mp4'] = 'C:\Other Player\player.exe'
    $report = Get-MpvAssociationState -Policy $policy -Executable $executable
    Assert-True ($report.RegistrationCompliant -and -not $report.DefaultsCompliant) 'an overriding default is drift even when registration matches'
    Assert-True (@($report.Extensions | Where-Object { -not $_.IsMpv }).Extension -eq '.mp4') 'the pending extension is identified'
    $registry.Remove($openCommand.Path + '|' + $openCommand.Name)
    $report = Get-MpvAssociationState -Policy $policy -Executable $executable
    Assert-True (-not $report.RegistrationCompliant) 'a missing launch command is registration drift'
    $resolved['.mp4'] = ''
    $report = Get-MpvAssociationState -Policy $policy -Executable $executable
    Assert-True (-not $report.DefaultsCompliant) 'unresolved shell defaults cannot count as mpv'

    Write-Host "mpv state tests passed ($script:assertions assertions)."
}

Test-MpvState
