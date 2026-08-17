Set-StrictMode -Version Latest

function Get-PyXllLicenseKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The local PyXLL license store is missing. Copy .licenses.yaml.sample to .licenses.yaml and add the key."
    }
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)
    if (-not ($lines -match '^\s*schema_version\s*:\s*1\s*$')) {
        throw 'The local PyXLL license store must declare schema_version: 1.'
    }
    $insidePyXll = $false
    foreach ($line in $lines) {
        if ($line -match '^pyxll\s*:\s*$') {
            $insidePyXll = $true
            continue
        }
        if ($insidePyXll -and $line -match '^\S') { break }
        if ($insidePyXll -and $line -match '^\s+key\s*:\s*(.*?)\s*$') {
            $value = $Matches[1].Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            if ([string]::IsNullOrWhiteSpace($value)) { break }
            return $value
        }
    }
    throw 'The local PyXLL license store has no non-empty pyxll.key value.'
}

function Set-PyXllIniSection {
    param(
        [Parameter(Mandatory)][object] $Lines,
        [Parameter(Mandatory)][string] $Section,
        [Parameter(Mandatory)][Collections.Specialized.OrderedDictionary] $Settings
    )

    $header = "[$Section]"
    $start = -1
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index].Trim() -ieq $header) { $start = $index; break }
    }
    if ($start -lt 0) {
        if ($Lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($Lines[$Lines.Count - 1])) { $Lines.Add('') }
        $Lines.Add($header)
        foreach ($key in $Settings.Keys) { $Lines.Add("$key = $($Settings[$key])") }
        return
    }

    $end = $Lines.Count
    for ($index = $start + 1; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index].Trim() -match '^\[[^]]+\]$') { $end = $index; break }
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    for ($index = $start + 1; $index -lt $end; $index++) {
        if ($Lines[$index] -match '^\s*([^#;][^=]*?)\s*=') {
            $key = $Matches[1].Trim()
            if ($Settings.Contains($key)) {
                $Lines[$index] = "$key = $($Settings[$key])"
                [void] $seen.Add($key)
            }
        }
    }
    foreach ($key in $Settings.Keys) {
        if (-not $seen.Contains([string] $key)) {
            $Lines.Insert($end, "$key = $($Settings[$key])")
            $end++
        }
    }
}

