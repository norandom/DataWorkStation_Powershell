[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $PSScriptRoot }
$skillsRoot = Join-Path $RepositoryRoot '.agents\skills'
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) { throw "Skills directory not found: $skillsRoot" }
$validator = Join-Path $env:USERPROFILE '.codex\skills\.system\skill-creator\scripts\quick_validate.py'
$uv = (Get-Command uv.exe -CommandType Application -ErrorAction Ignore).Source
$results = [Collections.Generic.List[object]]::new()

foreach ($directory in @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name)) {
    $skillFile = Join-Path $directory.FullName 'SKILL.md'
    $agentFile = Join-Path $directory.FullName 'agents\openai.yaml'
    $errors = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        $errors.Add('SKILL.md is missing.')
    } else {
        $content = Get-Content -LiteralPath $skillFile -Raw
        $frontmatterName = $null
        if ($content -notmatch '(?s)^---\s*\r?\nname:\s*([^\r\n]+)\r?\ndescription:\s*.+?\r?\n---') { $errors.Add('Frontmatter must contain name and description.') } else { $frontmatterName = $Matches[1].Trim(' "') }
        if ($content -match '\[TODO|\bTODO\b') { $errors.Add('TODO marker remains.') }
        if ($directory.Name -notmatch '^[a-z0-9-]{1,63}$') { $errors.Add('Directory name is not valid hyphen-case.') }
        if ($frontmatterName -and $frontmatterName -ne $directory.Name) { $errors.Add('Frontmatter name does not match the directory.') }
    }
    if (-not (Test-Path -LiteralPath $agentFile -PathType Leaf)) { $errors.Add('agents/openai.yaml is missing.') }

    $official = 'not available'
    if ($errors.Count -eq 0 -and $uv -and (Test-Path -LiteralPath $validator -PathType Leaf)) {
        $validationOutput = & $uv run --isolated --with pyyaml --python 3.12 python $validator $directory.FullName 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { $errors.Add("Official validator failed: $($validationOutput.Trim())") } else { $official = 'passed' }
    }
    $results.Add([pscustomobject]@{
        Skill = $directory.Name
        State = if ($errors.Count -eq 0) { 'valid' } else { 'invalid' }
        OfficialValidator = $official
        Errors = @($errors)
    })
}

if ($Json) { ConvertTo-Json -InputObject @($results) -Depth 6 } else { $results | Format-Table Skill, State, OfficialValidator, @{ Name = 'Errors'; Expression = { $_.Errors -join '; ' } } -Wrap -AutoSize }
if (@($results | Where-Object State -eq 'invalid').Count -gt 0) { exit 1 }
