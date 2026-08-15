[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('status', 'harvest', 'review', 'approve-tasks', 'dry-run', 'run', 'adopt', 'validate')]
    [string] $Action,

    [Parameter(Position = 1)]
    [string] $Skill,

    [string] $TasksFile,
    [string] $Staging,
    [ValidateSet('Mock', 'Codex')][string] $Backend = 'Mock',
    [ValidateRange(1, 20)][int] $MaxSessions = 5,
    [ValidateRange(2, 20)][int] $MaxTasks = 3,
    [ValidateRange(1, 8)][int] $EditBudget = 4,
    [ValidateRange(0, 8760)][int] $LookbackHours = 72,
    [switch] $AllowProviderCalls,
    [switch] $ConfirmReview,
    [switch] $ConfirmAdoption,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$cli = (Get-Command skillopt-sleep.exe -CommandType Application -ErrorAction Ignore).Source
if (-not $cli) { $cli = (Get-Command skillopt-sleep -ErrorAction Ignore).Source }
if (-not $cli) { throw 'SkillOpt is not installed. Run Apply-Workstation.ps1 -Mode Ensure or Set-SkillOptState.ps1 -Mode Ensure.' }
$configPath = Join-Path $env:USERPROFILE '.skillopt-sleep\config.json'

function Assert-SafeConfig {
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Managed SkillOpt safety config is missing: $configPath" }
    $state = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $violations = @()
    if ($state.evolve_memory -ne $false) { $violations += 'evolve_memory must be false' }
    if ($state.auto_adopt -ne $false) { $violations += 'auto_adopt must be false' }
    if ($state.gate_mode -ne 'on') { $violations += 'gate_mode must be on' }
    if ($state.gate_no_regression -ne $true) { $violations += 'gate_no_regression must be true' }
    if ($state.target_task_filter -ne $true) { $violations += 'target_task_filter must be true' }
    if ($state.redact_secrets -ne $true) { $violations += 'redact_secrets must be true' }
    if ($violations.Count -gt 0) { throw "Unsafe SkillOpt configuration: $($violations -join '; '). Run Set-SkillOptState.ps1 -Mode Ensure." }
}

function Resolve-TargetSkill {
    if (-not $Skill) { throw "Action '$Action' requires a skill name from .agents/skills." }
    if ($Skill -notmatch '^[a-z0-9-]{1,63}$') { throw "Invalid skill name: $Skill" }
    $path = Join-Path $repositoryRoot ".agents\skills\$Skill\SKILL.md"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Repository skill not found: $Skill" }
    (Resolve-Path -LiteralPath $path).Path
}

function Resolve-ReviewedTasks {
    param([Parameter(Mandatory = $true)][string] $ExpectedTarget)
    if (-not $TasksFile) { throw "Action '$Action' requires -TasksFile. Harvest and review tasks before optimization." }
    $path = (Resolve-Path -LiteralPath $TasksFile -ErrorAction Stop).Path
    $payload = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($payload.format -ne 'skillopt_sleep.tasks.v1') { throw 'Unsupported SkillOpt task-file format.' }
    if ($payload.reviewed -ne $true) { throw 'Task file is not approved. Inspect it, then run skillopt approve-tasks <skill> -TasksFile <path> -ConfirmReview.' }
    if (@($payload.tasks).Count -lt 2) { throw 'At least two reviewed tasks are required for a held-out validation gate.' }
    if (-not $payload.target_skill_path) { throw 'Task file does not declare its target skill path.' }
    $declaredTarget = [IO.Path]::GetFullPath($payload.target_skill_path)
    if (-not $declaredTarget.Equals([IO.Path]::GetFullPath($ExpectedTarget), [StringComparison]::OrdinalIgnoreCase)) { throw "Task file targets another skill: $declaredTarget" }
    $path
}

function Invoke-Cli {
    param([Parameter(Mandatory = $true)][string[]] $Arguments)
    & $cli @Arguments
    if ($LASTEXITCODE -ne 0) { throw "SkillOpt failed with exit code $LASTEXITCODE." }
}

Assert-SafeConfig
$actionName = $Action.ToLowerInvariant()

