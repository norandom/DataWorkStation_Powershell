[CmdletBinding()]
param(
    [ValidateSet('Test', 'Ensure', 'Reinitialize')]
    [string] $Mode = 'Test',
    [string] $Project = 'All',
    [switch] $Json,
    [switch] $ConfirmPyXllInstall,
    [string] $ConfigurationPath = (Join-Path $PSScriptRoot '..\config\quant-research.psd1')
)

$ErrorActionPreference = 'Stop'
$supportedOpenBbEntryPointGroups = @(
    'openbb_core_extension',
    'openbb_provider_extension',
    'openbb_obbject_extension'
)
$script:mutationPerformed = $false
. (Join-Path $PSScriptRoot 'PyXll.Core.ps1')

function Expand-PortablePath {
    param([Parameter(Mandatory)][string] $Value)

    [regex]::Replace($Value, '%([^%]+)%', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $resolved = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
        if ([string]::IsNullOrWhiteSpace($resolved)) {
            throw "Environment variable '$($match.Groups[1].Value)' is required to expand '$Value'."
        }
        $resolved
    })
}

function Resolve-ContainedPath {
    param([string] $Root, [string] $Path, [string] $Label)

    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullPath = [IO.Path]::GetFullPath($Path)
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    if ($fullPath -ne $fullRoot -and -not $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label resolves outside the research root: $fullPath"
    }
    $fullPath
}

function Invoke-Uv {
    param([string] $WorkingDirectory, [string[]] $ArgumentList)

    $uv = Get-Command uv -CommandType Application -ErrorAction Stop | Select-Object -First 1
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = @(& $uv.Source @ArgumentList 2>&1 | ForEach-Object { [string] $_ })
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousPreference
        }
    } finally {
        Pop-Location
    }
    [pscustomobject]@{ ExitCode = $exitCode; Text = ($output -join "`n"); Arguments = @($ArgumentList) }
}

function Get-FileDigest {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-KernelInventory {
    param([hashtable] $Configuration)

    foreach ($portableRoot in @($Configuration.GlobalKernelRoots)) {
        $path = Expand-PortablePath ([string] $portableRoot)
        $scope = if ($portableRoot -match 'PROGRAMDATA') { 'system' } else { 'user' }
        $identities = if (Test-Path -LiteralPath $path -PathType Container) {
            @(Get-ChildItem -LiteralPath $path -Force -Directory -ErrorAction Stop | Sort-Object Name | Select-Object -ExpandProperty Name)
        } else { @() }
        [pscustomobject]@{ scope = $scope; path = $path; identities = @($identities) }
    }
}

function Get-ResearchProjects {
    param([hashtable] $Configuration, [string] $ResearchRoot)

    $projects = [Collections.Generic.List[object]]::new()
    $basePath = Resolve-ContainedPath $ResearchRoot (Join-Path $ResearchRoot $Configuration.Base.Path) 'Base project'
    $projects.Add([pscustomobject]@{
        Name = [string] $Configuration.Base.Name
        Kind = 'base'
        Path = $basePath
        Imports = @($Configuration.Base.RepresentativeImports)
        BaseSource = $null
        NotebookPackages = @()
    })

    $configured = @{}
    foreach ($overlay in @($Configuration.RequiredOverlays)) {
        $configured[[string] $overlay.Name] = $overlay
    }
    $overlayRoot = Resolve-ContainedPath $ResearchRoot (Join-Path $ResearchRoot $Configuration.OverlayRoot) 'Overlay root'
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($overlay in @($Configuration.RequiredOverlays)) { [void] $names.Add([string] $overlay.Name) }
    if (Test-Path -LiteralPath $overlayRoot -PathType Container) {
        Get-ChildItem -LiteralPath $overlayRoot -Directory -Force | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName 'pyproject.toml') -PathType Leaf
        } | ForEach-Object { [void] $names.Add($_.Name) }
    }
    foreach ($name in @($names | Sort-Object)) {
        $definition = if ($configured.ContainsKey($name)) { $configured[$name] } else { $null }
        $relative = if ($definition) { [string] $definition.Path } else { Join-Path $Configuration.OverlayRoot $name }
        $path = Resolve-ContainedPath $ResearchRoot (Join-Path $ResearchRoot $relative) "Overlay '$name'"
        $projects.Add([pscustomobject]@{
            Name = $name
            Kind = 'overlay'
            Path = $path
            Imports = if ($definition) { @($definition.RepresentativeImports) } else { @('quant_base') }
            BaseSource = if ($definition) { [string] $definition.BaseSource } else { '../../quant-base' }
            NotebookPackages = if ($definition) { @($definition.NotebookPackages) } else { @() }
        })
    }
    @($projects)
}

