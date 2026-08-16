# Quantitative Research Configuration Contract

`config/quant-research.psd1` is portable public configuration with this logical shape:

| Field | Contract |
|---|---|
| `SchemaVersion` | Integer `1`. |
| `Root` | `%USERPROFILE%\Source\quant-research`; expanded only at runtime. |
| `Python` | Supported runtime line, initially `3.12`. |
| `EnvironmentName` | Generated environment directory, `.venv`. |
| `Base` | Name, relative path, required dependencies, declaration/lock names, and import probes. |
| `OverlayRoot` | Relative path `projects`. |
| `RequiredOverlays` | Initially the thesis overlay and its expected notebook/dev requirements. |
| `OpenBB` | Entry-point groups, reference metadata location, and representative provider/router probes. |
| `GlobalKernelRoots` | Portable user and system Jupyter kernel locations. |
| `ProtectedPatterns` | Notebook, source, data, export, secret, and credential patterns excluded from ownership. |
| `Relocation` | Portable source, default `D:\Source` target, local/NTFS requirements, reserve policy, and `ExecutionEnabled = $false`. |

Additional user overlays are discovered from direct children of the configured overlay root that
contain both a project declaration and a lock. Discovery never recursively adopts arbitrary Python
projects elsewhere in Source.

Configuration may require a package or import but cannot remove overlay-owned dependencies. Local
credentials, provider keys, datasets, exports, notebook outputs, or expanded workstation-specific
paths are not valid public configuration values.
