[CmdletBinding(DefaultParameterSetName = 'Trace')]
param(
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Trace')]
    [string] $TracePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Folded')]
    [string] $InputFoldedPath,

    [string] $OutputPath,
    [string] $FoldedPath,
    [object[]] $ProcessId = @(),
    [string[]] $ProcessName = @(),
    [object] $StartSeconds,
    [object] $EndSeconds,
    [string] $Title = 'Native CPU flame graph',
    [string] $Subtitle,
    [switch] $NoOpen,
    [switch] $Json
)

$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
[Threading.Thread]::CurrentThread.CurrentUICulture = [Globalization.CultureInfo]::InvariantCulture

function ConvertTo-Seconds([object] $Value, [string] $Name) {
    if ($Value -isnot [string]) {
        $number = [Convert]::ToDouble($Value, [Globalization.CultureInfo]::InvariantCulture)
    } else {
        $number = 0.0
        $parsed = [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref] $number)
        if (-not $parsed) {
            $parsed = [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::CurrentCulture, [ref] $number)
        }
        if (-not $parsed) { throw "$Name must be a number of seconds." }
    }
    if ($number -lt 0 -or $number -gt 86400) { throw "$Name must be between 0 and 86400 seconds." }
    return $number
}

$normalizedProcessIds = [Collections.Generic.List[int]]::new()
foreach ($value in $ProcessId) {
    foreach ($part in ([string] $value -split ',')) {
        if ([string]::IsNullOrWhiteSpace($part)) { continue }
        $parsedId = 0
        if (-not [int]::TryParse($part.Trim(), [Globalization.NumberStyles]::Integer, [Globalization.CultureInfo]::InvariantCulture, [ref] $parsedId)) {
            throw "Invalid process id: $part"
        }
        $normalizedProcessIds.Add($parsedId)
    }
}
$ProcessId = $normalizedProcessIds.ToArray()

$sourcePath = if ($PSCmdlet.ParameterSetName -eq 'Trace') {
    (Resolve-Path -LiteralPath $TracePath -ErrorAction Stop).Path
} else {
    (Resolve-Path -LiteralPath $InputFoldedPath -ErrorAction Stop).Path
}
if ($PSBoundParameters.ContainsKey('StartSeconds') -xor $PSBoundParameters.ContainsKey('EndSeconds')) {
    throw 'Specify StartSeconds and EndSeconds together.'
}
if ($PSBoundParameters.ContainsKey('StartSeconds')) {
    $StartSeconds = ConvertTo-Seconds $StartSeconds 'StartSeconds'
    $EndSeconds = ConvertTo-Seconds $EndSeconds 'EndSeconds'
}
if ($PSBoundParameters.ContainsKey('StartSeconds') -and $EndSeconds -le $StartSeconds) {
    throw 'EndSeconds must be greater than StartSeconds.'
}
if ($PSCmdlet.ParameterSetName -eq 'Folded' -and $FoldedPath) {
    throw 'FoldedPath is an output option for ETL input and cannot be combined with InputFoldedPath.'
}

$sourceDirectory = Split-Path -Parent $sourcePath
$sourceBase = [IO.Path]::GetFileNameWithoutExtension($sourcePath)
if (-not $OutputPath) { $OutputPath = Join-Path $sourceDirectory "$sourceBase-flamegraph.svg" }
if ($PSCmdlet.ParameterSetName -eq 'Trace' -and -not $FoldedPath) { $FoldedPath = Join-Path $sourceDirectory "$sourceBase.folded" }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ($FoldedPath) { $FoldedPath = [IO.Path]::GetFullPath($FoldedPath) }
foreach ($parent in @((Split-Path -Parent $OutputPath), $(if ($FoldedPath) { Split-Path -Parent $FoldedPath })) | Where-Object { $_ } | Select-Object -Unique) {
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Trace') {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) { throw 'dotnet is required to decode sampled CPU stacks from ETL.' }
    $projectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\NativeCpuStacks\NativeCpuStacks.csproj'
    if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { throw "Native CPU stack exporter is missing: $projectPath" }

    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @('run', '--project', $projectPath, '--configuration', 'Release', '--', $sourcePath, $FoldedPath)) {
        $arguments.Add($argument)
    }
    foreach ($id in $ProcessId) {
        $arguments.Add('--pid')
        $arguments.Add($id.ToString([Globalization.CultureInfo]::InvariantCulture))
    }
    foreach ($name in $ProcessName) {
        $arguments.Add('--process')
        $arguments.Add($name)
    }
    if ($PSBoundParameters.ContainsKey('StartSeconds')) {
        $arguments.Add('--start')
        $arguments.Add($StartSeconds.ToString('R', [Globalization.CultureInfo]::InvariantCulture))
        $arguments.Add('--end')
        $arguments.Add($EndSeconds.ToString('R', [Globalization.CultureInfo]::InvariantCulture))
    }

    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $dotnet.Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $arguments) { [void] $startInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'The native CPU stack exporter did not start.' }
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $outputText = $outputTask.GetAwaiter().GetResult().Trim()
    $errorText = $errorTask.GetAwaiter().GetResult().Trim()
    if ($process.ExitCode -ne 0) {
        throw "Native CPU stack export failed with exit code $($process.ExitCode): $errorText $outputText"
    }
    if (-not (Test-Path -LiteralPath $FoldedPath -PathType Leaf)) {
        throw "Native CPU stack export completed without creating '$FoldedPath'."
    }
    $effectiveFoldedPath = $FoldedPath
} else {
    $effectiveFoldedPath = $sourcePath
}