function New-Check {
    param([string] $Name, [string] $State, [string] $Detail)
    [pscustomobject]@{ name = $Name; state = $State; detail = $Detail }
}

function Get-PyXllPaths {
    param([object] $ProjectDefinition, [hashtable] $Configuration)

    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $licensePath = [string] $Configuration.PyXLL.LicensePath
    if (-not [IO.Path]::IsPathRooted($licensePath)) { $licensePath = Join-Path $repositoryRoot $licensePath }
    $roots = @($Configuration.PyXLL.PayloadRoots | ForEach-Object { [IO.Path]::GetFullPath((Expand-PortablePath ([string] $_))) })
    $xll = Find-PyXllPayload -Roots $roots
    $pythonw = Join-Path $ProjectDefinition.Path ($Configuration.EnvironmentName + '\Scripts\pythonw.exe')
    $webViewData = Expand-PortablePath ([string] $Configuration.PyXLL.Plotting.WebView2UserDataFolder)
    $notebookDirectory = if ($Configuration.PyXLL.ContainsKey('Jupyter')) {
        Expand-PortablePath ([string] $Configuration.PyXLL.Jupyter.NotebookDirectory)
    } else { $null }
    $jupyterRibbon = Join-Path $ProjectDefinition.Path ($Configuration.EnvironmentName + '\Lib\site-packages\pyxll_jupyter\resources\ribbon.xml')
    [pscustomobject]@{
        License = [IO.Path]::GetFullPath($licensePath)
        Roots = $roots
        Xll = $xll
        Config = if ($xll) { Join-Path (Split-Path -Parent $xll) 'pyxll.cfg' } else { $null }
        Pythonw = [IO.Path]::GetFullPath($pythonw)
        Excel = [IO.Path]::GetFullPath((Expand-PortablePath ([string] $Configuration.PyXLL.ExcelExecutable)))
        WebViewData = [IO.Path]::GetFullPath($webViewData)
        NotebookDirectory = if ($notebookDirectory) { [IO.Path]::GetFullPath($notebookDirectory) } else { $null }
        JupyterRibbon = [IO.Path]::GetFullPath($jupyterRibbon)
    }
}

