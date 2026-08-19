[CmdletBinding()]
param(
    [ValidateSet('All', 'LocalConfiguration', 'WindowsCleanup', 'TraceCleanup', 'CommandSurface')]
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

function Test-LocalConfiguration {
    $samplePath = Join-Path $repositoryRoot 'config.sample.json'
    $schemaPath = Join-Path $repositoryRoot 'config\local-config.schema.json'
    $importerPath = Join-Path $repositoryRoot 'scripts\Import-WorkstationConfiguration.ps1'
    Assert-True (Test-Path -LiteralPath $samplePath -PathType Leaf) 'the portable local configuration sample exists'
    Assert-True (Test-Path -LiteralPath $schemaPath -PathType Leaf) 'the local configuration JSON schema exists'
    Assert-True (Test-Path -LiteralPath $importerPath -PathType Leaf) 'the local configuration importer exists'
    if (-not (Test-Path -LiteralPath $samplePath -PathType Leaf) -or -not (Test-Path -LiteralPath $importerPath -PathType Leaf)) { return }
    $sample = Get-Content -LiteralPath $samplePath -Raw | ConvertFrom-Json
    Assert-True ($sample.schemaVersion -eq 1) 'the local configuration schema is versioned'
    Assert-True ($sample.fonts.terminalFamily -and $sample.paths.traces -and $sample.paths.eventLogs) 'font and storage paths share one local configuration'
    foreach ($role in @('developer', 'malware', 'nixos', 'ai')) {
        Assert-True ($sample.wsl.PSObject.Properties.Name -contains $role) "the local configuration declares the $role WSL boundary"
    }
    . $importerPath
    . (Join-Path $repositoryRoot 'scripts\Import-WslEnvironment.ps1')
    $loaded = Import-WorkstationConfiguration -RepositoryRoot $repositoryRoot -ConfigurationPath $samplePath
    Assert-True ($loaded.Paths.Traces -and $loaded.Defender.Exclusions.Count -gt 0) 'the importer returns validated paths and Defender exclusions'
    $wsl = Import-WslEnvironment -RepositoryRoot $repositoryRoot -ConfigurationPath $samplePath
    Assert-True ($wsl.WSL_DISTRIBUTION -ne $wsl.WSL_MALWARE_DISTRIBUTION) 'the compatibility WSL map preserves separate trust boundaries'
    foreach ($legacy in @('.excluded.sample', '.terminal-fonts-sample', '.wsl-env.sample')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $legacy))) "$legacy is replaced by config.sample.json"
    }
}

function Test-WindowsCleanup {
    $configuration = Get-Source 'config/windows-cleanup.psd1'
    $source = Get-Source 'scripts/Invoke-WindowsCleanup.ps1'
    Assert-True ($configuration -match "'Update Cleanup'" -and $configuration -match "KeepNewest\s*=\s*1") 'the cleanup profile includes update cleanup and keeps the newest shadow copy'
    foreach ($preserved in @('Prefetch', 'Event logs', 'D3D Shader Cache', 'Thumbnail Cache')) {
        Assert-True ($configuration -match [regex]::Escape($preserved)) "the cleanup profile explicitly preserves $preserved"
    }
    Assert-True ($source -match '\[switch\]\s*\$Run' -and $source -match '\[switch\]\s*\$ConfirmRestorePoints') 'cleanup execution and restore-point deletion are separately explicit'
    Assert-True ($source -match '/StartComponentCleanup' -and $source -notmatch '/ResetBase') 'component cleanup preserves update uninstallability where Windows supports it'
    Assert-True ($source -match 'cleanmgr\.exe' -and $source -match 'StateFlags') 'the command uses an allowlisted Disk Cleanup profile'
    Assert-True ($source -match 'DiskCleanupScope' -and $source -notmatch "'/d',\s*\[string\]\s*\$configuration\.Volume") 'the plan reports that cleanmgr sagerun enumerates eligible volumes instead of claiming a C-only scope'
    Assert-True ($source -match 'ShadowInventorySucceeded' -and $source -match 'inventory is unavailable') 'run mode fails closed when shadow-copy inventory is unavailable'
    Assert-True ($source -notmatch 'wevtutil.+cl|Clear-EventLog|\\Prefetch\\|Clear-RecycleBin') 'Windows cleanup never clears event logs, Prefetch, or the recycle bin'
}