$aggregates = [Collections.Generic.Dictionary[string, long]]::new([StringComparer]::Ordinal)
$foldedPattern = [regex]::new('^(?<stack>.+)\s+(?<count>\d+)\s*$', [Text.RegularExpressions.RegexOptions]::Compiled)
foreach ($line in [IO.File]::ReadLines($effectiveFoldedPath)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $match = $foldedPattern.Match($line)
    if (-not $match.Success) { throw "Invalid folded stack line: $line" }
    $stack = $match.Groups['stack'].Value
    $count = [long] $match.Groups['count'].Value
    if ($aggregates.ContainsKey($stack)) { $aggregates[$stack] += $count } else { $aggregates[$stack] = $count }
}
if ($aggregates.Count -eq 0) {
    $selection = if ($ProcessId.Count -or $ProcessName.Count) { ' for the selected process filter' } else { '' }
    throw "No sampled CPU stacks were found$selection in '$sourcePath'."
}

function New-FlameNode([string] $Name) {
    [pscustomobject]@{
        Name = $Name
        Value = [long] 0
        Children = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    }
}

$tree = New-FlameNode $Title
foreach ($entry in $aggregates.GetEnumerator()) {
    $node = $tree
    $count = [long] $entry.Value
    $node.Value += $count
    foreach ($segment in $entry.Key -split ';') {
        if (-not $node.Children.ContainsKey($segment)) { $node.Children[$segment] = New-FlameNode $segment }
        $node = $node.Children[$segment]
        $node.Value += $count
    }
}

function Get-MaxDepth($Node, [int] $Depth = 0) {
    $maximum = $Depth
    foreach ($child in $Node.Children.Values) {
        $childDepth = Get-MaxDepth $child ($Depth + 1)
        if ($childDepth -gt $maximum) { $maximum = $childDepth }
    }
    return $maximum
}

function ConvertTo-XmlText([string] $Value) { [Security.SecurityElement]::Escape($Value) }

$powerShellColors = @('#E76F51', '#F2845C', '#F4A261', '#E98A4B', '#D95D39')
$terminalColors = @('#2A9DCE', '#3A86C8', '#4EA8DE', '#277DA1', '#5AA9E6')
$neutralColors = @('#8E9AAF', '#98A8C2', '#7D8CA3', '#A4B3C7', '#8797AF')
function Get-FrameColor([string] $Name, [string] $Palette) {
    if ($Name -eq $Title) { return '#34435E' }
    $hash = 0
    foreach ($character in $Name.ToCharArray()) { $hash = (($hash * 33) + [int] $character) % 100000 }
    $colors = if ($Palette -eq 'PowerShell') { $powerShellColors } elseif ($Palette -eq 'Terminal') { $terminalColors } else { $neutralColors }
    return $colors[$hash % $colors.Count]
}

$maxDepth = Get-MaxDepth $tree
$canvasWidth = 1600.0
$margin = 24.0
$headerHeight = 64.0
$frameHeight = 22.0
$chartWidth = $canvasWidth - (2 * $margin)
$canvasHeight = $headerHeight + (($maxDepth + 1) * $frameHeight) + 42
$rectangles = [Collections.Generic.List[string]]::new()