function Get-PyXllState {
    param([object] $ProjectDefinition, [hashtable] $Configuration)

    $checks = [Collections.Generic.List[object]]::new()
    $paths = Get-PyXllPaths $ProjectDefinition $Configuration
    $manifest = Join-Path $ProjectDefinition.Path 'pyproject.toml'
    $manifestText = if (Test-Path -LiteralPath $manifest -PathType Leaf) { Get-Content -LiteralPath $manifest -Raw } else { '' }
    $packageDeclared = $manifestText -match '(?i)["'']pyxll(?:[=<>~!\[]|["''])'
    $checks.Add((New-Check 'pyxll-package' $(if ($packageDeclared) { 'compliant' } else { 'drift detected' }) $(if ($packageDeclared) { 'PyXLL is declared in the base environment.' } else { 'PyXLL is not declared in the base environment.' })))

    $licensePresent = $false
    $licenseKey = $null
    try {
        $licenseKey = Get-PyXllLicenseKey -Path $paths.License
        $licensePresent = $true
    } catch {
        $licensePresent = $false
        $licenseKey = $null
    }
    $checks.Add((New-Check 'pyxll-license' $(if ($licensePresent) { 'compliant' } else { 'blocked' }) $(if ($licensePresent) { 'A local PyXLL license is present (value redacted).' } else { 'The ignored local PyXLL license is missing or invalid.' })))

    $webViewPresent = Test-PyXllWebView2Runtime
    $checks.Add((New-Check 'pyxll-webview2' $(if ($webViewPresent) { 'compliant' } else { 'blocked' }) $(if ($webViewPresent) { 'Microsoft WebView2 Runtime is available.' } else { 'Microsoft WebView2 Runtime is required for interactive HTML plots.' })))

    if ($Configuration.PyXLL.ContainsKey('Jupyter') -and [bool] $Configuration.PyXLL.Jupyter.Enabled) {
        $sitePackages = Join-Path $ProjectDefinition.Path ($Configuration.EnvironmentName + '\Lib\site-packages')
        $integrationMetadata = Get-ChildItem -LiteralPath $sitePackages -Filter 'pyxll_jupyter-*.dist-info' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        $jupyterLabMetadata = Get-ChildItem -LiteralPath $sitePackages -Filter 'jupyterlab-*.dist-info' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        $integrationVersion = $null
        if ($integrationMetadata) {
            $metadataPath = Join-Path $integrationMetadata.FullName 'METADATA'
            if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
                $versionLine = Get-Content -LiteralPath $metadataPath | Where-Object { $_ -match '^Version:\s*(\S+)' } | Select-Object -First 1
                if ($versionLine -match '^Version:\s*(\S+)') { $integrationVersion = $Matches[1] }
            }
        }
        $integrationOk = $integrationVersion -eq [string] $Configuration.PyXLL.Jupyter.Version
        $checks.Add((New-Check 'pyxll-jupyter-package' $(if ($integrationOk) { 'compliant' } else { 'drift detected' }) $(if ($integrationOk) { "PyXLL Jupyter $integrationVersion is installed." } else { 'The declared PyXLL Jupyter integration is missing or has the wrong version.' })))
        $checks.Add((New-Check 'pyxll-jupyterlab' $(if ($jupyterLabMetadata) { 'compliant' } else { 'drift detected' }) $(if ($jupyterLabMetadata) { 'JupyterLab is installed in the OpenBB base environment.' } else { 'JupyterLab is missing from the OpenBB base environment.' })))

        $entryPointsPath = if ($integrationMetadata) { Join-Path $integrationMetadata.FullName 'entry_points.txt' } else { $null }
        $entryPointsText = if ($entryPointsPath -and (Test-Path -LiteralPath $entryPointsPath -PathType Leaf)) { Get-Content -LiteralPath $entryPointsPath -Raw } else { '' }
        $ribbonEntryPoint = $entryPointsText -match '(?ims)^\[pyxll\]\s*$.*?^\s*ribbon\s*='
        $checks.Add((New-Check 'pyxll-jupyter-ribbon' $(if ($ribbonEntryPoint) { 'compliant' } else { 'drift detected' }) $(if ($ribbonEntryPoint) { 'The PyXLL Jupyter ribbon entry point is available.' } else { 'The PyXLL Jupyter ribbon entry point is unavailable.' })))
    }

    if (-not $paths.Xll) {
        $checks.Add((New-Check 'pyxll-addin' 'drift detected' 'No installed PyXLL payload was found; use -ConfirmPyXllInstall for the explicit vendor workflow.'))
        $checks.Add((New-Check 'pyxll-architecture' 'drift detected' 'Architecture cannot be checked until the PyXLL payload and base environment exist.'))
        $checks.Add((New-Check 'pyxll-config' 'drift detected' 'The active PyXLL configuration is unavailable until the payload is installed.'))
        return @($checks)
    }

    $registered = @(Get-PyXllExcelAddIns)
    $active = @($registered | Where-Object { $_.Trim('"') -ieq $paths.Xll }).Count -gt 0
    $checks.Add((New-Check 'pyxll-addin' $(if ($active) { 'compliant' } else { 'drift detected' }) $(if ($active) { 'Excel loads the selected PyXLL add-in.' } else { 'Excel does not load the selected PyXLL add-in.' })))

    $xllArchitecture = Get-PortableExecutableArchitecture -Path $paths.Xll
    $pythonArchitecture = Get-PortableExecutableArchitecture -Path $paths.Pythonw
    $excelArchitecture = Get-PortableExecutableArchitecture -Path $paths.Excel
    $architectureOk = $xllArchitecture -and $pythonArchitecture -and $excelArchitecture -and
        $xllArchitecture -eq $pythonArchitecture -and $xllArchitecture -eq $excelArchitecture
    $checks.Add((New-Check 'pyxll-architecture' $(if ($architectureOk) { 'compliant' } else { 'blocked' }) $(if ($architectureOk) { "Excel, PyXLL, and Python are $xllArchitecture." } else { 'Excel, PyXLL, and base Python architectures are missing or incompatible.' })))

    $configOk = $false
    $jupyterConfigOk = -not ($Configuration.PyXLL.ContainsKey('Jupyter') -and [bool] $Configuration.PyXLL.Jupyter.Enabled)
    if ($paths.Config -and (Test-Path -LiteralPath $paths.Config -PathType Leaf)) {
        $configText = Get-Content -LiteralPath $paths.Config -Raw
        $configuredLicense = [regex]::Match($configText, '(?ims)^\[LICENSE\]\s*.*?^\s*key\s*=\s*(\S+)\s*$')
        $configOk = $configText -match ('(?im)^\s*executable\s*=\s*' + [regex]::Escape($paths.Pythonw) + '\s*$') -and
            $configText -match '(?im)^\s*plot_allow_html\s*=\s*1\s*$' -and
            $configText -match '(?im)^\s*plot_allow_svg\s*=\s*1\s*$' -and
            $configText -match '(?im)^\s*plot_allow_resize\s*=\s*1\s*$' -and
            $configText -match ('(?im)^\s*webview2_userdata_folder\s*=\s*' + [regex]::Escape($paths.WebViewData) + '\s*$') -and
            $configuredLicense.Success -and $configuredLicense.Groups[1].Value -ceq $licenseKey
        if ($Configuration.PyXLL.ContainsKey('Jupyter') -and [bool] $Configuration.PyXLL.Jupyter.Enabled) {
            $jupyterConfigOk = $configText -match '(?im)^\s*subcommand\s*=\s*lab\s*$' -and
                $configText -match '(?im)^\s*disable_ribbon\s*=\s*1\s*$' -and
                $configText -match '(?im)^\s*use_workbook_dir\s*=\s*1\s*$' -and
                $configText -match ('(?im)^\s*notebook_dir\s*=\s*' + [regex]::Escape($paths.NotebookDirectory) + '\s*$') -and
                $configText -notmatch '(?im)^\s*(?:modules\s*=\s*)?pyxll_jupyter\.pyxll\s*$' -and
                $configText -match ('(?im)^\s*ribbon\s*=\s*' + [regex]::Escape($paths.JupyterRibbon) + '\s*$') -and
                $configText -notmatch '(?im)^\s*(?:ribbon\s*=\s*)?(?:\./)?examples[/\\]ribbon[/\\]ribbon\.xml\s*$' -and
                $configText -notmatch '(?im)^\s*ignore_entry_points\s*=\s*1\s*$'
        }
    }
    $checks.Add((New-Check 'pyxll-config' $(if ($configOk) { 'compliant' } else { 'drift detected' }) $(if ($configOk) { 'PyXLL uses the base Python and all interactive plot settings; license value redacted.' } else { 'PyXLL configuration does not match the base Python and interactive plot policy.' })))
    if ($Configuration.PyXLL.ContainsKey('Jupyter') -and [bool] $Configuration.PyXLL.Jupyter.Enabled) {
        $checks.Add((New-Check 'pyxll-jupyter-config' $(if ($jupyterConfigOk) { 'compliant' } else { 'drift detected' }) $(if ($jupyterConfigOk) { 'The PyXLL JupyterLab ribbon configuration is enabled.' } else { 'The active PyXLL JupyterLab ribbon configuration is missing or drifted.' })))
    }
    @($checks)
}