function Remove-PyXllIniListItems {
    param(
        [Parameter(Mandatory)][object] $Lines,
        [Parameter(Mandatory)][string] $Section,
        [Parameter(Mandatory)][string] $Key,
        [Parameter(Mandatory)][string[]] $Items
    )

    $header = "[$Section]"
    $sectionStart = -1
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index].Trim() -ieq $header) { $sectionStart = $index; break }
    }
    if ($sectionStart -lt 0) { return }

    $sectionEnd = $Lines.Count
    for ($index = $sectionStart + 1; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index].Trim() -match '^\[[^]]+\]$') { $sectionEnd = $index; break }
    }

    $keyIndex = -1
    $keyValue = ''
    for ($index = $sectionStart + 1; $index -lt $sectionEnd; $index++) {
        if ($Lines[$index] -match ('^\s*' + [regex]::Escape($Key) + '\s*=\s*(.*?)\s*$')) {
            $keyIndex = $index
            $keyValue = $Matches[1]
            break
        }
    }
    if ($keyIndex -lt 0) { return }

    $values = [Collections.Generic.List[string]]::new()
    foreach ($value in @($keyValue -split ',')) {
        if (-not [string]::IsNullOrWhiteSpace($value)) { $values.Add($value.Trim()) }
    }
    $continuationEnd = $keyIndex + 1
    while ($continuationEnd -lt $sectionEnd -and $Lines[$continuationEnd] -match '^\s+([^#;].*?)\s*$') {
        foreach ($value in @($Matches[1] -split ',')) {
            if (-not [string]::IsNullOrWhiteSpace($value)) { $values.Add($value.Trim()) }
        }
        $continuationEnd++
    }

    $remove = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) { [void] $remove.Add($item.Trim().Replace('/', '\')) }
    $remaining = @($values | Where-Object { -not $remove.Contains($_.Trim().Replace('/', '\')) })

    for ($index = $continuationEnd - 1; $index -ge $keyIndex; $index--) { $Lines.RemoveAt($index) }
    if ($remaining.Count -eq 1) {
        $Lines.Insert($keyIndex, "$Key = $($remaining[0])")
    } elseif ($remaining.Count -gt 1) {
        $Lines.Insert($keyIndex, "$Key =")
        for ($index = 0; $index -lt $remaining.Count; $index++) {
            $Lines.Insert($keyIndex + $index + 1, "`t$($remaining[$index])")
        }
    }
}

function Merge-PyXllConfiguration {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string] $ExistingText = '',
        [Parameter(Mandatory)][string] $PythonExecutable,
        [Parameter(Mandatory)][string] $WebView2UserDataFolder,
        [Parameter(Mandatory)][string] $LicenseKey,
        [Collections.Specialized.OrderedDictionary] $JupyterSettings,
        [string] $JupyterRibbonPath,
        [switch] $UseExplicitJupyterRibbon
    )

    if ([string]::IsNullOrWhiteSpace($LicenseKey)) { throw 'A non-empty PyXLL license key is required.' }
    $sourceLines = if ([string]::IsNullOrEmpty($ExistingText)) { @() } else { @($ExistingText -split '\r?\n') }
    $lines = [Collections.Generic.List[string]]::new()
    $skipLicense = $false
    foreach ($line in $sourceLines) {
        if ($line.Trim() -match '^\[LICENSE\]$') { $skipLicense = $true; continue }
        if ($skipLicense -and $line.Trim() -match '^\[[^]]+\]$') { $skipLicense = $false }
        if (-not $skipLicense) { $lines.Add($line) }
    }
    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
        $lines.RemoveAt($lines.Count - 1)
    }

    $python = [ordered]@{ executable = $PythonExecutable }
    $plotting = [ordered]@{
        plot_allow_html = '1'
        plot_allow_svg = '1'
        plot_allow_resize = '1'
        webview2_userdata_folder = $WebView2UserDataFolder
    }
    if ($UseExplicitJupyterRibbon) {
        if ([string]::IsNullOrWhiteSpace($JupyterRibbonPath)) { throw 'An explicit Jupyter ribbon path is required.' }
        $plotting.ribbon = $JupyterRibbonPath
    }
    Set-PyXllIniSection -Lines ([object] $lines) -Section 'PYTHON' -Settings $python
    Set-PyXllIniSection -Lines ([object] $lines) -Section 'PYXLL' -Settings $plotting
    if ($JupyterSettings) {
        Set-PyXllIniSection -Lines ([object] $lines) -Section 'JUPYTER' -Settings $JupyterSettings
    }
    if ($UseExplicitJupyterRibbon) {
        Remove-PyXllIniListItems -Lines ([object] $lines) -Section 'PYXLL' -Key 'modules' -Items @('pyxll_jupyter.pyxll')
        Remove-PyXllIniListItems -Lines ([object] $lines) -Section 'PYXLL' -Key 'ribbon' -Items @('./examples/ribbon/ribbon.xml')
    }
    if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) { $lines.Add('') }
    $lines.Add('[LICENSE]')
    $lines.Add("key = $LicenseKey")
    (($lines -join "`r`n") + "`r`n")
}

function Set-PyXllConfigurationFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $PythonExecutable,
        [Parameter(Mandatory)][string] $WebView2UserDataFolder,
        [Parameter(Mandatory)][string] $LicenseKey,
        [Collections.Specialized.OrderedDictionary] $JupyterSettings,
        [string] $JupyterRibbonPath,
        [switch] $UseExplicitJupyterRibbon
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        [IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $existing = if (Test-Path -LiteralPath $Path -PathType Leaf) { Get-Content -LiteralPath $Path -Raw } else { '' }
    $rendered = Merge-PyXllConfiguration -ExistingText $existing -PythonExecutable $PythonExecutable -WebView2UserDataFolder $WebView2UserDataFolder -LicenseKey $LicenseKey -JupyterSettings $JupyterSettings -JupyterRibbonPath $JupyterRibbonPath -UseExplicitJupyterRibbon:$UseExplicitJupyterRibbon
    $temporary = Join-Path $directory ('.pyxll.cfg.' + [guid]::NewGuid().ToString('N') + '.temporary')
    $backup = Join-Path $directory ('.pyxll.cfg.' + [guid]::NewGuid().ToString('N') + '.backup')
    try {
        [IO.File]::WriteAllText($temporary, $rendered, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($temporary, $Path, $backup, $true)
            Remove-Item -LiteralPath $backup -Force
        } else {
            Move-Item -LiteralPath $temporary -Destination $Path
        }
    } catch {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -and (Test-Path -LiteralPath $backup -PathType Leaf)) {
            Move-Item -LiteralPath $backup -Destination $Path
        }
        throw
    } finally {
        if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -Force }
    }
}

function Find-PyXllPayload {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]] $Roots)

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $candidate = Get-ChildItem -LiteralPath $root -Filter pyxll.xll -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = { $_.DirectoryName -match '64' }; Descending = $true }, LastWriteTimeUtc -Descending |
            Select-Object -First 1
        if ($candidate) { return $candidate.FullName }
    }
    $null
}

function Get-PyXllExcelAddIns {
    [CmdletBinding()]
    param()

    $paths = @(
        'HKCU:\Software\Microsoft\Office\16.0\Excel\Options',
        'HKCU:\Software\Microsoft\Office\Excel\Options'
    )
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $values = Get-ItemProperty -LiteralPath $path
        foreach ($property in $values.PSObject.Properties | Where-Object Name -match '^OPEN\d*$') {
            $value = [string] $property.Value
            if ($value -match '(?i)"([^"]*pyxll\.xll)"') {
                $Matches[1]
            } elseif ($value -match '(?i)([^\s"]*pyxll\.xll)') {
                $Matches[1]
            }
        }
    }
}

function Get-PortableExecutableArchitecture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        $stream.Position = 0x3c
        $peOffset = $reader.ReadInt32()
        $stream.Position = $peOffset + 4
        switch ($reader.ReadUInt16()) {
            0x8664 { 'x64' }
            0x014c { 'x86' }
            0xaa64 { 'arm64' }
            default { 'unknown' }
        }
    } finally {
        $reader.Dispose()
        $stream.Dispose()
    }
}

function Test-PyXllWebView2Runtime {
    [CmdletBinding()]
    param()

    $roots = [Collections.Generic.List[string]]::new()
    foreach ($parent in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not [string]::IsNullOrWhiteSpace($parent)) {
            $candidate = Join-Path $parent 'Microsoft\EdgeWebView\Application'
            if (Test-Path -LiteralPath $candidate -PathType Container) { $roots.Add($candidate) }
        }
    }
    @($roots).Count -gt 0
}
