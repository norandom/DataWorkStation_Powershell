[CmdletBinding()]
param(
    [ValidateSet('All', 'CommandSurface', 'PlanContract', 'OutputContract', 'TargetContract', 'SafetyContract', 'DependencyContract', 'WindowsContract', 'WinGetContract', 'ScoopContract', 'WslContract', 'LinuxContract', 'HomebrewContract', 'ContainerContract', 'ReconciliationContract', 'PrivilegeContract', 'ExecutionContract', 'DualShellContract')]
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
    if (Test-Path -LiteralPath $path -PathType Leaf) { Get-Content -LiteralPath $path -Raw } else { '' }
}

function Get-UpdateConfiguration {
    $path = Join-Path $repositoryRoot 'config\workstation-update.psd1'
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'update configuration exists'
    if (Test-Path -LiteralPath $path -PathType Leaf) { Import-PowerShellDataFile -LiteralPath $path }
}

function Invoke-Plan {
    param([string[]] $Target = @('All'), [string] $Runtime)
    if (-not $Runtime) { $Runtime = if ($PSVersionTable.PSEdition -eq 'Desktop') { Join-Path $PSHOME 'powershell.exe' } else { (Get-Command pwsh.exe).Source } }
    $scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-WorkstationUpdate.ps1'
    $arguments = @('-NoLogo', '-NoProfile', '-File', $scriptPath, '-Target') + $Target + @('-Json')
    $output = @(& $Runtime @arguments 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) "plan exits zero: $($output -join ' ')"
    if ($LASTEXITCODE -ne 0) { return $null }
    try { $output -join "`n" | ConvertFrom-Json -ErrorAction Stop } catch { throw "Plan JSON is invalid: $($output -join ' ')" }
}

function Invoke-SyntheticRun {
    param(
        [string[]] $Target = @('All'),
        [string] $FailStage,
        [string] $RestartStage
    )
    $null = $FailStage # captured by the nested synthetic runner
    $null = $RestartStage # captured by the nested synthetic runner
    $requests = [Collections.Generic.List[object]]::new()
    $runner = {
        param($Request)
        [void] $requests.Add($Request)
        $failed = $FailStage -and $Request.Stage -eq $FailStage
        $restart = $RestartStage -and $Request.Stage -eq $RestartStage
        $output = @()
        if ($Request.Stage -eq 'Windows' -and -not $failed) {
            $status = if ($restart) { 'restart-required' } else { 'succeeded' }
            $output = @([pscustomobject]@{ Status = $status; RebootRequired = [bool] $restart; Detail = 'synthetic Windows result' } | ConvertTo-Json -Compress)
        } elseif (@($Request.ArgumentList) -contains '--pinned') {
            $output = @('dagger')
        }
        [pscustomobject]@{ ExitCode = if ($failed) { 23 } else { 0 }; Output = $output; Succeeded = -not $failed; RestartRequired = [bool] $restart }
    }.GetNewClosure()
    $scriptPath = Join-Path $repositoryRoot 'scripts\Invoke-WorkstationUpdate.ps1'
    $output = @(& $scriptPath -Target $Target -Run -Json -CommandRunner $runner 2>&1)
    $json = $output -join "`n"
    [pscustomobject]@{ Result = $json | ConvertFrom-Json -ErrorAction Stop; Requests = @($requests) }
}

function Test-CommandSurface {
    $scriptSource = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    $aliases = Get-Source 'profile/Aliases.ps1'
    $capabilities = Get-Source 'config/capabilities.psd1'
    $docs = Get-Source 'docs/Aliases.md'
    Assert-True ($scriptSource -match "ValidateSet\('All'.*'PowerShellEnvironment'\)") 'direct command declares bounded targets'
    Assert-True ($aliases -match 'function global:update') 'managed profile exposes update'
    Assert-True ($aliases -match 'Invoke-WorkstationUpdate\.ps1') 'profile wrapper uses the human script'
    Assert-True ($capabilities -match 'update -Run') 'capability routing exposes explicit update execution'
    Assert-True ($docs -match 'update -Run') 'operator docs expose explicit update execution'
}

function Test-PlanContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match '\[switch\]\s*\$Run') 'execution requires a Run switch'
    $plan = Invoke-Plan
    if (-not $plan) { return }
    Assert-True ($plan.Action -eq 'Plan') 'default action is Plan'
    Assert-True (@($plan.Stages).Count -eq 8) 'complete plan contains eight stages'
    Assert-True (@($plan.Stages | Where-Object Status -ne 'planned').Count -eq 0) 'all default stages are planned'
    Assert-True (@($plan.Stages | Where-Object ChangesState -ne $true).Count -eq 0) 'plan identifies every mutating stage'
}