function Invoke-PyXllReconciliation {
    param([object] $ProjectDefinition, [hashtable] $Configuration, [switch] $AllowInteractiveInstall)

    if (Get-Process -Name EXCEL -ErrorAction SilentlyContinue) {
        throw 'Close Excel before activating or configuring PyXLL.'
    }
    $paths = Get-PyXllPaths $ProjectDefinition $Configuration
    $licenseKey = Get-PyXllLicenseKey -Path $paths.License
    if (-not (Test-PyXllWebView2Runtime)) { throw 'Microsoft WebView2 Runtime is required before PyXLL reconciliation.' }
    if (-not (Test-Path -LiteralPath $paths.Pythonw -PathType Leaf)) { throw 'The OpenBB base pythonw.exe is missing after locked synchronization.' }

    if (-not $paths.Xll) {
        if (-not $AllowInteractiveInstall) {
            throw 'No PyXLL payload is installed. Re-run this direct command with -ConfirmPyXllInstall to start the vendor interactive installer.'
        }
        $python = Join-Path $ProjectDefinition.Path ($Configuration.EnvironmentName + '\Scripts\python.exe')
        Push-Location -LiteralPath $ProjectDefinition.Path
        try {
            & $python -m pyxll install ("--version=$([string] $Configuration.PyXLL.Version)")
            if ($LASTEXITCODE -ne 0) { throw 'The interactive PyXLL installer did not complete successfully.' }
        } finally { Pop-Location }
        $paths = Get-PyXllPaths $ProjectDefinition $Configuration
        if (-not $paths.Xll) { throw 'The interactive PyXLL installer completed without a discoverable pyxll.xll payload.' }
    }

    $xllArchitecture = Get-PortableExecutableArchitecture -Path $paths.Xll
    $pythonArchitecture = Get-PortableExecutableArchitecture -Path $paths.Pythonw
    $excelArchitecture = Get-PortableExecutableArchitecture -Path $paths.Excel
    if (-not $xllArchitecture -or -not $excelArchitecture -or $xllArchitecture -ne $pythonArchitecture -or $xllArchitecture -ne $excelArchitecture) {
        throw 'Excel, the PyXLL add-in, and OpenBB base Python architectures are incompatible.'
    }

    $registered = @(Get-PyXllExcelAddIns)
    if (@($registered | Where-Object { $_.Trim('"') -ieq $paths.Xll }).Count -eq 0) {
        $activate = Invoke-Uv $ProjectDefinition.Path @('run', '--frozen', '--no-sync', 'python', '-m', 'pyxll', 'activate', '--non-interactive', (Split-Path -Parent $paths.Xll))
        if ($activate.ExitCode -ne 0) { throw "PyXLL add-in activation failed: $($activate.Text)" }
        $script:mutationPerformed = $true
    }
    $jupyterSettings = $null
    if ($Configuration.PyXLL.ContainsKey('Jupyter') -and [bool] $Configuration.PyXLL.Jupyter.Enabled) {
        if ([string] $Configuration.PyXLL.Jupyter.RibbonMode -ne 'Explicit') {
            throw "Unsupported PyXLL Jupyter ribbon mode '$([string] $Configuration.PyXLL.Jupyter.RibbonMode)'."
        }
        $jupyterSettings = [ordered]@{
            use_workbook_dir = $(if ([bool] $Configuration.PyXLL.Jupyter.UseWorkbookDirectory) { '1' } else { '0' })
            notebook_dir = $paths.NotebookDirectory
            subcommand = [string] $Configuration.PyXLL.Jupyter.Subcommand
            qt = [string] $Configuration.PyXLL.Jupyter.Qt
            timeout = [string] $Configuration.PyXLL.Jupyter.TimeoutSeconds
            disable_ribbon = '1'
        }
    }
    Set-PyXllConfigurationFile -Path $paths.Config -PythonExecutable $paths.Pythonw -WebView2UserDataFolder $paths.WebViewData -LicenseKey $licenseKey -JupyterSettings $jupyterSettings -JupyterRibbonPath $paths.JupyterRibbon -UseExplicitJupyterRibbon
    $script:mutationPerformed = $true
}

