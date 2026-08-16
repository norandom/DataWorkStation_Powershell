#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $PackageRoot,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string] $BuildRecord,
    [switch] $Json,
    [Parameter(DontShow = $true)][switch] $PassThru
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repositoryRoot 'tests\helpers\NativeForensicTestSupport.ps1'
$fixtureRoot = Join-Path $repositoryRoot 'tests\fixtures\ewf'
$verifierPath = Join-Path $PSScriptRoot 'Invoke-EwfVerification.ps1'
$testRoot = $null

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Forensic compatibility certification requires native Windows.' }
    foreach ($requiredPath in $PackageRoot, $BuildRecord, $helperPath, $fixtureRoot, $verifierPath) {
        if (-not (Test-Path -LiteralPath $requiredPath)) { throw "Certification input does not exist: $requiredPath" }
    }
    . $helperPath
    $build = Import-PowerShellDataFile -LiteralPath ([IO.Path]::GetFullPath($BuildRecord))
    $testRoot = New-NativeForensicTestRoot -Name 'candidate-compatibility'
    $corpus = New-DerivedEwfCertificationCorpus -FixtureRoot $fixtureRoot -DestinationRoot (Join-Path $testRoot 'corpus')
    $package = [pscustomobject]@{
        Root = [IO.Path]::GetFullPath($PackageRoot)
        Files = @(Get-ChildItem -LiteralPath $PackageRoot -File | Sort-Object Name | ForEach-Object { Get-TestFileIdentity -LiteralPath $_.FullName })
    }
    $catalog = New-SyntheticNativeForensicCatalog -Root (Join-Path $testRoot 'catalog') -Package $package
    $reportRoot = New-NativeForensicReportRoot -Root $testRoot
    $results = @()

    foreach ($case in $corpus.Cases) {
        $parameters = @{
            Path = $case.Path
            ReportDirectory = $reportRoot
            CatalogPath = $catalog.Path
            PassThru = $true
        }
        if ($case.Name -eq 'hostile-output') {
            $hostileBytes = [byte[]] $case.NativeStdOutBytes
            $parameters.NativeProcessRunner = { param($Executable, $Arguments) $null = $Executable, $Arguments; New-SyntheticNativeProcessResult -RawStdOut $hostileBytes }
        }
        elseif ($case.Name -eq 'unsupported') {
            $parameters.NativeProcessRunner = { param($Executable, $Arguments) throw "Unsupported input invoked the native verifier: $Executable $Arguments" }
        }
        if ($case.Name -eq 'persistence-failure') {
            $failureMessage = [string] $case.PersistenceFailure
            $parameters.PersistenceFaultProvider = { param($Stage, $Path) $null = $Path; if ($Stage -eq 'BeforeCommit') { throw $failureMessage } }
        }
        $output = @(. $verifierPath @parameters)
        $verification = @($output | Where-Object { $null -ne $_ -and $null -ne $_.PSObject.Properties['status'] } | Select-Object -First 1)
        if ($verification.Count -ne 1) { throw "Certification case '$($case.Name)' returned no verification result." }
        $observed = [string] $verification[0].status
        $results += [pscustomobject]@{
            name = [string] $case.Name
            expectedStatus = [string] $case.ExpectedStatus
            observedStatus = $observed
            passed = $observed -eq [string] $case.ExpectedStatus
        }
    }

    $lane = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'WindowsPowerShell-5.1' } else { 'PowerShell-7' }
    $failed = @($results | Where-Object { -not $_.passed })
    $result = [pscustomobject]@{
        schemaVersion = '1.0'
        status = if ($failed.Count -eq 0) { 'Passed' } else { 'Failed' }
        lane = $lane
        toolId = [string] $build.ToolId
        upstreamVersion = [string] $build.UpstreamVersion
        buildRevision = [string] $build.BuildRevision
        cases = $results
        failure = if ($failed.Count -eq 0) { $null } else { [pscustomobject]@{ code = 'certification-failed'; message = "$($failed.Count) compatibility case(s) did not match expected status." } }
    }
}
catch {
    $result = [pscustomobject]@{
        schemaVersion = '1.0'
        status = 'Failed'
        lane = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'WindowsPowerShell-5.1' } else { 'PowerShell-7' }
        toolId = $null
        upstreamVersion = $null
        buildRevision = $null
        cases = @()
        failure = [pscustomobject]@{ code = 'certification-failed'; message = $_.Exception.Message }
    }
}
finally {
    if ($null -ne $testRoot) { Remove-NativeForensicTestRoot -Root $testRoot }
}

if ($PassThru) { $result }
elseif ($Json) { $result | ConvertTo-Json -Depth 8 -Compress }
else {
    "Forensic candidate compatibility: $($result.status) [$($result.lane)]"
    foreach ($case in $result.cases) { "  $($case.name): $($case.observedStatus) (expected $($case.expectedStatus))" }
    if ($result.failure) { "Detail: $($result.failure.message)" }
}
if (-not $PassThru -and $MyInvocation.InvocationName -ne '.' -and $result.status -ne 'Passed') { exit 1 }
