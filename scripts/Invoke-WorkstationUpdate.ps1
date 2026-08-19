[CmdletBinding()]
param(
    [ValidateSet('All', 'Windows', 'WinGet', 'Scoop', 'Wsl', 'Linux', 'Homebrew', 'Containers', 'PowerShellEnvironment')]
    [string[]] $Target = @('All'),
    [switch] $Run,
    [switch] $Check,
    [switch] $Json,
    [scriptblock] $CommandRunner,
    [Parameter(DontShow = $true)][string] $ForensicCatalogPath,
    [Parameter(DontShow = $true)][scriptblock] $ReleaseFetcher,
    [Parameter(DontShow = $true)][switch] $PassThru
)

$ErrorActionPreference = 'Stop'
$null = $CommandRunner # consumed by the nested command executor
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configuration = Import-PowerShellDataFile -LiteralPath (Join-Path $repositoryRoot 'config\workstation-update.psd1')
$releaseVersion = (Get-Content -LiteralPath (Join-Path $repositoryRoot 'VERSION') -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($ForensicCatalogPath)) { $ForensicCatalogPath = Join-Path $repositoryRoot 'config\forensic-tools.psd1' }
if ($Run -and $Check) { throw '-Run and -Check are mutually exclusive. Review available pinned releases before running ordinary updates.' }

function Get-ForensicToolUpdateStatus {
    param([Parameter(Mandatory = $true)][string] $LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { throw "Forensic tool catalog not found: $LiteralPath" }
    $catalog = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($LiteralPath))
    $approved = @($catalog.Records | Where-Object { $_.ReviewState -eq 'Approved' } | ForEach-Object {
        [pscustomobject]@{ RecordId = $_.RecordId; ToolId = $_.ToolId; UpstreamVersion = $_.UpstreamVersion; BuildRevision = $_.BuildRevision; ReleaseTag = $_.ReleaseIdentity.Tag }
    })
    $candidates = @($catalog.Records | Where-Object { $_.ReviewState -eq 'Candidate' } | ForEach-Object {
        [pscustomobject]@{ RecordId = $_.RecordId; ToolId = $_.ToolId; UpstreamVersion = $_.UpstreamVersion; BuildRevision = $_.BuildRevision; ReleaseTag = $_.ReleaseIdentity.Tag; Action = 'review-required' }
    })
    [pscustomobject]@{ Approved = $approved; Candidates = $candidates }
}

function Assert-UpdateCatalog {
    $targets = @($configuration.Targets)
    $names = @($targets.Name)
    $orders = @($targets.Order)
    if (@($names | Sort-Object -Unique).Count -ne $names.Count) { throw 'Update target names must be unique.' }
    if (@($orders | Sort-Object -Unique).Count -ne $orders.Count) { throw 'Update target orders must be unique.' }
    foreach ($item in $targets) {
        foreach ($dependency in @($item.DependsOn)) {
            $dependencyMatches = @($targets | Where-Object Name -eq $dependency)
            if ($dependencyMatches.Count -ne 1) { throw "Update target '$($item.Name)' has missing or duplicate dependency '$dependency'." }
            if ([int] $dependencyMatches[0].Order -ge [int] $item.Order) { throw "Update target '$($item.Name)' has non-preceding dependency '$dependency'." }
        }
    }
}

function Resolve-UpdateTargets {
    param([string[]] $Requested)

    if ($Requested -contains 'All' -and $Requested.Count -gt 1) { throw "Target 'All' cannot be combined with another target." }
    $selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $visiting = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    function Add-TargetWithDependencies {
        param([string] $Name)
        if ($selected.Contains($Name)) { return }
        if (-not $visiting.Add($Name)) { throw "Update dependency cycle includes '$Name'." }
        $item = @($configuration.Targets | Where-Object Name -eq $Name)
        if ($item.Count -ne 1) { throw "Unknown update target '$Name'." }
        foreach ($dependency in @($item[0].DependsOn)) { Add-TargetWithDependencies $dependency }
        [void] $visiting.Remove($Name)
        [void] $selected.Add($Name)
    }

    $roots = if ($Requested -contains 'All') { @($configuration.Targets.Name) } else { @($Requested) }
    foreach ($name in $roots) { Add-TargetWithDependencies $name }
    @($configuration.Targets | Where-Object { $selected.Contains($_.Name) } | Sort-Object { [int] $_['Order'] })
}

