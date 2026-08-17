@{
    SchemaVersion = 1
    Root = '%USERPROFILE%\Source\quant-research'
    Python = '3.12'
    EnvironmentName = '.venv'
    Base = @{
        Name = 'quant-base'
        Path = 'quant-base'
        Declaration = 'pyproject.toml'
        Lock = 'uv.lock'
        RequiredDependencies = @(
            'duckdb'
            'jupyterlab'
            'numpy'
            'openbb'
            'pandas'
            'plotly'
            'polars'
            'pyarrow'
            'pyxll'
            'pyxll-jupyter'
            'scipy'
            'statsmodels'
            'kaleido'
        )
        RepresentativeImports = @('quant_base', 'openbb', 'numpy', 'pandas')
    }
    OverlayRoot = 'projects'
    RequiredOverlays = @(
        @{
            Name = 'thesis'
            Path = 'projects\thesis'
            BaseSource = '../../quant-base'
            RepresentativeImports = @('quant_base', 'thesis', 'openbb')
            NotebookPackages = @('jupyterlab', 'ipykernel')
        }
    )
    OpenBB = @{
        EntryPointGroups = @(
            'openbb_core_extension'
            'openbb_provider_extension'
            'openbb_obbject_extension'
        )
        ReferenceRelativePath = '.venv\Lib\site-packages\openbb\assets\reference.json'
        RepresentativeProviders = @()
    }
    PyXLL = @{
        Enabled = $true
        Version = '5.12.4'
        LicensePath = '.licenses.yaml'
        ExcelExecutable = '%ProgramFiles%\Microsoft Office\Root\Office16\EXCEL.EXE'
        PayloadRoots = @(
            '%LOCALAPPDATA%\Programs\PyXLL'
            '%LOCALAPPDATA%\PyXLL'
            '%APPDATA%\PyXLL'
        )
        Plotting = @{
            AllowHtml = $true
            AllowSvg = $true
            AllowResize = $true
            WebView2UserDataFolder = '%LOCALAPPDATA%\PyXLL\WebView2'
        }
        Jupyter = @{
            Enabled = $true
            Version = '0.7.1'
            Subcommand = 'lab'
            UseWorkbookDirectory = $true
            NotebookDirectory = '%USERPROFILE%\Source\quant-research'
            Qt = 'PySide6'
            TimeoutSeconds = 60
            RibbonMode = 'Explicit'
        }
    }
    GlobalKernelRoots = @(
        '%APPDATA%\jupyter\kernels'
        '%PROGRAMDATA%\jupyter\kernels'
    )
    ProtectedPatterns = @(
        '*.ipynb'
        '*.csv'
        '*.parquet'
        '*.feather'
        '.env*'
        '*credential*'
        '*secret*'
        'data'
        'datasets'
        'exports'
        'output'
        'outputs'
    )
    Relocation = @{
        Source = '%USERPROFILE%\Source'
        Target = 'D:\Source'
        ExpectedFileSystem = 'NTFS'
        RequireLocalFixed = $true
        ReserveBytes = 10737418240
        ExecutionEnabled = $false
    }
}