function Test-OutputContract {
    $plan = Invoke-Plan
    if (-not $plan) { return }
    Assert-True ($plan.SchemaVersion -eq 1) 'JSON schema is version 1'
    Assert-True ($plan.ReleaseVersion -match '^\d+\.\d+\.\d+$') 'current release version is reported'
    Assert-True ($null -ne $plan.RestartRequired) 'aggregate restart field exists'
    Assert-True ($null -ne $plan.Succeeded) 'aggregate success field exists'
    Assert-True ($null -ne $plan.NewShellRecommended) 'new-shell field exists'
    foreach ($stage in @($plan.Stages)) {
        foreach ($property in @('Name', 'Order', 'DependsOn', 'Privilege', 'ChangesState', 'RestartMayBeRequired', 'Status', 'Detail')) {
            Assert-True ($stage.PSObject.Properties.Name -contains $property) "$($stage.Name) reports $property"
        }
    }
}

function Test-TargetContract {
    $configuration = Get-UpdateConfiguration
    if (-not $configuration) { return }
    $expected = @('Windows', 'WinGet', 'Scoop', 'Wsl', 'Linux', 'Homebrew', 'Containers', 'PowerShellEnvironment')
    Assert-True ($configuration.SchemaVersion -eq 1) 'catalog schema is version 1'
    Assert-True (@($configuration.Targets).Count -eq $expected.Count) 'catalog contains eight executable targets'
    foreach ($name in $expected) {
        Assert-True (@($configuration.Targets | Where-Object Name -eq $name).Count -eq 1) "$name exists once"
        $plan = Invoke-Plan -Target @($name)
        Assert-True (@($plan.Stages | Where-Object Name -eq $name).Count -eq 1) "$name focused plan contains target"
    }
}

function Test-DependencyContract {
    $configuration = Get-UpdateConfiguration
    if (-not $configuration) { return }
    $names = @($configuration.Targets.Name)
    $orders = @($configuration.Targets.Order)
    Assert-True (@($names | Sort-Object -Unique).Count -eq $names.Count) 'target names are unique'
    Assert-True (@($orders | Sort-Object -Unique).Count -eq $orders.Count) 'target orders are unique'
    foreach ($target in @($configuration.Targets)) {
        foreach ($dependency in @($target.DependsOn)) {
            $dependencyTarget = @($configuration.Targets | Where-Object Name -eq $dependency)
            Assert-True ($dependencyTarget.Count -eq 1) "$($target.Name) dependency $dependency exists once"
            if ($dependencyTarget.Count -eq 1) { Assert-True ($dependencyTarget[0].Order -lt $target.Order) "$dependency precedes $($target.Name)" }
        }
    }
    $homebrew = Invoke-Plan -Target @('Homebrew')
    Assert-True ((@($homebrew.Stages.Name) -join ',') -eq 'WinGet,Wsl,Linux,Homebrew') 'Homebrew plan includes ordered hard prerequisites'
}

function Test-SafetyContract {
    $configuration = Get-UpdateConfiguration
    if (-not $configuration) { return }
    $expected = @('Restart-Computer', 'shutdown.exe', 'wsl.exe --shutdown', 'docker system prune', 'podman system prune', 'scoop cleanup', '--include-pinned', '--include-unknown', '--uninstall-previous')
    foreach ($operation in $expected) { Assert-True ($configuration.ProhibitedOperations -contains $operation) "$operation is explicitly prohibited" }
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -notmatch 'Remove-LegacyDockerMwState') 'update never invokes destructive legacy cleanup'
    Assert-True ($source -notmatch "-Module\s+Debloat|ConfirmRemoval|ConfirmDestructive") 'update never selects destructive modules'
}

function Test-WindowsContract {
    $source = Get-Source 'scripts/Invoke-WindowsUpdate.ps1'
    Assert-True ($source -match "IsInstalled=0 and Type='Software' and IsHidden=0") 'WUA search is software-only'
    Assert-True ($source -match 'EulaAccepted') 'only accepted updates enter installation'
    Assert-True ($source -match 'RebootRequired') 'restart requirement is reported'
    Assert-True ($source -match 'Microsoft\.Update\.Session') 'supported WUA session is used'
    Assert-True ($source -notmatch "Type='Driver'") 'driver updates are not selected'
    Assert-True ($source -notmatch 'Restart-Computer|shutdown\.exe') 'Windows update never reboots'
}