function New-PlannedStage {
    param([hashtable] $Definition)
    [pscustomobject][ordered]@{
        Name = [string] $Definition.Name
        Title = [string] $Definition.Title
        Order = [int] $Definition.Order
        DependsOn = @($Definition.DependsOn)
        Privilege = [string] $Definition.Privilege
        ChangesState = $true
        RestartMayBeRequired = [bool] $Definition.RestartMayBeRequired
        Status = 'planned'
        Detail = [string] $Definition.Detail
        ExitCode = $null
        BlockedBy = @()
        RestartRequired = $false
    }
}

function Write-HumanResult {
    param([object] $Result)
    Write-Host "Workstation update $($Result.Action.ToLowerInvariant()) (release $($Result.ReleaseVersion))"
    $Result.Stages | Select-Object Order, Name, Privilege, Status, @{ Name = 'DependsOn'; Expression = { @($_.DependsOn) -join ',' } }, Detail |
        Format-Table -AutoSize -Wrap
    if ($Result.Action -eq 'Plan') { Write-Host 'No updates were installed. Run update -Check to query pinned releases or update -Run to execute this plan.' }
    if ($Result.Action -eq 'Check') {
        $Result.PinnedSoftware | Select-Object Name, CurrentVersion, LatestVersion, Status, Review | Format-Table -AutoSize -Wrap
        Write-Host "Pinned release check: $($Result.PinnedUpdatesAvailable) update(s) available. No files or software were changed."
    }
    foreach ($candidate in @($Result.ForensicToolCandidates)) {
        Write-Host "Forensic candidate (not installed): $($candidate.ToolId) $($candidate.UpstreamVersion)-$($candidate.BuildRevision); explicit review is required."
    }
}

function ConvertTo-BoundedDetail {
    param([object[]] $Output, [string] $Fallback)
    $text = (@($Output) | ForEach-Object { "$_" }) -join ' '
    $text = ($text -replace '\s+', ' ').Trim()
    if (-not $text) { return $Fallback }
    if ($text.Length -gt 1024) { return $text.Substring($text.Length - 1024) }
    $text
}

function Invoke-UpdateCommand {
    param(
        [string] $Stage,
        [string] $FilePath,
        [string[]] $ArgumentList,
        [string] $Privilege = 'CurrentUser',
        [int[]] $AcceptedExitCodes = @(0)
    )

    $request = [pscustomobject]@{
        Stage = $Stage
        FilePath = $FilePath
        ArgumentList = @($ArgumentList)
        Privilege = $Privilege
    }
    if (-not $Json) { Write-Host ("Running [{0}/{1}]: {2} {3}" -f $Stage, $Privilege, $FilePath, (@($ArgumentList) -join ' ')) }
    if ($CommandRunner) {
        $response = & $CommandRunner $request
        if ($null -eq $response -or $response.PSObject.Properties.Name -notcontains 'ExitCode') {
            throw "The synthetic command runner returned no ExitCode for stage '$Stage'."
        }
        if ($response.PSObject.Properties.Name -notcontains 'Output') { $response | Add-Member -NotePropertyName Output -NotePropertyValue @() }
        if ($response.PSObject.Properties.Name -notcontains 'Succeeded') { $response | Add-Member -NotePropertyName Succeeded -NotePropertyValue ([int] $response.ExitCode -in @($AcceptedExitCodes)) }
        if ($response.PSObject.Properties.Name -notcontains 'RestartRequired') { $response | Add-Member -NotePropertyName RestartRequired -NotePropertyValue $false }
        return $response
    }

    $output = @(& $FilePath @ArgumentList 2>&1)
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
    if (-not $Json) { $output | ForEach-Object { Write-Host "  $_" } }
    [pscustomobject]@{
        ExitCode = [int] $exitCode
        Output = @($output)
        Succeeded = [int] $exitCode -in @($AcceptedExitCodes)
        RestartRequired = $false
    }
}

