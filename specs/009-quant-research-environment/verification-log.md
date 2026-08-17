# Verification Log: Quantitative Research Environment

## Baseline

- Tasks gate: `ears-sdd validate --phase tasks` passed with 22 requirements, zero errors, and zero warnings on 2026-08-16.
- Specification-quality checklist: 16 checked, zero unchecked.
- Existing base and thesis: `uv lock --check` and `uv sync --check` passed before implementation.
- Existing thesis base source: relative editable `../../quant-base`.
- Existing global project kernels: none under the configured user and system roots before implementation.
- Production command baseline: expected red because the four feature scripts and portable configuration did not yet exist.

This log records bounded implementation evidence only. It never authorizes or performs Source relocation.

## US1 thesis workflow

- `BaseDeclaration`, `LockReproducibility`, `RelativeBaseRelationship`, `NotebookEntryPoint`, and `KernelRegistryIsolation` passed.
- The existing thesis status was compliant with a relative `../../quant-base` relationship and representative `quant_base`, `thesis`, and `openbb` imports.
- `Start-QuantResearchNotebook.ps1 -Project thesis -JupyterArguments '--version'` returned JupyterLab `4.6.3` without changing either global kernel inventory.
- The standalone base correctly reported stale OpenBB generated extension metadata as drift; observational status did not rebuild it.

## US2 overlay workflow

- `OverlayIsolation`, `OverlayMutationIsolation`, and the overlay portion of `FailureAtomicity` passed.
- A disposable `event-study` plan produced no destination, then explicit `-Run` created an independent manifest, lock, and `.venv` through three deterministic uv calls.
- The disposable base manifest digest remained unchanged; no operation targeted the real research tree.

## US3 maintenance workflow

- `OutputParity`, `ObservationalStatus`, `OpenBbExtensions`, `FailureAtomicity`, `ReconciliationScope`, `UserContentPreservation`, `CredentialBoundary`, and `FocusedBoundary` passed.
- Repeated disposable Test returned `compliant`, `mutationPerformed=false`, and an identical complete-tree digest.
- Disposable Ensure and Reinitialize returned zero while notebook, CSV, and `.env.local` hashes remained unchanged.
- An injected locked-sync failure returned nonzero and restored the previous `.venv` with an unchanged sentinel hash.
- The workstation plan resolves `PowerShell7`, `Packages`, and `PowerShellProfile` before the opt-in, non-privileged, non-destructive `QuantResearchEnvironment` module.

## US4 deferred relocation workflow

- `RelocationNonMutation`, `RelocationPlanContract`, `RelocationGuard`, and `MovedRootRebuild` passed.
- A suitable disposable plan returned schema-valid JSON with `planOnly=true`, `executionAvailable=false`, `mutationPerformed=false`, an unchanged source digest, and no target directory.
- A disposable complete research tree was moved only within the test temporary directory after generated environments were removed. `Reinitialize -Project All` recreated both environments from locks, retained `../../quant-base`, returned compliant, and left kernel inventory unchanged.
- No command ran against the real `C:\Users\mariu\Source` or `D:\Source`. Future backup-before-junction behavior remains manually deferred to a separately authorized feature.

## Final gates

- Focused runner: 22 sections, 173 assertions, zero failures, including disposable overlay creation, observational tree hashing, failed-rebuild rollback, relocation-plan schema validation, and moved-root recovery.
- Managed Pester 6.1.0 adapter: 22 passed, zero failed, parallel PowerShell 7 lane.
- Pester dependency repair: the declared shared `Documents\WindowsPowerShell\Modules` path is now explicitly prepended by the desired-state and test runners, so PowerShell 7 and Windows PowerShell both resolve 6.1.0.
- Workstation catalog checks: Modules, ModulePlanning, and Capabilities passed after adding the opt-in module and route.
- `lint-powershell`: 166 files passed.
- Tricky capability output: human and JSON forms parsed and contained `quant-research-environment`.
- `uv run --group docs mkdocs build --strict`: passed.
- `ears-sdd validate --phase final`: 22 requirements, zero errors, zero warnings.
- `git diff --check`: passed. The working tree remains uncommitted for review.

## US5 PyXLL Excel integration

- Spec, plan, and tasks gates passed with 30 requirements before implementation. The existing 16-item requirements checklist remained fully checked.
- Six focused selectors were observed red before production changes: declaration, status, activation, license boundary, interactive plots, and failure atomicity.
- The external `quant-base` declaration and lock now resolve PyXLL 5.12.4, Plotly 6.9.0, and Kaleido 1.3.0 in the OpenBB `.venv`.
- The local license store is ignored and untracked. The tracked sample has an empty value; tests use a runtime-generated fixture value and scan tracked files without reading the real entitlement into output.
- Live observational status reports the x64 Excel/PyXLL/Python match, registered add-in, base `pythonw.exe`, WebView2 runtime, HTML/SVG/resizing settings, matching local license, synchronized lock/environment, imports, and OpenBB extension inventory as compliant.
- The PyXLL CLI's non-interactive status also reports version 5.12.4, the installed add-in/config locations, and matching 64-bit Excel/Python.
- Focused runner: 28 sections, 752 assertions, zero failures. Managed Pester 6.1.0 adapter: 28 passed, zero failed, parallel PowerShell 7 lane.
- `ears-sdd validate --phase final`: 30 requirements, zero errors, zero warnings. `lint-powershell`: 203 files passed. Strict MkDocs, Tricky human/JSON capability routing, module plan human/JSON, and `git diff --check` passed.
- The managed PowerShell 7 and Windows PowerShell profile components were reconciled and retested so the first-install switch is available in new shells.

## US5 PyXLL Jupyter ribbon correction

- Live diagnosis found a compliant PyXLL add-in but no `pyxll-jupyter`, Notebook, or JupyterLab distribution in the OpenBB environment; the active config had no Jupyter policy.
- `PyXllJupyterRibbon` was observed red before implementation. REQ-031 through REQ-033 then passed the spec, plan, tasks, and traceability gates.
- The base declaration and lock now include `pyxll-jupyter==0.7.1` and JupyterLab 4.6.3; the resolved integration also supplies Notebook 7.6.2, PySide6 6.11.1, and pywin32 312.
- Live status verifies the exact integration version, JupyterLab distribution, package-provided `pyxll` ribbon entry point, and enabled JupyterLab settings without exposing the license.
- Direct imports of the ribbon entry points, JupyterLab, Qt WebEngine, and win32com passed from the OpenBB interpreter.
- Final gates passed with 33 requirements, 29 Pester cases, 776 focused assertions, 203 linted PowerShell files, strict documentation, Tricky human/JSON routing, clean diff checks, and observationally compliant live state.
- A subsequent visual check showed only the installer example label. Package and ribbon inspection proved that the installer XML and Jupyter XML share the same `pyxll` tab ID; loading both automatic and explicit Jupyter XML then produced duplicate control IDs and headless Excel processes. Entry-point-only construction was not stable after removing the last configured ribbon. The corrected policy loads exactly one explicit package XML, disables only its automatic ribbon injection, and removes the colliding example ribbon. The package intentionally renders one split button with embedded/browser actions plus a cell context-menu action.
- After the approved termination of five headless/open-dialog Excel instances, live reconciliation produced exactly one explicit package ribbon, disabled automatic ribbon injection, and excluded the example ribbon. Two consecutive operator-observed Excel startups displayed the Jupyter button; the corresponding PyXLL startups contained no duplicate-ID error.