function Test-TraceCleanup {
    $source = Get-Source 'scripts/Invoke-TraceCleanup.ps1'
    Assert-True ($source -match '\[switch\]\s*\$Run' -and $source -match '\[switch\]\s*\$ConfirmCleanup') 'trace deletion requires an explicit run and confirmation boundary'
    Assert-True ($source -match "Status\s*-eq\s*'Active'|Active") 'active trace sessions are recognized'
    Assert-True ($source -notmatch 'E:\\Traces') 'trace cleanup reads its root from local configuration'

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('cleanup-contract-' + [guid]::NewGuid().ToString('N'))
    $traceRoot = Join-Path $tempRoot 'traces'
    $configurationPath = Join-Path $tempRoot 'config.json'
    try {
        $old = Join-Path $traceRoot 'profile-native-old'
        $active = Join-Path $traceRoot 'pcap-active'
        $recent = Join-Path $traceRoot 'dotnet-recent.nettrace'
        New-Item -ItemType Directory -Path $old,$active -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $old 'state.json'), '{"Active":false}')
        [IO.File]::WriteAllText((Join-Path $old 'cpu.etl'), 'old')
        [IO.File]::WriteAllText((Join-Path $active 'session.json'), '{"Status":"Active"}')
        [IO.File]::WriteAllText((Join-Path $active 'capture.etl'), 'active')
        [IO.File]::WriteAllText($recent, 'recent')
        Get-ChildItem -LiteralPath $old -Recurse -Force | ForEach-Object { $_.LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30) }
        (Get-Item -LiteralPath $old).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30)
        Get-ChildItem -LiteralPath $active -Recurse -Force | ForEach-Object { $_.LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30) }
        (Get-Item -LiteralPath $active).LastWriteTimeUtc = [DateTime]::UtcNow.AddDays(-30)
        $fixture = [ordered]@{
            schemaVersion = 1
            fonts = @{ terminalFamily = 'Fira Code' }
            wsl = @{
                developer = @{ distribution = 'Debian'; user = 'user' }
                malware = @{ distribution = 'Debian-MW'; user = 'user' }
                nixos = @{ distribution = 'NixOS'; user = 'user' }
                ai = @{ distribution = 'NixOS-AI'; user = 'ai' }
            }
            paths = @{ traces = $traceRoot; eventLogs = (Join-Path $tempRoot 'logs') }
            defender = @{ exclusions = @($tempRoot) }
            cleanup = @{ traces = @{ retentionDays = 14 } }
        }
        [IO.File]::WriteAllText($configurationPath, ($fixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
        $command = Join-Path $repositoryRoot 'scripts\Invoke-TraceCleanup.ps1'
        $plan = & $command -ConfigurationPath $configurationPath -PassThru
        Assert-True ($plan.Action -eq 'Plan' -and $plan.CandidateCount -eq 1) 'the trace plan selects only expired completed evidence'
        Assert-True ($plan.ActiveSkipped -eq 1) 'the trace plan reports the active session it protects'
        $run = & $command -ConfigurationPath $configurationPath -Run -ConfirmCleanup -PassThru
        Assert-True ($run.Succeeded -and -not (Test-Path -LiteralPath $old)) 'confirmed cleanup removes the expired completed trace'
        Assert-True ((Test-Path -LiteralPath $active) -and (Test-Path -LiteralPath $recent)) 'active and recent traces remain intact'
        Assert-True (Test-Path -LiteralPath $traceRoot -PathType Container) 'cleanup preserves the configured trace root'
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

function Test-CommandSurface {
    $aliases = Get-Source 'profile/Aliases.ps1'
    $capabilities = Get-Source 'config/capabilities.psd1'
    $docs = Get-Source 'docs/cleanup.md'
    Assert-True ($aliases -match 'function global:cleanup-windows' -and $aliases -match 'function global:cleanup-traces') 'the profile exposes human cleanup commands'
    Assert-True ($aliases -match "function global:cleanup-windows[\s\S]+?sudo\.exe") 'Windows cleanup plans use sudo so VSS inventory is authoritative'
    Assert-True ($capabilities -match 'cleanup-windows' -and $capabilities -match 'cleanup-traces') 'cleanup commands are routed through the capability catalog'
    Assert-True ($docs -match 'Prefetch' -and $docs -match 'event logs' -and $docs -match 'restore') 'cleanup documentation states the preservation and recovery boundaries'
}

$sections = if ($Section -eq 'All') { @('LocalConfiguration', 'WindowsCleanup', 'TraceCleanup', 'CommandSurface') } else { @($Section) }
foreach ($name in $sections) {
    & (Get-Command "Test-$name" -CommandType Function)
    Write-Host "PASS $name"
}
Write-Host "Cleanup state tests passed ($script:assertions assertions)."