function Get-OpenBbExtensionState {
    param([object] $ProjectDefinition, [hashtable] $Configuration)

    $reference = Join-Path $ProjectDefinition.Path $Configuration.OpenBB.ReferenceRelativePath
    if (-not (Test-Path -LiteralPath $reference -PathType Leaf)) {
        return (New-Check 'openbb-extensions' 'drift detected' "Generated OpenBB reference is missing: $reference")
    }
    $groups = @($Configuration.OpenBB.EntryPointGroups)
    foreach ($group in $groups) {
        if ($group -notin $supportedOpenBbEntryPointGroups) {
            return (New-Check 'openbb-extensions' 'blocked' "Unsupported OpenBB entry-point group: $group")
        }
    }
    $groupLiteral = ($groups | ForEach-Object { "'" + $_.Replace("'", "\'") + "'" }) -join ','
    $probe = "import json; from importlib.metadata import entry_points; groups=[$groupLiteral]; eps=entry_points(); print(json.dumps({g:sorted([e.name for e in eps.select(group=g)]) for g in groups},sort_keys=True))"
    $result = Invoke-Uv $ProjectDefinition.Path @('run', '--frozen', '--no-sync', 'python', '-B', '-c', $probe)
    if ($result.ExitCode -ne 0) {
        return (New-Check 'openbb-extensions' 'blocked' "Entry-point probe failed: $($result.Text)")
    }
    try { $inventory = $result.Text | ConvertFrom-Json -AsHashtable } catch {
        return (New-Check 'openbb-extensions' 'blocked' 'Entry-point probe did not return JSON.')
    }
    $referenceText = Get-Content -LiteralPath $reference -Raw
    $missing = @()
    foreach ($group in $groups) {
        foreach ($name in @($inventory[$group])) {
            if ($referenceText -notmatch [regex]::Escape([string] $name)) { $missing += "$group/$name" }
        }
    }
    if ($missing.Count -gt 0) {
        return (New-Check 'openbb-extensions' 'drift detected' "Generated OpenBB reference omits: $($missing -join ', ')")
    }
    New-Check 'openbb-extensions' 'compliant' 'Installed entry points match generated reference metadata.'
}