function Add-FlameNode($Node, [int] $Depth, [double] $X, [double] $Width, [string] $Palette) {
    if ($Depth -eq 1) {
        if ($Node.Name -match '^(?:pwsh|powershell)(?:\.exe)?\s') { $Palette = 'PowerShell' }
        elseif ($Node.Name -match 'terminal') { $Palette = 'Terminal' }
    }
    $y = $headerHeight + (($maxDepth - $Depth) * $frameHeight)
    $displayWidth = [Math]::Max(0.2, $Width - 0.6)
    $percent = if ($tree.Value) { 100.0 * $Node.Value / $tree.Value } else { 0 }
    $tooltip = ConvertTo-XmlText ('{0} - {1:N0} samples ({2:N2}%)' -f $Node.Name, $Node.Value, $percent)
    $label = ConvertTo-XmlText $Node.Name
    $fill = Get-FrameColor $Node.Name $Palette
    $textColor = if ($Node.Name -eq $Title) { '#FFFFFF' } else { '#101820' }
    $rectangles.Add(('<g><title>{0}</title><rect x="{1:F2}" y="{2:F2}" width="{3:F2}" height="{4:F2}" rx="2" fill="{5}" stroke="#FFFFFF" stroke-width="0.6"/>' -f $tooltip, $X, $y, $displayWidth, ($frameHeight - 1), $fill))
    $characterCapacity = [Math]::Floor(($displayWidth - 8) / 7.0)
    if ($characterCapacity -ge 3) {
        if ($label.Length -gt $characterCapacity) { $label = $label.Substring(0, [Math]::Max(1, $characterCapacity - 1)) + '...' }
        $rectangles.Add(('<text x="{0:F2}" y="{1:F2}" font-size="12" fill="{2}">{3}</text></g>' -f ($X + 4), ($y + 15), $textColor, $label))
    } else {
        $rectangles.Add('</g>')
    }
    $cursor = $X
    foreach ($child in $Node.Children.Values | Sort-Object @{ Expression = 'Value'; Descending = $true }, Name) {
        $childWidth = if ($Node.Value) { $Width * $child.Value / $Node.Value } else { 0 }
        Add-FlameNode $child ($Depth + 1) $cursor $childWidth $Palette
        $cursor += $childWidth
    }
}

Add-FlameNode $tree 0 $margin $chartWidth ''
if (-not $Subtitle) {
    $filterText = if ($ProcessId.Count -or $ProcessName.Count) { 'selected processes' } else { 'all sampled processes' }
    $Subtitle = "$filterText; module labels reflect image metadata available in the ETL"
}
$svg = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    ('<svg xmlns="http://www.w3.org/2000/svg" width="{0:F0}" height="{1:F0}" viewBox="0 0 {0:F0} {1:F0}">' -f $canvasWidth, $canvasHeight)
    ('<rect x="0" y="0" width="{0:F0}" height="{1:F0}" fill="#F7F8FA"/>' -f $canvasWidth, $canvasHeight)
    ('<text x="24" y="28" font-family="Segoe UI, sans-serif" font-size="21" font-weight="600" fill="#172033">{0}</text>' -f (ConvertTo-XmlText $Title))
    ('<text x="24" y="49" font-family="Segoe UI, sans-serif" font-size="12" fill="#4B5563">{0}</text>' -f (ConvertTo-XmlText $Subtitle))
    '<g font-family="Segoe UI, sans-serif">'
    $rectangles
    '</g>'
    ('<text x="24" y="{0:F0}" font-family="Segoe UI, sans-serif" font-size="11" fill="#6B7280">{1:N0} total samples across {2:N0} unique stacks</text>' -f ($canvasHeight - 14), $tree.Value, $aggregates.Count)
    '</svg>'
)
[IO.File]::WriteAllLines($OutputPath, $svg, [Text.UTF8Encoding]::new($false))

$opened = $false
if (-not $NoOpen) {
    & (Join-Path $PSScriptRoot 'Open-Profile.ps1') -Path $OutputPath
    $opened = $true
}
$result = [pscustomobject]@{
    Source = $sourcePath
    Folded = $effectiveFoldedPath
    Svg = $OutputPath
    Samples = $tree.Value
    UniqueStacks = $aggregates.Count
    MaxDepth = $maxDepth
    StartSeconds = if ($PSBoundParameters.ContainsKey('StartSeconds')) { $StartSeconds } else { $null }
    EndSeconds = if ($PSBoundParameters.ContainsKey('EndSeconds')) { $EndSeconds } else { $null }
    Opened = $opened
    Viewer = if ($opened) { 'qView' } else { $null }
}
if ($Json) { $result | ConvertTo-Json -Depth 3 } else { $result }