switch ($actionName) {
    'status' {
        $arguments = @('status', '--project', $repositoryRoot)
        if ($Json) { $arguments += '--json' }
        Invoke-Cli $arguments
    }
    'validate' {
        $arguments = @('-NoLogo', '-NoProfile', '-File', (Join-Path $PSScriptRoot 'Test-RepositorySkills.ps1'), '-RepositoryRoot', $repositoryRoot)
        if ($Json) { $arguments += '-Json' }
        & pwsh.exe @arguments
        if ($LASTEXITCODE -ne 0) { throw "Skill validation failed with exit code $LASTEXITCODE." }
    }
    'harvest' {
        $target = Resolve-TargetSkill
        $reviewDirectory = Join-Path $repositoryRoot '.skillopt-sleep\review'
        New-Item -ItemType Directory -Path $reviewDirectory -Force | Out-Null
        $output = if ($TasksFile) { [IO.Path]::GetFullPath($TasksFile) } else { Join-Path $reviewDirectory ("{0}-tasks-{1}.json" -f $Skill, (Get-Date -Format 'yyyyMMdd-HHmmss')) }
        $arguments = @('harvest', '--project', $repositoryRoot, '--scope', 'invoked', '--source', 'codex', '--target-skill-path', $target, '--lookback-hours', $LookbackHours, '--max-sessions', $MaxSessions, '--max-tasks', $MaxTasks, '--output', $output)
        if ($Json) { $arguments += '--json' }
        Invoke-Cli $arguments
        if (-not $Json) { Write-Host "Sensitive review draft: $output" }
    }
    'review' {
        if ($TasksFile) {
            $path = (Resolve-Path -LiteralPath $TasksFile -ErrorAction Stop).Path
            $payload = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $summary = [pscustomobject]@{ Path = $path; Format = $payload.format; Reviewed = $payload.reviewed; Sessions = $payload.n_sessions; TargetSkillPath = $payload.target_skill_path; Tasks = @($payload.tasks).Count }
            if ($Json) { [pscustomobject]@{ Summary = $summary; Tasks = @($payload.tasks) } | ConvertTo-Json -Depth 10 } else { $summary | Format-List; @($payload.tasks) | Select-Object id, split, outcome, intent, reference_kind | Format-Table -Wrap }
        } elseif ($Staging) {
            $path = (Resolve-Path -LiteralPath $Staging -ErrorAction Stop).Path
            $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.skillopt-sleep\staging')).TrimEnd('\') + '\'
            if (-not $path.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Staging path is outside this repository SkillOpt staging tree.' }
            Get-ChildItem -LiteralPath $path -File | Select-Object Name, Length, LastWriteTime
            $report = Join-Path $path 'report.md'
            if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report }
        } else {
            Invoke-Cli @('status', '--project', $repositoryRoot)
        }
    }
    'approve-tasks' {
        $target = Resolve-TargetSkill
        if (-not $ConfirmReview) { throw 'Approval requires -ConfirmReview after inspecting every task and removing sensitive content.' }
        if (-not $TasksFile) { throw 'Approval requires -TasksFile.' }
        $path = (Resolve-Path -LiteralPath $TasksFile -ErrorAction Stop).Path
        $payload = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($payload.format -ne 'skillopt_sleep.tasks.v1') { throw 'Unsupported SkillOpt task-file format.' }
        if (@($payload.tasks).Count -lt 2) { throw 'At least two tasks are required for the held-out gate.' }
        if (-not $payload.target_skill_path -or -not ([IO.Path]::GetFullPath($payload.target_skill_path)).Equals([IO.Path]::GetFullPath($target), [StringComparison]::OrdinalIgnoreCase)) { throw 'Task file target does not match the selected skill.' }
        $payload.reviewed = $true
        if ($payload.PSObject.Properties.Name -contains 'reviewed_utc') { $payload.reviewed_utc = [DateTime]::UtcNow.ToString('o') } else { $payload | Add-Member -NotePropertyName reviewed_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) }
        $taskJson = $payload | ConvertTo-Json -Depth 12
        [IO.File]::WriteAllText($path, $taskJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        Write-Host "Approved reviewed task file: $path"
    }
    { $_ -in 'dry-run', 'run' } {
        $target = Resolve-TargetSkill
        $tasks = Resolve-ReviewedTasks -ExpectedTarget $target
        if ($Backend -eq 'Codex' -and -not $AllowProviderCalls) { throw 'Codex-backed optimization sends reviewed task content to the provider. Re-run with -AllowProviderCalls to acknowledge this boundary.' }
        $arguments = @($actionName, '--project', $repositoryRoot, '--scope', 'invoked', '--source', 'codex', '--backend', $Backend.ToLowerInvariant(), '--target-skill-path', $target, '--tasks-file', $tasks, '--edit-budget', $EditBudget, '--max-sessions', $MaxSessions, '--max-tasks', $MaxTasks, '--lookback-hours', $LookbackHours, '--progress')
        if ($Json) { $arguments += '--json' }
        Invoke-Cli $arguments
    }
    'adopt' {
        $target = Resolve-TargetSkill
        if (-not $ConfirmAdoption) { throw 'Adoption requires -ConfirmAdoption after reviewing the staged report and proposed SKILL.md diff.' }
        if (-not $Staging) { throw 'Adoption requires an explicit -Staging path; latest-staging adoption is intentionally disabled.' }
        $path = (Resolve-Path -LiteralPath $Staging -ErrorAction Stop).Path
        $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.skillopt-sleep\staging')).TrimEnd('\') + '\'
        if (-not $path.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Staging path is outside this repository SkillOpt staging tree.' }
        $manifestPath = Join-Path $path 'manifest.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Staging manifest is missing.' }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.accepted -ne $true -or $manifest.has_skill -ne $true) { throw 'Staging manifest does not contain an accepted skill proposal.' }
        if ($manifest.has_memory -eq $true) { throw 'Refusing staging that would modify project memory.' }
        $liveTarget = [IO.Path]::GetFullPath($manifest.live_skill_path)
        if (-not $liveTarget.Equals([IO.Path]::GetFullPath($target), [StringComparison]::OrdinalIgnoreCase)) { throw "Staged proposal targets another skill: $liveTarget" }
        Invoke-Cli @('adopt', '--project', $repositoryRoot, '--staging', $path)
        & pwsh.exe -NoLogo -NoProfile -File (Join-Path $PSScriptRoot 'Test-RepositorySkills.ps1') -RepositoryRoot $repositoryRoot
        if ($LASTEXITCODE -ne 0) { throw 'The adopted skill failed repository validation. SkillOpt created a backup; inspect the adoption output and restore it.' }
    }
}