function Test-WinGetContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match "'upgrade', '--all'") 'WinGet upgrades all ordinary applications'
    Assert-True ($source -match '--accept-source-agreements') 'WinGet accepts source agreements explicitly'
    Assert-True ($source -match '--accept-package-agreements') 'WinGet accepts package agreements explicitly'
    Assert-True ($source -match '--disable-interactivity') 'WinGet disables prompts'
    $configuration = Get-UpdateConfiguration
    Assert-True ($configuration.AcceptedExitCodes.WinGet -contains -1978335189) 'official no-applicable-update code is normalized'
    Assert-True ($source -notmatch "'--include-pinned'|'--include-unknown'|'--uninstall-previous'") 'WinGet does not override pins, unknown versions, or uninstall behavior'
}

function Test-ScoopContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match 'Set-ScoopState\.ps1') 'declared Scoop state is checked first'
    Assert-True ($source -match "@\('update'\)") 'Scoop core and buckets are updated'
    Assert-True ($source -match "@\('update', '\*'\)") 'all installed Scoop apps are updated'
    Assert-True ($source -notmatch "@\('cleanup'") 'Scoop cleanup is absent'
}

function Test-WslContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match "@\('--update'\)") 'supported WSL update command is used'
    Assert-True ($source -notmatch "@\('--shutdown'\)") 'WSL shutdown is absent'
}

function Test-LinuxContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match 'WSL_DISTRIBUTION') 'developer distribution comes from declared environment'
    Assert-True ($source -match 'WSL_MALWARE_DISTRIBUTION') 'malware distribution comes from declared environment'
    Assert-True ($source -match 'apt-get update') 'APT metadata is refreshed'
    Assert-True ($source -match 'dist-upgrade -y') 'APT distribution packages are upgraded noninteractively'
    Assert-True ($source -match "'--user', 'root'") 'APT runs through explicit WSL root'
    Assert-True ($source -notmatch '--list.*--quiet') 'installed WSL distributions are not discovered'
}

function Test-HomebrewContract {
    $configuration = Get-UpdateConfiguration
    if (-not $configuration) { return }
    Assert-True (@($configuration.HomebrewInstances).Count -eq 1) 'only one Homebrew instance is declared'
    Assert-True ($configuration.HomebrewInstances[0].Role -eq 'Developer') 'Homebrew belongs to developer Debian'
    Assert-True ($configuration.HomebrewInstances[0].PinnedFormulae -contains 'dagger') 'release-owned Dagger formula is pinned'
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match '''pin'', \$formula') 'declared release formulae are pinned before upgrade'
    Assert-True ($source -match '\$brew, ''update''') 'Homebrew metadata is updated'
    Assert-True ($source -match '\$brew, ''upgrade''') 'ordinary Homebrew formulae are upgraded'
}

function Test-ContainerContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match 'Set-DeveloperDockerState\.ps1') 'developer Docker uses existing resource'
    Assert-True ($source -match 'Set-RootlessPodmanState\.ps1') 'malware Podman uses existing resource'
    Assert-True ($source -match '\$developerDocker, ''-Mode'', ''Ensure''') 'developer Docker is reconciled explicitly'
    Assert-True ($source -match '\$rootlessPodman, ''-Mode'', ''Ensure''') 'rootless Podman is reconciled explicitly'
}

function Test-ReconciliationContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match 'Get-Content -LiteralPath \(Join-Path \$repositoryRoot ''VERSION''\)') 'current release VERSION is read'
    Assert-True ($source -match '\$applyWorkstation, ''-Mode'', ''Ensure''') 'default desired state is ensured'
    Assert-True ($source -match '\$applyWorkstation, ''-Mode'', ''Test''') 'remaining drift is tested'
    Assert-True ($source -notmatch "Apply-Workstation.*-Module") 'reconciliation uses the default non-destructive selection'
    $synthetic = Invoke-SyntheticRun -Target @('PowerShellEnvironment')
    Assert-True ($synthetic.Result.ReleaseVersion -eq (Get-Content -Raw (Join-Path $repositoryRoot 'VERSION')).Trim()) 'synthetic run uses current release version'
    Assert-True ($synthetic.Result.NewShellRecommended) 'successful reconciliation recommends a new shell'
    $reconciliationRequests = @($synthetic.Requests | Where-Object Stage -eq 'PowerShellEnvironment')
    Assert-True ($reconciliationRequests.Count -eq 5) 'reconciliation runs Ensure, Test, and three restricted-boundary checks'
    Assert-True ((@($reconciliationRequests[0].ArgumentList) -join ' ') -match '-Mode Ensure') 'reconciliation ensures first'
    Assert-True ((@($reconciliationRequests[1].ArgumentList) -join ' ') -match '-Mode Test') 'reconciliation tests remaining drift second'
    $boundaryRequests = @($reconciliationRequests | Select-Object -Skip 2)
    Assert-True (@($boundaryRequests | Where-Object { $_.Privilege -ne 'Observational' }).Count -eq 0) 'post-update boundary checks are observational'
    foreach ($role in @('TrustedUtility', 'MalwareAnalysis', 'DevOps')) {
        Assert-True (@($boundaryRequests | Where-Object { (@($_.ArgumentList) -join ' ') -match "-Role $role" }).Count -eq 1) "$role is revalidated once"
    }
}