function Get-ProjectState {
    param([object] $Definition, [hashtable] $Configuration, [string] $ResearchRoot)

    $checks = [Collections.Generic.List[object]]::new()
    $manifest = Join-Path $Definition.Path 'pyproject.toml'
    $lock = Join-Path $Definition.Path 'uv.lock'
    $environment = Join-Path $Definition.Path $Configuration.EnvironmentName
    if (-not (Test-Path -LiteralPath $Definition.Path -PathType Container)) {
        $checks.Add((New-Check 'project-directory' 'blocked' "Missing project directory: $($Definition.Path)"))
    } else {
        $checks.Add((New-Check 'project-directory' 'compliant' $Definition.Path))
    }
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        $checks.Add((New-Check 'declaration' 'blocked' "Missing declaration: $manifest"))
    } else {
        $manifestText = Get-Content -LiteralPath $manifest -Raw
        $runtimeOk = $manifestText -match ('requires-python\s*=\s*"[^"\r\n]*' + [regex]::Escape($Configuration.Python))
        $checks.Add((New-Check 'runtime' $(if ($runtimeOk) { 'compliant' } else { 'drift detected' }) "Expected Python $($Configuration.Python)."))
        if ($Definition.Kind -eq 'base') {
            $missingDependencies = @($Configuration.Base.RequiredDependencies | Where-Object { $manifestText -notmatch ('(?i)["'']' + [regex]::Escape($_) + '([>=<~!\[]|["''])') })
            $checks.Add((New-Check 'base-dependencies' $(if ($missingDependencies.Count -eq 0) { 'compliant' } else { 'drift detected' }) $(if ($missingDependencies.Count -eq 0) { 'Required base dependencies are declared.' } else { "Missing: $($missingDependencies -join ', ')" })))
            if ($Configuration.ContainsKey('PyXLL') -and [bool] $Configuration.PyXLL.Enabled) {
                foreach ($pyxllCheck in @(Get-PyXllState $Definition $Configuration)) { $checks.Add($pyxllCheck) }
            }
        } else {
            $sourceMatch = [regex]::Match($manifestText, '(?m)^quant-base\s*=\s*\{[^\r\n]*path\s*=\s*"([^"]+)"')
            if (-not $sourceMatch.Success) {
                $checks.Add((New-Check 'base-relationship' 'blocked' 'The overlay has no relative quant-base source.'))
            } else {
                $sourceValue = $sourceMatch.Groups[1].Value
                $baseResolved = Resolve-ContainedPath $ResearchRoot (Join-Path $Definition.Path $sourceValue) "Overlay '$($Definition.Name)' base"
                $expectedBase = [IO.Path]::GetFullPath((Join-Path $ResearchRoot $Configuration.Base.Path))
                $relationshipOk = -not [IO.Path]::IsPathRooted($sourceValue) -and $baseResolved -eq $expectedBase
                $checks.Add((New-Check 'base-relationship' $(if ($relationshipOk) { 'compliant' } else { 'blocked' }) "$sourceValue -> $baseResolved"))
            }
            foreach ($package in @($Definition.NotebookPackages)) {
                if ($manifestText -notmatch [regex]::Escape($package)) {
                    $checks.Add((New-Check 'notebook-entry-point' 'drift detected' "Missing notebook package: $package"))
                }
            }
        }
    }
    if (-not (Test-Path -LiteralPath $lock -PathType Leaf)) {
        $checks.Add((New-Check 'lock' 'blocked' "Missing lock: $lock"))
    } elseif (Test-Path -LiteralPath $Definition.Path -PathType Container) {
        $lockCheck = Invoke-Uv $Definition.Path @('lock', '--check')
        $checks.Add((New-Check 'lock' $(if ($lockCheck.ExitCode -eq 0) { 'compliant' } else { 'drift detected' }) $(if ($lockCheck.ExitCode -eq 0) { 'Lock matches the declaration.' } else { $lockCheck.Text })))
    }
    if (-not (Test-Path -LiteralPath $environment -PathType Container)) {
        $checks.Add((New-Check 'environment' 'drift detected' "Missing generated environment: $environment"))
    } else {
        $syncCheck = Invoke-Uv $Definition.Path @('sync', '--check')
        $checks.Add((New-Check 'environment' $(if ($syncCheck.ExitCode -eq 0) { 'compliant' } else { 'drift detected' }) $(if ($syncCheck.ExitCode -eq 0) { 'Environment matches the project.' } else { $syncCheck.Text })))
        $imports = @($Definition.Imports | Where-Object { $_ })
        if ($imports.Count -gt 0) {
            $importCode = "import " + ($imports -join '; import ')
            $previousBytecode = $env:PYTHONDONTWRITEBYTECODE
            $previousOpenBb = $env:OPENBB_AUTO_BUILD
            $env:PYTHONDONTWRITEBYTECODE = '1'
            $env:OPENBB_AUTO_BUILD = 'false'
            try { $importCheck = Invoke-Uv $Definition.Path @('run', '--frozen', '--no-sync', 'python', '-B', '-c', $importCode) }
            finally {
                $env:PYTHONDONTWRITEBYTECODE = $previousBytecode
                $env:OPENBB_AUTO_BUILD = $previousOpenBb
            }
            $checks.Add((New-Check 'imports' $(if ($importCheck.ExitCode -eq 0) { 'compliant' } else { 'blocked' }) $(if ($importCheck.ExitCode -eq 0) { "Imported: $($imports -join ', ')" } else { $importCheck.Text })))
        }
        if ('openbb' -in $imports) { $checks.Add((Get-OpenBbExtensionState $Definition $Configuration)) }
    }
    $state = if (@($checks | Where-Object state -eq 'blocked').Count -gt 0) { 'blocked' }
        elseif (@($checks | Where-Object state -eq 'drift detected').Count -gt 0) { 'drift detected' }
        else { 'compliant' }
    [pscustomobject]@{
        name = $Definition.Name
        kind = $Definition.Kind
        path = $Definition.Path
        state = $state
        lockDigest = Get-FileDigest $lock
        checks = @($checks)
    }
}

