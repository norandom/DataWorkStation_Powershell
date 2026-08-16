@{
    SchemaVersion = 1
    Python = '3.12'
    BaseName = 'quant-base'
    ThesisName = 'thesis'
    ThesisBaseSource = '../../quant-base'
    BaseDependencies = @('openbb', 'numpy', 'pandas')
    NotebookPackages = @('jupyterlab', 'ipykernel')
    ProtectedFiles = @('notebooks/analysis.ipynb', 'dataset.csv', '.env.local')
}
