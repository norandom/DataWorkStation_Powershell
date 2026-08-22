Set-StrictMode -Version Latest

function Resolve-AiToolPath {
    param([AllowNull()][string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    [Environment]::ExpandEnvironmentVariables($Path)
}
function Get-AiCommandRecord {
    param([Parameter(Mandatory = $true)][hashtable] $Product)

    $expectedPath = Resolve-AiToolPath $Product.ExpectedPath
    $command = $null
    if ($expectedPath -and (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
        $command = Get-Item -LiteralPath $expectedPath
    } elseif ($Product.Command) {
        $command = Get-Command $Product.Command -CommandType Application,ExternalScript -ErrorAction Ignore |
            Select-Object -First 1
    }
    $observedPath = if (-not $command) { $null }
        elseif ($command.PSObject.Properties['Source']) { [string] $command.Source }
        elseif ($command.PSObject.Properties['FullName']) { [string] $command.FullName }
        else { $null }
    $forbiddenPathPattern = if ($Product.ContainsKey('ForbiddenPathPattern')) { [string] $Product.ForbiddenPathPattern } else { $null }
    $wrongChannel = [bool] ($observedPath -and $forbiddenPathPattern -and
        $observedPath -match $forbiddenPathPattern)
    $expectedPathMatched = -not $expectedPath -or
        ($observedPath -and [IO.Path]::GetFullPath($observedPath) -eq [IO.Path]::GetFullPath($expectedPath))

    [pscustomobject]@{
        Name = $Product.Name
        Enabled = [bool] $Product.Enabled
        Target = $Product.Target
        Channel = $Product.Channel
        Command = $Product.Command
        Installed = [bool] $command
        ObservedPath = $observedPath
        WrongChannel = $wrongChannel
        Status = if (-not $command) { 'absent' } elseif ($wrongChannel -or -not $expectedPathMatched) { 'wrong-channel' } else { 'compliant' }
        Action = if (-not $Product.Enabled) { 'none' } elseif (-not $command -or $wrongChannel -or -not $expectedPathMatched) { 'install-from-declared-channel' } else { 'none' }
        PrivilegeBoundary = 'Current Windows user; network-delivered installer only during explicit Ensure.'
    }
}

function Get-NpmGlobalPackageRecord {
    param([Parameter(Mandatory = $true)][hashtable] $Product)

    $version = $null
    $npm = Get-Command npm.cmd,npm.exe,npm -ErrorAction Ignore | Select-Object -First 1
    if ($npm) {
        $raw = @(& $npm.Source list --global --depth=0 --json $Product.NpmPackage 2>$null) -join "`n"
        try {
            $result = $raw | ConvertFrom-Json -ErrorAction Stop
            $property = $result.dependencies.PSObject.Properties[$Product.NpmPackage]
            if ($property) { $version = [string] $property.Value.version }
        } catch {
            $version = $null
        }
    }
    $expectedPath = if ($Product.ContainsKey('ExpectedPath')) { Resolve-AiToolPath $Product.ExpectedPath } else { $null }
    $formerScoopPath = if ($Product.ContainsKey('FormerScoopPath')) { Resolve-AiToolPath $Product.FormerScoopPath } else { $null }
    $wrongChannel = [bool] ($formerScoopPath -and (Test-Path -LiteralPath $formerScoopPath -PathType Leaf))
    $expectedPathMatched = -not $expectedPath -or (Test-Path -LiteralPath $expectedPath -PathType Leaf)
    [pscustomobject]@{
        Name = $Product.Name
        Enabled = [bool] $Product.Enabled
        Target = $Product.Target
        Channel = $Product.Channel
        Command = $Product.Command
        Package = $Product.NpmPackage
        Installed = -not [string]::IsNullOrWhiteSpace($version)
        Version = $version
        ObservedPath = if ($expectedPathMatched -and $expectedPath) { $expectedPath } elseif ($npm) { $npm.Source } else { $null }
        WrongChannel = $wrongChannel
        Status = if ($wrongChannel) { 'wrong-channel' } elseif (-not $version) { 'absent' } elseif (-not $expectedPathMatched) { 'wrong-channel' } else { 'compliant' }
        Action = if (-not $Product.Enabled -or ($version -and $expectedPathMatched -and -not $wrongChannel)) { 'none' } else { 'npm-global-install' }
        PrivilegeBoundary = 'Current Windows user global npm prefix; explicit Ensure only.'
    }
}

function Get-OpenCodeDesktopRecord {
    param([Parameter(Mandatory = $true)][hashtable] $Product)
    $path = Resolve-AiToolPath $Product.InstallPath
    $present = Test-Path -LiteralPath $path -PathType Leaf
    $shortcutPath = if ($Product.ContainsKey('ShortcutPath')) { Resolve-AiToolPath $Product.ShortcutPath } else { $null }
    $shortcutPresent = -not $shortcutPath -or (Test-Path -LiteralPath $shortcutPath -PathType Leaf)
    $formerScoopPath = if ($Product.ContainsKey('FormerScoopPath')) { Resolve-AiToolPath $Product.FormerScoopPath } else { $null }
    $wrongChannel = [bool] ($formerScoopPath -and (Test-Path -LiteralPath $formerScoopPath -PathType Leaf))
    $observedVersion = if ($present) { [string] (Get-Item -LiteralPath $path).VersionInfo.FileVersion } else { $null }
    $versionMatched = [string]::IsNullOrWhiteSpace([string] $Product.Version) -or $observedVersion -eq [string] $Product.Version
    [pscustomobject]@{
        Name = $Product.Name
        Enabled = [bool] $Product.Enabled
        Target = $Product.Target
        Channel = $Product.Channel
        Command = $null
        Installed = $present
        Version = $observedVersion
        DeclaredVersion = $Product.Version
        ObservedPath = if ($present) { $path } else { $null }
        ShortcutPath = $shortcutPath
        ShortcutPresent = $shortcutPresent
        WrongChannel = $wrongChannel
        Status = if ($wrongChannel) { 'wrong-channel' } elseif (-not $present) { 'absent' } elseif (-not $versionMatched) { 'version-drift' } elseif (-not $shortcutPresent) { 'shortcut-missing' } else { 'compliant' }
        Action = if (-not $Product.Enabled -or ($present -and $versionMatched -and $shortcutPresent -and -not $wrongChannel)) { 'none' } else { 'install-from-declared-channel' }
        PrivilegeBoundary = 'Current Windows user verified release extraction; explicit Ensure only.'
    }
}

function Get-AiToolsState {
    param([Parameter(Mandatory = $true)][hashtable] $Configuration)
    $records = foreach ($product in @($Configuration.Products)) {
        if ($product.Name -eq 'OpenCode Desktop') { Get-OpenCodeDesktopRecord $product }
        elseif ($product.Channel -eq 'NpmGlobal') { Get-NpmGlobalPackageRecord $product }
        else { Get-AiCommandRecord $product }
    }
    $pending = @($records | Where-Object { $_.Enabled -and $_.Status -ne 'compliant' })
    [pscustomobject]@{
        SchemaVersion = 1
        Category = 'AiTools'
        OptIn = $true
        Status = if ($pending.Count -eq 0) { 'compliant' } else { 'drifted' }
        Products = @($records)
        PendingCount = $pending.Count
        NetworkRequiredForEnsure = $true
        StateChangingEnsure = $true
    }
}

function Get-AiToolsHumanText {
    param([Parameter(Mandatory = $true)] $State)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("AI tools: $($State.Status) (opt-in)")
    foreach ($item in @($State.Products)) {
        $lines.Add("  $($item.Name): $($item.Status); target=$($item.Target); channel=$($item.Channel); action=$($item.Action)")
    }
    $lines.Add('  Ensure impact: executes reviewed network installers as the current Windows user.')
    $lines -join [Environment]::NewLine
}