function Get-EnvironmentStatus {
    param([hashtable] $Configuration, [string] $ResearchRoot, [object[]] $SelectedProjects, [string] $ResultMode)

    $states = @($SelectedProjects | ForEach-Object { Get-ProjectState $_ $Configuration $ResearchRoot })
    $baseState = @($states | Where-Object kind -eq 'base') | Select-Object -First 1
    if (-not $baseState) {
        $baseDefinition = @((Get-ResearchProjects $Configuration $ResearchRoot) | Where-Object Kind -eq 'base')[0]
        $baseState = Get-ProjectState $baseDefinition $Configuration $ResearchRoot
    }
    $overall = if (@($states | Where-Object state -eq 'blocked').Count -gt 0) { 'blocked' }
        elseif (@($states | Where-Object state -eq 'drift detected').Count -gt 0) { 'drift detected' }
        else { 'compliant' }
    [pscustomobject]@{
        schemaVersion = 1
        mode = $ResultMode
        checkedAtUtc = [DateTime]::UtcNow.ToString('o')
        researchRoot = $ResearchRoot
        state = $overall
        mutationPerformed = [bool] $script:mutationPerformed
        base = $baseState
        overlays = @($states | Where-Object kind -eq 'overlay')
        globalKernels = @(Get-KernelInventory $Configuration)
        blockers = @($states.checks | Where-Object state -eq 'blocked' | ForEach-Object detail)
        warnings = @($states.checks | Where-Object state -eq 'drift detected' | ForEach-Object detail)
    }
}

function Write-EnvironmentResult {
    param([object] $Result, [switch] $AsJson)
    if ($AsJson) {
        $Result | ConvertTo-Json -Depth 10 -Compress
        return
    }
    Write-Host "Quantitative research environment: $($Result.state)"
    Write-Host "Root: $($Result.researchRoot)"
    foreach ($projectState in @($Result.base) + @($Result.overlays)) {
        Write-Host "- $($projectState.kind) $($projectState.name): $($projectState.state)"
        foreach ($check in @($projectState.checks | Where-Object state -ne 'compliant')) {
            Write-Host "  $($check.name): $($check.detail)"
        }
    }
}

if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) { throw "Configuration not found: $ConfigurationPath" }
$configuration = Import-PowerShellDataFile -LiteralPath $ConfigurationPath
if ($configuration.SchemaVersion -ne 1) { throw "Unsupported quantitative research configuration schema: $($configuration.SchemaVersion)" }
$researchRoot = [IO.Path]::GetFullPath((Expand-PortablePath ([string] $configuration.Root)))
$allProjects = @(Get-ResearchProjects $configuration $researchRoot)
$selectedProjects = if ($Project -eq 'All') { $allProjects }
    elseif ($Project -eq 'Base') { @($allProjects | Where-Object Kind -eq 'base') }
    else { @($allProjects | Where-Object { $_.Name -eq $Project -and $_.Kind -eq 'overlay' }) }
