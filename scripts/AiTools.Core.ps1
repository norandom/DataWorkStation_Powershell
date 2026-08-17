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
    $observedPath = if ($command) { [string] $command.Source } else { $null }
    $wrongChannel = [bool] ($observedPath -and $Product.ForbiddenPathPattern -and
        $observedPath -match [string] $Product.ForbiddenPathPattern)
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
    [pscustomobject]@{
        Name = $Product.Name
        Enabled = [bool] $Product.Enabled
        Target = $Product.Target
        Channel = $Product.Channel
        Command = $Product.Command
        Package = $Product.NpmPackage
        Installed = -not [string]::IsNullOrWhiteSpace($version)
        Version = $version
        ObservedPath = if ($npm) { $npm.Source } else { $null }
        WrongChannel = $false
        Status = if ($version) { 'compliant' } else { 'absent' }
        Action = if ($Product.Enabled -and -not $version) { 'npm-global-install' } else { 'none' }
        PrivilegeBoundary = 'Current Windows user global npm prefix; explicit Ensure only.'
    }
}

function Get-OpenCodeDesktopRecord {
    param([Parameter(Mandatory = $true)][hashtable] $Product)
    $path = Resolve-AiToolPath $Product.InstallPath
    $present = Test-Path -LiteralPath $path -PathType Leaf
    [pscustomobject]@{
        Name = $Product.Name
        Enabled = [bool] $Product.Enabled
        Target = $Product.Target
        Channel = $Product.Channel
        Command = $null
        Installed = $present
        Version = $Product.Version
        ObservedPath = if ($present) { $path } else { $null }
        WrongChannel = $false
        Status = if ($present) { 'compliant' } else { 'absent' }
        Action = if ($Product.Enabled -and -not $present) { 'install-pinned-release' } else { 'none' }
        PrivilegeBoundary = 'Current Windows user desktop application; explicit Ensure only.'
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
