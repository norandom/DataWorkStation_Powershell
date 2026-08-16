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
            'numpy'
            'openbb'
            'pandas'
            'polars'
            'pyarrow'
            'scipy'
            'statsmodels'
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