function Complete-CommandStage {
    param([object[]] $Responses, [string] $SuccessDetail)
    $failed = @($Responses | Where-Object { $_.PSObject.Properties.Name -contains 'Succeeded' -and -not $_.Succeeded })
    if ($failed.Count -gt 0) {
        return [pscustomobject]@{ Succeeded = $false; RestartRequired = $false; ExitCode = [int] $failed[0].ExitCode; Detail = ConvertTo-BoundedDetail $failed[0].Output 'Native command failed.' }
    }
    $restart = @($Responses | Where-Object { $_.RestartRequired }).Count -gt 0
    [pscustomobject]@{ Succeeded = $true; RestartRequired = $restart; ExitCode = 0; Detail = $SuccessDetail }
}

function Invoke-UpdateStage {
    param([hashtable] $Definition)

    $stageName = [string] $Definition.Name
    switch ([string] $Definition.Executor) {
        'WindowsUpdate' {
            $windowsUpdate = Join-Path $PSScriptRoot 'Invoke-WindowsUpdate.ps1'
            $response = Invoke-UpdateCommand -Stage $stageName -FilePath 'sudo.exe' -Privilege 'WindowsAdministrator' -ArgumentList @('powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $windowsUpdate, '-Action', 'Install', '-Json')
            $restart = [bool] $response.RestartRequired
            if ($response.Succeeded -and $response.Output) {
                try {
                    $windowsResult = (@($response.Output) -join "`n") | ConvertFrom-Json -ErrorAction Stop
                    $restart = [bool] $windowsResult.RebootRequired
                    return [pscustomobject]@{ Succeeded = ($windowsResult.Status -ne 'failed'); RestartRequired = $restart; ExitCode = [int] $response.ExitCode; Detail = [string] $windowsResult.Detail }
                } catch { Write-Verbose 'Windows Update output did not match the bounded JSON contract.' }
            }
            Complete-CommandStage @($response) 'Windows software updates completed.'
        }
        'WinGet' {
            $response = Invoke-UpdateCommand -Stage $stageName -FilePath 'winget.exe' -ArgumentList @('upgrade', '--all', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity') -AcceptedExitCodes @($configuration.AcceptedExitCodes.WinGet)
            if ([int] $response.ExitCode -in @($configuration.AcceptedExitCodes.WinGet)) { $response.Succeeded = $true }
            Complete-CommandStage @($response) 'WinGet application updates completed or no update was applicable.'
        }
        'Scoop' {
            $scoopState = Join-Path $PSScriptRoot 'Set-ScoopState.ps1'
            $responses = @()
            $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'powershell.exe' -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scoopState, '-Mode', 'Test')
            if ($responses[-1].Succeeded) {
                $scoop = Get-Command scoop.ps1 -CommandType ExternalScript -ErrorAction SilentlyContinue
                if (-not $scoop) { return [pscustomobject]@{ Succeeded = $false; RestartRequired = $false; ExitCode = 1; Detail = 'Scoop command is unavailable after its declared-state test.' } }
                $responses += Invoke-UpdateCommand -Stage $stageName -FilePath $scoop.Source -ArgumentList @('update')
                if ($responses[-1].Succeeded) { $responses += Invoke-UpdateCommand -Stage $stageName -FilePath $scoop.Source -ArgumentList @('update', '*') }
            }
            Complete-CommandStage $responses 'Scoop, declared buckets, and installed applications updated without cleanup.'
        }
        'Wsl' {
            $response = Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList @('--update')
            Complete-CommandStage @($response) 'WSL runtime update completed without distribution shutdown.'
        }
        'Linux' {
            . (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
            $wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
            $responses = @()
            foreach ($distribution in @($wslEnvironment.WSL_DISTRIBUTION, $wslEnvironment.WSL_MALWARE_DISTRIBUTION)) {
                $arguments = @('-d', $distribution, '--user', 'root', '--exec', 'sh', '-lc', 'DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y')
                $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList $arguments -Privilege "WslRoot/$distribution"
                if (-not $responses[-1].Succeeded) { break }
            }
            Complete-CommandStage $responses 'Both declared Debian distributions updated independently.'
        }
        'Homebrew' {
            . (Join-Path $PSScriptRoot 'Import-WslEnvironment.ps1')
            $wslEnvironment = Import-WslEnvironment -RepositoryRoot $repositoryRoot
            $responses = @()
            foreach ($instance in @($configuration.HomebrewInstances)) {
                $distribution = [string] $wslEnvironment[$instance.DistributionVariable]
                $linuxUser = [string] $wslEnvironment[$instance.UserVariable]
                $brew = [string] $instance.Executable
                foreach ($formula in @($instance.PinnedFormulae)) {
                    $pinList = Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList @('-d', $distribution, '--user', $linuxUser, '--exec', $brew, 'list', '--pinned')
                    $responses += $pinList
                    if (-not $pinList.Succeeded) { break }
                    $pinnedFormulae = @($pinList.Output | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
                    if ($pinnedFormulae -notcontains $formula) {
                        $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList @('-d', $distribution, '--user', $linuxUser, '--exec', $brew, 'pin', $formula)
                        if (-not $responses[-1].Succeeded) { break }
                    }
                }
                if (@($responses | Where-Object { -not $_.Succeeded }).Count -gt 0) { break }
                $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList @('-d', $distribution, '--user', $linuxUser, '--exec', $brew, 'update')
                if ($responses[-1].Succeeded) { $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'wsl.exe' -ArgumentList @('-d', $distribution, '--user', $linuxUser, '--exec', $brew, 'upgrade') }
            }
            Complete-CommandStage $responses 'Declared Homebrew instances and unpinned formulae updated.'
        }
        'Containers' {
            $developerDocker = Join-Path $PSScriptRoot 'Set-DeveloperDockerState.ps1'
            $rootlessPodman = Join-Path $PSScriptRoot 'Set-RootlessPodmanState.ps1'
            $responses = @()
            $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'pwsh.exe' -Privilege 'WslRoot/Developer' -ArgumentList @('-NoLogo', '-NoProfile', '-File', $developerDocker, '-Mode', 'Ensure')
            if ($responses[-1].Succeeded) { $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'pwsh.exe' -Privilege 'WslRoot/MalwareAnalysis' -ArgumentList @('-NoLogo', '-NoProfile', '-File', $rootlessPodman, '-Mode', 'Ensure') }
            Complete-CommandStage $responses 'Developer Docker and malware-analysis rootless Podman reconciled.'
        }
        'PowerShellEnvironment' {
            $applyWorkstation = Join-Path $repositoryRoot 'Apply-Workstation.ps1'
            $wslTrustBoundary = Join-Path $PSScriptRoot 'Test-WslTrustBoundary.ps1'
            $responses = @()
            $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'powershell.exe' -Privilege 'Mixed' -ArgumentList @('-NoLogo', '-NoProfile', '-File', $applyWorkstation, '-Mode', 'Ensure')
            if ($responses[-1].Succeeded) { $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'powershell.exe' -Privilege 'Mixed' -ArgumentList @('-NoLogo', '-NoProfile', '-File', $applyWorkstation, '-Mode', 'Test') }
            if ($responses[-1].Succeeded) {
                foreach ($role in @('TrustedUtility', 'MalwareAnalysis', 'DevOps')) {
                    $responses += Invoke-UpdateCommand -Stage $stageName -FilePath 'pwsh.exe' -Privilege 'Observational' -ArgumentList @('-NoLogo', '-NoProfile', '-File', $wslTrustBoundary, '-Role', $role)
                    if (-not $responses[-1].Succeeded) { break }
                }
            }
            Complete-CommandStage $responses 'Current-release default workstation state ensured and verified.'
        }
        default { throw "Unknown update executor '$($Definition.Executor)'." }
    }
}

Assert-UpdateCatalog
$resolved = @(Resolve-UpdateTargets -Requested $Target)
$forensicStatus = Get-ForensicToolUpdateStatus -LiteralPath $ForensicCatalogPath
$pinnedSoftwareResult = if ($Check) {
    $pinnedUpdateScript = Join-Path $PSScriptRoot 'Get-PinnedSoftwareUpdate.ps1'
    $pinnedCatalogPath = Join-Path $repositoryRoot ([string] $configuration.PinnedSoftwareCatalog)
    & $pinnedUpdateScript -CatalogPath $pinnedCatalogPath -PassThru -ReleaseFetcher $ReleaseFetcher
} else { $null }
$pinnedReleases = [object[]] @()
if ($pinnedSoftwareResult) { $pinnedReleases = [object[]] @($pinnedSoftwareResult.Releases) }
$result = [pscustomobject][ordered]@{
    SchemaVersion = 1
    Action = if ($Run) { 'Run' } elseif ($Check) { 'Check' } else { 'Plan' }
    ReleaseVersion = $releaseVersion
    SelectedTargets = @($Target)
    Stages = @($resolved | ForEach-Object { New-PlannedStage -Definition $_ })
    ForensicToolApproved = @($forensicStatus.Approved)
    ForensicToolCandidates = @($forensicStatus.Candidates)
    PinnedSoftware = $pinnedReleases
    PinnedUpdatesAvailable = if ($pinnedSoftwareResult) { [int] $pinnedSoftwareResult.UpdatesAvailable } else { 0 }
    PinnedReleaseCheckSucceeded = if ($pinnedSoftwareResult) { [bool] $pinnedSoftwareResult.Succeeded } else { $null }
    RestartRequired = $false
    Succeeded = if ($pinnedSoftwareResult) { [bool] $pinnedSoftwareResult.Succeeded } else { $true }
    NewShellRecommended = $false
}

if (-not $Run) {
    if ($PassThru) { $result }
    elseif ($Json) { $result | ConvertTo-Json -Depth 8 }
    else { Write-HumanResult $result }
    if (-not $PassThru -and -not $result.Succeeded) { exit 1 }
    return
}

$terminalStates = @('succeeded', 'skipped', 'failed', 'restart-required')
foreach ($stage in @($result.Stages)) {
    $blocked = @($stage.DependsOn | Where-Object {
        $dependency = @($result.Stages | Where-Object Name -eq $_)
        $dependency.Count -eq 1 -and $dependency[0].Status -in @('failed', 'skipped')
    })
    if ($blocked.Count -gt 0) {
        $stage.Status = 'skipped'
        $stage.BlockedBy = @($blocked)
        $stage.Detail = "Blocked by: $($blocked -join ', ')."
        continue
    }

    if (-not $Json) { Write-Host "`n==> $($stage.Title) [$($stage.Privilege)]" }
    try {
        $definition = @($configuration.Targets | Where-Object Name -eq $stage.Name)[0]
        $execution = Invoke-UpdateStage -Definition $definition
        $stage.ExitCode = [int] $execution.ExitCode
        $stage.RestartRequired = [bool] $execution.RestartRequired
        $stage.Detail = [string] $execution.Detail
        if (-not $execution.Succeeded) { $stage.Status = 'failed' }
        elseif ($stage.RestartRequired) { $stage.Status = 'restart-required' }
        else { $stage.Status = 'succeeded' }
    } catch {
        $stage.Status = 'failed'
        $stage.ExitCode = 1
        $stage.Detail = $_.Exception.Message
    }
}

$result.RestartRequired = @($result.Stages | Where-Object RestartRequired).Count -gt 0
$result.Succeeded = @($result.Stages | Where-Object Status -eq 'failed').Count -eq 0
$result.NewShellRecommended = @($result.Stages | Where-Object { $_.Name -eq 'PowerShellEnvironment' -and $_.Status -in @('succeeded', 'restart-required') }).Count -gt 0
foreach ($stage in @($result.Stages)) {
    if ($stage.Status -notin $terminalStates) { throw "Update stage '$($stage.Name)' has invalid terminal status '$($stage.Status)'." }
}

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 8 }
else { Write-HumanResult $result }
if (-not $PassThru -and -not $result.Succeeded) { exit 1 }