if ($selectedProjects.Count -eq 0) { throw "Unknown quantitative research project: $Project" }

if ($Mode -eq 'Test') {
    $result = Get-EnvironmentStatus $configuration $researchRoot $selectedProjects $Mode
    Write-EnvironmentResult $result -AsJson:$Json
    if ($result.state -ne 'compliant') { exit 1 }
    exit 0
}

foreach ($definition in $selectedProjects) {
    $manifest = Join-Path $definition.Path 'pyproject.toml'
    $lock = Join-Path $definition.Path 'uv.lock'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf) -or -not (Test-Path -LiteralPath $lock -PathType Leaf)) {
        throw "Cannot reconcile '$($definition.Name)' without pyproject.toml and uv.lock."
    }
    $manifestDigest = Get-FileDigest $manifest
    $lockDigest = Get-FileDigest $lock
    $environment = Resolve-ContainedPath $definition.Path (Join-Path $definition.Path $configuration.EnvironmentName) 'Generated environment'
    if ((Split-Path -Leaf $environment) -ne $configuration.EnvironmentName) { throw "Unexpected generated environment path: $environment" }

    if ($Mode -eq 'Ensure') {
        $sync = Invoke-Uv $definition.Path @('sync', '--locked')
        if ($sync.ExitCode -ne 0) { throw "Locked sync failed for '$($definition.Name)': $($sync.Text)" }
        $script:mutationPerformed = $true
        $extensionState = Get-OpenBbExtensionState $definition $configuration
        if ($extensionState.state -eq 'drift detected') {
            $build = Invoke-Uv $definition.Path @('run', '--frozen', '--no-sync', 'openbb-build')
            if ($build.ExitCode -ne 0) { throw "OpenBB extension refresh failed for '$($definition.Name)': $($build.Text)" }
        }
        if ($definition.Kind -eq 'base' -and $configuration.ContainsKey('PyXLL') -and [bool] $configuration.PyXLL.Enabled) {
            Invoke-PyXllReconciliation $definition $configuration -AllowInteractiveInstall:$ConfirmPyXllInstall
        }
    } else {
        $backup = "$environment.pre-reinitialize-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff'))"
        if (Test-Path -LiteralPath $backup) { throw "Generated environment backup already exists: $backup" }
        $moved = $false
        try {
            if (Test-Path -LiteralPath $environment -PathType Container) {
                Move-Item -LiteralPath $environment -Destination $backup -ErrorAction Stop
                $moved = $true
            }
            $sync = Invoke-Uv $definition.Path @('sync', '--locked')
            if ($sync.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $environment -PathType Container)) {
                throw "Replacement environment creation failed for '$($definition.Name)': $($sync.Text)"
            }
            $probe = Invoke-Uv $definition.Path @('run', '--frozen', '--no-sync', 'python', '-B', '-c', "import " + (@($definition.Imports) -join '; import '))
            if ($probe.ExitCode -ne 0) { throw "Replacement environment validation failed for '$($definition.Name)': $($probe.Text)" }
            $script:mutationPerformed = $true
            if ($definition.Kind -eq 'base' -and $configuration.ContainsKey('PyXLL') -and [bool] $configuration.PyXLL.Enabled) {
                Invoke-PyXllReconciliation $definition $configuration -AllowInteractiveInstall:$ConfirmPyXllInstall
            }
            if ($moved -and (Test-Path -LiteralPath $backup -PathType Container)) {
                Remove-Item -LiteralPath $backup -Recurse -Force
            }
        } catch {
            if (Test-Path -LiteralPath $environment -PathType Container) { Remove-Item -LiteralPath $environment -Recurse -Force }
            if ($moved -and (Test-Path -LiteralPath $backup -PathType Container)) {
                Move-Item -LiteralPath $backup -Destination $environment
            }
            throw "Generated environment restore completed after failure: $($_.Exception.Message)"
        }
    }
    if ((Get-FileDigest $manifest) -ne $manifestDigest -or (Get-FileDigest $lock) -ne $lockDigest) {
        throw "Reconciliation changed the recorded declaration or lock for '$($definition.Name)'."
    }
}

$result = Get-EnvironmentStatus $configuration $researchRoot $selectedProjects $Mode
Write-EnvironmentResult $result -AsJson:$Json
if ($result.state -ne 'compliant') { exit 1 }
