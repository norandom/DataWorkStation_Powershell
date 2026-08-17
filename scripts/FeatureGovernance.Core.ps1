Set-StrictMode -Version Latest

function Get-SpecFeatureProperty {
    param([Parameter(Mandatory = $true)][object] $Object, [Parameter(Mandatory = $true)][string] $Name)
    if ($Object -is [Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function Invoke-SpecFeatureGovernanceAdapter {
    param(
        [Parameter(Mandatory = $true)][hashtable] $Adapter,
        [Parameter(Mandatory = $true)][string] $Operation,
        [object[]] $Arguments = @()
    )
    if (-not $Adapter.ContainsKey($Operation) -or $Adapter[$Operation] -isnot [scriptblock]) {
        throw "Spec feature governance adapter operation is unavailable: $Operation"
    }
    & $Adapter[$Operation] @Arguments
}

function Get-SpecFeatureLegacyFingerprint {
    param([string[]] $Modules, [string[]] $StateCapabilities)
    $canonical = "Modules`n$(@($Modules | Sort-Object) -join "`n")`nStateCapabilities`n$(@($StateCapabilities | Sort-Object) -join "`n")`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function New-SpecFeatureGovernanceFailure {
    param(
        [Parameter(Mandatory = $true)][string] $Code,
        [Parameter(Mandatory = $true)][string] $Kind,
        [Parameter(Mandatory = $true)][string] $Identity,
        [string] $FeatureSpec,
        [Parameter(Mandatory = $true)][string] $Message
    )
    [pscustomobject]@{
        Code = $Code
        Kind = $Kind
        Identity = $Identity
        FeatureSpec = $FeatureSpec
        Message = $Message
    }
}

function Get-NormalizedSpecFeaturePath {
    param([Parameter(Mandatory = $true)][string] $RepositoryRoot, [string] $FeatureSpec)
    if (-not $FeatureSpec -or [IO.Path]::IsPathRooted($FeatureSpec)) { return $null }
    $normalized = $FeatureSpec.Replace('\', '/').TrimEnd('/')
    if ($normalized -notmatch '^specs/[^/]+$') { return $null }
    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $specsRoot = [IO.Path]::GetFullPath((Join-Path $root 'specs')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $normalized.Replace('/', [IO.Path]::DirectorySeparatorChar)))
    if (-not $resolved.StartsWith($specsRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    return $normalized
}

function Invoke-SpecFeatureGovernanceEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $RepositoryRoot,
        [Parameter(Mandatory = $true)][object[]] $Modules,
        [Parameter(Mandatory = $true)][object[]] $Capabilities,
        [Parameter(Mandatory = $true)][hashtable] $Configuration,
        [Parameter(Mandatory = $true)][hashtable] $Adapter
    )

    $failures = [Collections.Generic.List[object]]::new()
    $references = [Collections.Generic.List[object]]::new()
    $legacyModules = @($Configuration.LegacyBoundary.Modules)
    $legacyRoutes = @($Configuration.LegacyBoundary.StateCapabilities)
    $moduleNames = @($Modules | ForEach-Object { [string] (Get-SpecFeatureProperty -Object $_ -Name Name) })
    $stateRoutes = @($Capabilities | Where-Object { @(Get-SpecFeatureProperty -Object $_ -Name StateCommands).Count -gt 0 })
    $stateRouteIds = @($stateRoutes | ForEach-Object { [string] (Get-SpecFeatureProperty -Object $_ -Name Id) })

    foreach ($group in @($legacyModules | Group-Object | Where-Object Count -gt 1)) {
        $failures.Add((New-SpecFeatureGovernanceFailure -Code DuplicateLegacyIdentity -Kind Module -Identity $group.Name -Message "Legacy module identity '$($group.Name)' is declared more than once."))
    }
    foreach ($group in @($legacyRoutes | Group-Object | Where-Object Count -gt 1)) {
        $failures.Add((New-SpecFeatureGovernanceFailure -Code DuplicateLegacyIdentity -Kind StateRoute -Identity $group.Name -Message "Legacy state-route identity '$($group.Name)' is declared more than once."))
    }
    foreach ($name in @($legacyModules | Sort-Object -Unique)) {
        if ($name -notin $moduleNames) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code UnknownLegacyIdentity -Kind Module -Identity $name -Message "Legacy module '$name' does not exist in the workstation module catalog."))
        }
    }
    foreach ($id in @($legacyRoutes | Sort-Object -Unique)) {
        if ($id -notin $stateRouteIds) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code UnknownLegacyIdentity -Kind StateRoute -Identity $id -Message "Legacy state route '$id' does not exist in the capability catalog."))
        }
    }

    $actualFingerprint = Get-SpecFeatureLegacyFingerprint -Modules $legacyModules -StateCapabilities $legacyRoutes
    $expectedFingerprint = ([string] $Configuration.LegacyBoundary.Sha256).ToLowerInvariant()
    $fingerprintValid = $actualFingerprint -eq $expectedFingerprint
    if (-not $fingerprintValid) {
        $failures.Add((New-SpecFeatureGovernanceFailure -Code LegacyFingerprintMismatch -Kind LegacyBoundary -Identity 'LegacyBoundary' -Message "Legacy membership fingerprint is $actualFingerprint; reviewed fingerprint is $expectedFingerprint."))
    }

    $governedModules = @($Modules | Where-Object { (Get-SpecFeatureProperty -Object $_ -Name Name) -notin $legacyModules })
    foreach ($module in $governedModules) {
        $name = [string] (Get-SpecFeatureProperty -Object $module -Name Name)
        $declaredFeature = [string] (Get-SpecFeatureProperty -Object $module -Name FeatureSpec)
        if (-not $declaredFeature) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code MissingFeatureSpec -Kind Module -Identity $name -Message "Module '$name' is not grandfathered and must declare FeatureSpec."))
            continue
        }
        $normalized = Get-NormalizedSpecFeaturePath -RepositoryRoot $RepositoryRoot -FeatureSpec $declaredFeature
        if (-not $normalized) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code InvalidFeaturePath -Kind Module -Identity $name -FeatureSpec $declaredFeature -Message "Module '$name' FeatureSpec must be one normalized repository-relative child of specs/."))
            continue
        }
        $references.Add([pscustomobject]@{ Kind = 'Module'; Identity = $name; FeatureSpec = $normalized })
    }

    $governedRoutes = @($stateRoutes | Where-Object { (Get-SpecFeatureProperty -Object $_ -Name Id) -notin $legacyRoutes })
    foreach ($route in $governedRoutes) {
        $id = [string] (Get-SpecFeatureProperty -Object $route -Name Id)
        $declaredFeature = [string] (Get-SpecFeatureProperty -Object $route -Name FeatureSpec)
        if (-not $declaredFeature) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code MissingFeatureSpec -Kind StateRoute -Identity $id -Message "State route '$id' is not grandfathered and must declare FeatureSpec."))
            continue
        }
        $normalized = Get-NormalizedSpecFeaturePath -RepositoryRoot $RepositoryRoot -FeatureSpec $declaredFeature
        if (-not $normalized) {
            $failures.Add((New-SpecFeatureGovernanceFailure -Code InvalidFeaturePath -Kind StateRoute -Identity $id -FeatureSpec $declaredFeature -Message "State route '$id' FeatureSpec must be one normalized repository-relative child of specs/."))
            continue
        }
        $references.Add([pscustomobject]@{ Kind = 'StateRoute'; Identity = $id; FeatureSpec = $normalized })
        foreach ($moduleName in @(Get-SpecFeatureProperty -Object $route -Name Modules)) {
            $pairedModules = @($Modules | Where-Object { (Get-SpecFeatureProperty -Object $_ -Name Name) -eq $moduleName })
            if ($pairedModules.Count -eq 0) {
                $failures.Add((New-SpecFeatureGovernanceFailure -Code UnknownPairedModule -Kind StateRoute -Identity $id -FeatureSpec $normalized -Message "State route '$id' names unknown focused module '$moduleName'."))
                continue
            }
            $pairedModule = $pairedModules[0]
            $moduleFeature = [string] (Get-SpecFeatureProperty -Object $pairedModule -Name FeatureSpec)
            if ($moduleFeature) {
                $normalizedModuleFeature = Get-NormalizedSpecFeaturePath -RepositoryRoot $RepositoryRoot -FeatureSpec $moduleFeature
                if ($normalizedModuleFeature -ne $normalized) {
                    $failures.Add((New-SpecFeatureGovernanceFailure -Code FeatureReferenceMismatch -Kind StateRoute -Identity $id -FeatureSpec $normalized -Message "State route '$id' references '$normalized' but focused module '$moduleName' references '$normalizedModuleFeature'."))
                }
            }
        }
    }

    $referencedFeatures = [Collections.Generic.List[object]]::new()
    foreach ($featureSpec in @($references.FeatureSpec | Sort-Object -Unique)) {
        $missingArtifacts = [Collections.Generic.List[string]]::new()
        foreach ($artifact in @($Configuration.RequiredArtifacts)) {
            $relativeArtifact = "$featureSpec/$artifact"
            if (-not (Invoke-SpecFeatureGovernanceAdapter -Adapter $Adapter -Operation TestFile -Arguments @($relativeArtifact))) {
                $missingArtifacts.Add($artifact)
                $failures.Add((New-SpecFeatureGovernanceFailure -Code MissingArtifact -Kind Feature -Identity $featureSpec -FeatureSpec $featureSpec -Message "Referenced feature '$featureSpec' is missing required artifact '$artifact'."))
            }
        }
        $gatePassed = $false
        $detail = 'not run because required artifacts are missing'
        if ($missingArtifacts.Count -eq 0) {
            try {
                $gate = Invoke-SpecFeatureGovernanceAdapter -Adapter $Adapter -Operation InvokeFinalGate -Arguments @($featureSpec)
                $gatePassed = [bool] (Get-SpecFeatureProperty -Object $gate -Name Passed)
                $detail = [string] (Get-SpecFeatureProperty -Object $gate -Name Detail)
                if (-not $gatePassed) {
                    $failures.Add((New-SpecFeatureGovernanceFailure -Code FinalGateFailed -Kind Feature -Identity $featureSpec -FeatureSpec $featureSpec -Message "Referenced feature '$featureSpec' did not pass its final EARS gate: $detail"))
                }
            } catch {
                $detail = $_.Exception.Message
                $failures.Add((New-SpecFeatureGovernanceFailure -Code FinalGateFailed -Kind Feature -Identity $featureSpec -FeatureSpec $featureSpec -Message "Referenced feature '$featureSpec' final EARS gate could not run: $detail"))
            }
        }
        $referencedFeatures.Add([pscustomobject]@{
            FeatureSpec = $featureSpec
            ArtifactsValid = $missingArtifacts.Count -eq 0
            FinalGatePassed = $gatePassed
            Detail = $detail
        })
    }

    $compliant = $failures.Count -eq 0
    [pscustomobject]@{
        SchemaVersion = 1
        Outcome = if ($compliant) { 'compliant' } else { 'failed' }
        Compliant = $compliant
        ModuleCount = $Modules.Count
        StateRouteCount = $stateRoutes.Count
        GovernedModules = @($governedModules | ForEach-Object { [string] (Get-SpecFeatureProperty -Object $_ -Name Name) })
        GovernedStateRoutes = @($governedRoutes | ForEach-Object { [string] (Get-SpecFeatureProperty -Object $_ -Name Id) })
        ReferencedFeatures = @($referencedFeatures)
        LegacyFingerprint = [pscustomobject]@{
            ExpectedSha256 = $expectedFingerprint
            ActualSha256 = $actualFingerprint
            Valid = $fingerprintValid
            ModuleCount = $legacyModules.Count
            StateRouteCount = $legacyRoutes.Count
        }
        Failures = @($failures)
    }
}

function Get-SpecFeatureGovernanceHumanText {
    param([Parameter(Mandatory = $true)][object] $Result)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("Spec feature governance: $($Result.Outcome)")
    $lines.Add("Checked modules/state routes: $($Result.ModuleCount)/$($Result.StateRouteCount)")
    $lines.Add("Governed modules: $(@($Result.GovernedModules) -join ', ')")
    $lines.Add("Governed state routes: $(@($Result.GovernedStateRoutes) -join ', ')")
    $lines.Add("Legacy fingerprint: $($Result.LegacyFingerprint.ActualSha256) (expected $($Result.LegacyFingerprint.ExpectedSha256))")
    foreach ($feature in @($Result.ReferencedFeatures)) {
        $lines.Add("Feature $($feature.FeatureSpec): artifacts=$($feature.ArtifactsValid); final=$($feature.FinalGatePassed); $($feature.Detail)")
    }
    foreach ($failure in @($Result.Failures)) {
        $lines.Add("FAIL [$($failure.Code)] $($failure.Kind)/$($failure.Identity): $($failure.Message)")
    }
    $lines -join [Environment]::NewLine
}
