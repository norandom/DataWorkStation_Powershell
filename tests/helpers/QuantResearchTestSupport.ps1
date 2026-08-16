Set-StrictMode -Version Latest

function Write-TestUtf8File {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $Content)

    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function New-QuantResearchFixture {
    param([Parameter(Mandatory)][string] $Root)

    $researchRoot = Join-Path $Root 'quant-research'
    $base = Join-Path $researchRoot 'quant-base'
    $thesis = Join-Path $researchRoot 'projects\thesis'
    [IO.Directory]::CreateDirectory((Join-Path $base 'src\quant_base')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $thesis 'src\thesis')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $thesis 'notebooks')) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $thesis '.venv\Lib\site-packages\openbb\assets')) | Out-Null

    Write-TestUtf8File (Join-Path $base 'pyproject.toml') @'
[project]
name = "quant-base"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["openbb>=4.7.2", "numpy>=2.0", "pandas>=2.0"]

[build-system]
requires = ["uv_build>=0.12.3,<0.13.0"]
build-backend = "uv_build"
'@
    Write-TestUtf8File (Join-Path $base 'uv.lock') 'version = 1'
    Write-TestUtf8File (Join-Path $base 'src\quant_base\__init__.py') '__version__ = "0.1.0"'
    Write-TestUtf8File (Join-Path $thesis 'pyproject.toml') @'
[project]
name = "thesis"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["quant-base"]

[tool.uv.sources]
quant-base = { path = "../../quant-base", editable = true }

[dependency-groups]
dev = ["jupyterlab>=4", "ipykernel>=6"]
'@
    Write-TestUtf8File (Join-Path $thesis 'uv.lock') 'version = 1'
    Write-TestUtf8File (Join-Path $thesis 'src\thesis\__init__.py') '__version__ = "0.1.0"'
    Write-TestUtf8File (Join-Path $thesis 'notebooks\analysis.ipynb') '{"cells":[],"metadata":{},"nbformat":4,"nbformat_minor":5}'
    Write-TestUtf8File (Join-Path $thesis 'dataset.csv') "x`n1"
    Write-TestUtf8File (Join-Path $thesis '.env.local') 'OPENBB_TOKEN=test-only-placeholder'
    Write-TestUtf8File (Join-Path $thesis '.venv\Lib\site-packages\openbb\assets\reference.json') '{"extensions":[]}'

    $kernelUser = Join-Path $Root 'kernels\user'
    $kernelSystem = Join-Path $Root 'kernels\system'
    [IO.Directory]::CreateDirectory($kernelUser) | Out-Null
    [IO.Directory]::CreateDirectory($kernelSystem) | Out-Null

    $configPath = Join-Path $Root 'quant-research.test.psd1'
    $escapedRoot = $researchRoot.Replace("'", "''")
    $escapedUser = $kernelUser.Replace("'", "''")
    $escapedSystem = $kernelSystem.Replace("'", "''")
    Write-TestUtf8File $configPath @"
@{
    SchemaVersion = 1
    Root = '$escapedRoot'
    Python = '3.12'
    EnvironmentName = '.venv'
    Base = @{ Name='quant-base'; Path='quant-base'; RequiredDependencies=@('openbb','numpy','pandas'); RepresentativeImports=@('quant_base') }
    OverlayRoot = 'projects'
    RequiredOverlays = @(@{ Name='thesis'; Path='projects\thesis'; BaseSource='../../quant-base'; RepresentativeImports=@('quant_base','thesis'); NotebookPackages=@('jupyterlab','ipykernel') })
    OpenBB = @{ EntryPointGroups=@('openbb_core_extension','openbb_provider_extension','openbb_obbject_extension'); ReferenceRelativePath='.venv\Lib\site-packages\openbb\assets\reference.json'; RepresentativeProviders=@() }
    GlobalKernelRoots = @('$escapedUser','$escapedSystem')
    ProtectedPatterns = @('*.ipynb','*.csv','.env*','data','exports')
    Relocation = @{ Source='$escapedRoot'; Target='$(Join-Path $Root 'relocated')'; ExpectedFileSystem='NTFS'; RequireLocalFixed=`$true; ReserveBytes=0; ExecutionEnabled=`$false }
}
"@

    $bin = Join-Path $Root 'bin'
    [IO.Directory]::CreateDirectory($bin) | Out-Null
    $fakeUv = Join-Path $bin 'uv.cmd'
    Write-TestUtf8File $fakeUv @'
@echo off
if not "%QUANT_UV_LOG%"=="" echo %CD%^|%*>>"%QUANT_UV_LOG%"
if "%QUANT_UV_FAIL_SYNC%"=="1" if "%1"=="sync" exit /b 9
if "%1"=="lock" if not exist uv.lock echo version = 1>uv.lock
if "%1"=="sync" if not exist .venv\Lib\site-packages\openbb\assets mkdir .venv\Lib\site-packages\openbb\assets
if "%1"=="sync" if not exist .venv\Lib\site-packages\openbb\assets\reference.json echo {"extensions":[]}>.venv\Lib\site-packages\openbb\assets\reference.json
echo %* | findstr /C:"entry_points" >nul && echo {"openbb_core_extension":[],"openbb_provider_extension":[],"openbb_obbject_extension":[]}
exit /b 0
'@

    [pscustomobject]@{
        Root = $researchRoot
        Base = $base
        Thesis = $thesis
        Config = $configPath
        Bin = $bin
        KernelUser = $kernelUser
        KernelSystem = $kernelSystem
        Protected = @(
            (Join-Path $thesis 'notebooks\analysis.ipynb'),
            (Join-Path $thesis 'dataset.csv'),
            (Join-Path $thesis '.env.local')
        )
    }
}

function Get-TestTreeDigest {
    param([Parameter(Mandatory)][string] $Path)

    $records = Get-ChildItem -LiteralPath $Path -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Path, $_.FullName)
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$relative|$($_.Length)|$hash"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Invoke-TestPowerShellScript {
    param([Parameter(Mandatory)][string] $Path, [string[]] $ArgumentList = @(), [hashtable] $Environment = @{})

    $previous = @{}
    foreach ($name in $Environment.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, [string] $Environment[$name], 'Process')
    }
    try {
        $text = @(& (Get-Command pwsh).Source -NoLogo -NoProfile -File $Path @ArgumentList 2>&1 | ForEach-Object { [string] $_ }) -join "`n"
        [pscustomobject]@{ ExitCode = $LASTEXITCODE; Text = $text }
    } finally {
        foreach ($name in $Environment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
        }
    }
}