function Test-PrivilegeContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match 'sudo\.exe') 'Windows administrator boundary uses managed sudo'
    Assert-True ($source -match "'--user', 'root'") 'Linux administrator boundary names root explicitly'
    $configuration = Get-UpdateConfiguration
    if ($configuration) {
        Assert-True (@($configuration.Targets | Where-Object Privilege -eq 'WindowsAdministrator').Count -eq 1) 'Windows privilege stage is declared once'
        Assert-True (@($configuration.Targets | Where-Object Privilege -eq 'WslRoot').Count -ge 1) 'WSL root stages are declared'
    }
}

function Test-ExecutionContract {
    $source = Get-Source 'scripts/Invoke-WorkstationUpdate.ps1'
    Assert-True ($source -match '\[scriptblock\]\s*\$CommandRunner') 'synthetic executor seam is explicit'
    Assert-True ($source -match "'succeeded'.*'skipped'.*'failed'.*'restart-required'") 'terminal execution states are bounded'
    Assert-True ($source -match 'BlockedBy') 'blocked dependencies are reported'
    Assert-True ($source -match 'if \(-not \$Run\)') 'plan returns before execution'
    $success = Invoke-SyntheticRun
    Assert-True ($success.Result.Succeeded) 'synthetic all-stage execution succeeds'
    Assert-True (@($success.Result.Stages | Where-Object Status -ne 'succeeded').Count -eq 0) 'all synthetic success stages terminate succeeded'
    Assert-True (@($success.Requests).Count -gt @($success.Result.Stages).Count) 'compound stages emit individual reviewed commands'
    $restart = Invoke-SyntheticRun -Target @('Windows') -RestartStage 'Windows'
    Assert-True ($restart.Result.RestartRequired) 'synthetic Windows restart is aggregated'
    Assert-True ($restart.Result.Stages[0].Status -eq 'restart-required') 'restart-required is a successful terminal state'
    $failure = Invoke-SyntheticRun -Target @('Homebrew') -FailStage 'Linux'
    Assert-True (-not $failure.Result.Succeeded) 'synthetic prerequisite failure fails the workflow'
    Assert-True (($failure.Result.Stages | Where-Object Name -eq 'Linux').Status -eq 'failed') 'failing prerequisite is reported'
    Assert-True (($failure.Result.Stages | Where-Object Name -eq 'Homebrew').Status -eq 'skipped') 'dependent stage is skipped'
    Assert-True (($failure.Result.Stages | Where-Object Name -eq 'Homebrew').BlockedBy -contains 'Linux') 'dependent stage names its blocker'
}

function Test-DualShellContract {
    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $pwsh = (Get-Command pwsh.exe -ErrorAction Stop).Source
    $desktop = Invoke-Plan -Runtime $powershell
    $core = Invoke-Plan -Runtime $pwsh
    if (-not $desktop -or -not $core) { return }
    Assert-True ((@($desktop.Stages.Name) -join ',') -eq (@($core.Stages.Name) -join ',')) 'both shells expose identical target order'
    Assert-True ((@($desktop.Stages.Privilege) -join ',') -eq (@($core.Stages.Privilege) -join ',')) 'both shells expose identical privilege plan'
}

$sections = if ($Section -eq 'All') {
    @('CommandSurface', 'PlanContract', 'OutputContract', 'TargetContract', 'SafetyContract', 'DependencyContract', 'WindowsContract', 'WinGetContract', 'ScoopContract', 'WslContract', 'LinuxContract', 'HomebrewContract', 'ContainerContract', 'ReconciliationContract', 'PrivilegeContract', 'ExecutionContract', 'DualShellContract')
} else { @($Section) }

foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}

Write-Host "Workstation update tests passed ($script:assertions assertions)."
