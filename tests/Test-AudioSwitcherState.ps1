[CmdletBinding()]
param()

function Test-AudioSwitcherState {
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
        if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Content -LiteralPath $path -Raw }
    }

    $package = Get-RequiredText '.config/audio-switcher.winget'
    $configuration = Get-RequiredText 'config/audio-switcher.psd1'
    $state = Get-RequiredText 'scripts/Set-AudioSwitcherState.ps1'
    $orchestrator = Get-RequiredText 'Apply-Workstation.ps1'
    $aliases = Get-RequiredText 'profile/Aliases.ps1'
    $docs = Get-RequiredText 'docs/Aliases.md'

    Assert-True ($package -match 'id:\s*FortyOneLtd\.AudioSwitcher') 'the official Audio Switcher WinGet package is declared'
    Assert-True ($package -match 'useLatest:\s*true') 'Audio Switcher follows ordinary WinGet updates'
    Assert-True ($configuration -match "Command\s*=\s*'audioswitcher\.exe'" -and $configuration -match 'https://audioswit\.ch/er') 'the command and official homepage are declared'
    Assert-True ($state -match 'if \(\$Mode -ne ''Test''\)' -and $state -match 'winget\.exe configure') 'Audio Switcher installation remains explicit outside Test'
    Assert-True ($state -match 'Get-Command \$configuration\.Command -CommandType Application' -and $state -match 'Microsoft\\WinGet\\Packages' -and $state -match 'ConvertTo-Json') 'Audio Switcher state checks the command and portable package layout and supports machine output'
    Assert-True ($orchestrator -match "'AudioSwitcher'" -and $orchestrator -match 'Set-AudioSwitcherState\.ps1') 'Audio Switcher is selectable through the workstation orchestrator'
    Assert-True ($aliases -match 'function global:audio-switcher' -and $aliases -match 'audioswitcher') 'the Audio Switcher launcher is exposed in the managed profile'
    Assert-True ($docs -match '`audio-switcher\s+\[ARG\.\.\.\]`' -and $docs -match 'Audio Switcher') 'the Audio Switcher launcher is documented'

    $catalog = Import-PowerShellDataFile (Join-Path $repositoryRoot 'config/workstation-modules.psd1')
    $module = @($catalog.Modules | Where-Object Name -eq 'AudioSwitcher')
    Assert-True ($module.Count -eq 1 -and $module[0].Default -and -not $module[0].Privileged) 'Audio Switcher is a non-privileged default module'
    Assert-True (@($module[0].DependsOn).Count -eq 0) 'Audio Switcher does not add an unrelated profile deployment dependency'

    $capabilities = Get-RequiredText 'config/capabilities.psd1'
    Assert-True ($capabilities -match 'Set-AudioSwitcherState\.ps1' -and $capabilities -match 'AudioSwitcher -Plan') 'human Audio Switcher inspection commands are routed'

    Write-Host "Audio Switcher state tests passed ($script:assertions assertions)."
}

Test-AudioSwitcherState
