# Research: Quantitative Research Environment

## Base package and independent overlays

**Decision**: Keep `quant-base` as an installable library project. Give every overlay its own
`pyproject.toml`, `uv.lock`, and `.venv`, and reference the base through a relative editable path in
`tool.uv.sources`. Preserve the complete research tree in one version-control boundary so a thesis
result can identify the exact base revision it used.

**Rationale**: Python virtual environments do not inherit from other virtual environments. A path
dependency provides logical inheritance of code and declared requirements while each overlay owns
its exact resolution. Relative paths remain valid when the complete tree moves. The shared uv cache
avoids repeated downloads.

**Alternatives considered**: Nested virtual environments were rejected as unsupported. A uv
workspace was rejected because members share a lock and environment. Repeating common requirements
in every overlay was rejected because the copies drift independently.

Sources:

- https://docs.astral.sh/uv/concepts/projects/dependencies/
- https://docs.astral.sh/uv/concepts/projects/workspaces/
- https://docs.astral.sh/uv/concepts/projects/layout/
- https://docs.astral.sh/uv/concepts/cache/

## Observational status and explicit reconciliation

**Decision**: Use `uv lock --check` to compare declarations with the lock and `uv sync --check` to
compare an existing environment with the project. Run representative processes with
`uv run --frozen --no-sync` so status never relocks or synchronizes. Reconciliation uses
`uv sync --locked`, which may create or exact-sync `.venv` but refuses to alter the reviewed lock.
Dependency changes remain separate, reviewed `uv add` or `uv remove` operations.

**Rationale**: Bare `uv run` can automatically lock and synchronize. The selected flags give Test a
read-only boundary and Ensure a narrow generated-state boundary.

**Alternatives considered**: Importing with the system Python was rejected because it does not prove
the overlay state. Bare `uv run` and `uv sync` were rejected for observation because they can write.

Sources:

- https://docs.astral.sh/uv/concepts/projects/sync/
- https://docs.astral.sh/uv/reference/cli/

## Project-local Jupyter

**Decision**: Declare JupyterLab and ipykernel in each notebook overlay's development group and
launch with `uv run --locked jupyter lab`. Never run `ipython kernel install --user`. Status and
smoke tests snapshot `%APPDATA%\jupyter\kernels` and `%PROGRAMDATA%\jupyter\kernels`; an
environment-local kernelspec is allowed.

**Rationale**: The notebook server and default Python kernel then execute in the overlay environment
without accumulating global user or system kernels. Editors can select `.venv\Scripts\python.exe`
directly.

**Alternatives considered**: A central Jupyter installation with a named kernelspec for every
overlay was rejected because it recreates the kernel-management problem. An ephemeral Jupyter
overlay is supported but was not selected because the thesis has a reviewed JupyterLab version.

Sources:

- https://docs.astral.sh/uv/guides/integration/jupyter/
- https://jupyter-client.readthedocs.io/en/stable/kernels.html
- https://jupyterlab.readthedocs.io/en/stable/getting_started/starting.html

## OpenBB extension state

**Decision**: After an explicit extension/provider add, remove, or upgrade, reconciliation runs
`openbb-build` and verifies declared providers and routers in a fresh process. Observational imports
set `OPENBB_AUTO_BUILD=false` in only the child process and compare installed extension entry points
with the built reference metadata before importing representative routes.

**Rationale**: OpenBB requires regenerated static assets after extension changes, while the default
first import may auto-build and write into the environment. Disabling auto-build preserves the Test
boundary; explicit reconciliation owns the refresh.

**Alternatives considered**: Running `openbb-build` during Test was rejected because it forces a
write. Treating a successful `from openbb import obb` as complete verification was rejected because
it does not prove that declared extensions are represented in the built inventory.

Sources:

- https://docs.openbb.co/odp/python/basic_usage
- https://docs.openbb.co/odp/python/extensions/providers
- https://docs.openbb.co/odp/python/developer/architecture_overview
- https://github.com/OpenBB-finance/OpenBB/blob/develop/openbb_platform/core/openbb_core/env.py

## Workstation integration boundary

**Decision**: Add one opt-in `QuantResearchEnvironment` desired-state module depending on the
managed Packages and PowerShellProfile prerequisites. Its state script owns only portable
declarations and generated environments under the configured research root. Separate human
commands own overlay creation and notebook launch. A separate relocation command owns the future
Source migration and is never selected by the default workstation run.

**Rationale**: This follows the repository's config/script/module/test pattern while keeping a
one-time destructive migration out of routine environment reconciliation. `%USERPROFILE%`-relative
configuration is portable and does not commit one workstation's expanded absolute path.

**Alternatives considered**: Making research packages global workstation packages was rejected
because project locks would lose ownership. Adding relocation to the quant Ensure path was rejected
because it broadens an ordinary repair into a drive-level cutover.

## Relocation authorization model

**Decision**: Model relocation as `Plan`, separately authorized `Prepare`, and separately confirmed
`Commit`. Plan is read-only. Prepare copies and verifies without renaming or linking. Commit is bound
to the exact source, target, backup name, verification manifest digest, copy log, and timestamp from
a fresh verified preparation.

**Rationale**: A failed copy leaves the original Source tree authoritative. A stale plan or a source
change cannot be promoted into a cutover. Ordinary quant setup, Test, Ensure, project creation, and
notebook launch never invoke relocation.

**Alternatives considered**: One cross-volume move command was rejected because it couples copying
with removal. Creating the junction before copy verification was rejected because it obscures the
authoritative tree.

## Relocation filesystem gates

**Decision**: Require the source to be a normal directory and the destination to be absent on a
healthy, writable, local fixed NTFS volume with sufficient free space plus reserve. Reject equal or
nested paths, backup-name conflicts, EFS files without an approved procedure, and unknown, broken,
cyclic, or destination-pointing reparse points. Inventory links without following them.

**Rationale**: Directory junctions support different local volumes, but network volumes and
unclassified reparse points create unsupported or recursive behavior. A junction path must be
path-free when created.

**Alternatives considered**: A directory symbolic link was unnecessary for the selected local
volumes. Blind recursive traversal or copying every junction was rejected because it can duplicate
trees, retain stale targets, or create cycles.

Sources:

- https://learn.microsoft.com/windows/win32/fileio/hard-links-and-junctions
- https://learn.microsoft.com/windows/win32/fileio/reparse-points
- https://learn.microsoft.com/windows/win32/vss/junction-points
- https://learn.microsoft.com/powershell/module/storage/get-volume
- https://learn.microsoft.com/powershell/module/microsoft.powershell.management/get-childitem

## Copy and verification policy

**Decision**: Prepare uses a non-purging Robocopy `/E` copy with bounded retries, logging outside
both trees, junction exclusion, and reviewed link handling. It never uses `/MOVE`, `/MOV`, `/PURGE`,
or mutating `/MIR`. Initial copy accepts only exit codes 0 or 1. Verification requires quiescence, a
repeat copy, a `/MIR /L` convergence audit with exit code 0, relative-path SHA-256/length equality,
empty-directory and approved-link equality, and repository status plus object-integrity checks.

**Rationale**: Microsoft defines Robocopy codes below 8 as non-failures, but codes 2 through 7 still
describe extra or mismatched state that this guarded migration must review. Copy success alone is
not content or repository integrity evidence.

**Alternatives considered**: `/MIR` was rejected for the mutating copy because it includes `/PURGE`.
`/COPYALL` was rejected as the default because owner/auditing preservation can require a broader
privilege boundary; `/COPY:DATS` is sufficient unless a separate review says otherwise.

Sources:

- https://learn.microsoft.com/windows-server/administration/windows-commands/robocopy
- https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-filehash
- https://git-scm.com/docs/git-status
- https://git-scm.com/docs/git-fsck

## Cutover and rollback

**Decision**: Commit runs outside Source after active-use checks and fresh verification. It renames
the original to `Source.pre-junction-<timestamp>` without force, verifies the backup, creates the
junction, and checks its type, exact target, and representative reads. If cutover validation fails,
it removes only the exact expected junction and renames the backup to Source. Neither tree is
recursively deleted; backup cleanup is a later decision.

**Rationale**: A same-volume rename is recoverable and precedes creation of the alias. The operator
always retains at least one readable original or verified copy.

**Alternatives considered**: Deleting the original after copying, using `-Force`, and automatic
backup cleanup were rejected as unrecoverable or overly broad.

Sources:

- https://learn.microsoft.com/powershell/module/microsoft.powershell.management/rename-item
- https://learn.microsoft.com/powershell/module/microsoft.powershell.management/new-item
- https://learn.microsoft.com/windows-server/administration/windows-commands/mklink
- https://learn.microsoft.com/sysinternals/downloads/handle

## Environment recreation after relocation

**Decision**: Treat declared `.venv` directories as generated and exclude only their exact approved
paths from the relocation copy. After junction validation, access projects through the familiar C:
path, run `uv lock --check`, recreate with `uv sync --locked`, and repeat relationship, import,
OpenBB, Jupyter, and global-kernel checks.

**Rationale**: Python virtual environments are non-portable because installed scripts contain
absolute interpreter paths. Locks and declarations, not copied environments, are the recovery
source.

**Alternatives considered**: Copying `.venv` or relying on the junction to mask embedded paths was
rejected as unsupported and fragile.

Sources:

- https://docs.python.org/3/library/venv.html
- https://docs.astral.sh/uv/concepts/projects/layout/
- https://docs.astral.sh/uv/reference/cli/#uv-sync

## PyXLL package, payload, and activation

**Decision**: Declare `pyxll`, `plotly`, and `kaleido` in `quant-base`, but treat the downloaded
PyXLL payload, Excel add-in registration, and active `pyxll.cfg` as machine-local generated state.
Use the official `python -m pyxll install` workflow only behind an explicit first-install switch;
activate an already installed payload non-interactively during reviewed reconciliation.

**Rationale**: The Python package belongs to the OpenBB runtime requested by the user. The vendor
installer collects first-time information and terms interactively, so ordinary desired-state runs
must not imply consent. Activation can be deterministic after the payload exists.

Sources:

- https://www.pyxll.com/docs/userguide/installation/firsttime.html
- https://www.pyxll.com/docs/userguide/installation/cli.html

## PyXLL configuration and secret boundary

**Decision**: Keep the key in an ignored root `.licenses.yaml` with a bounded `pyxll.key` field.
Render a machine-local config that selects `quant-base\.venv\Scripts\pythonw.exe`, preserves
unmanaged sections, enables HTML/SVG/resizable plots, assigns a WebView2 data directory, and appends
`[LICENSE]` last. Compare only presence or keyed equality; never return the value.

**Rationale**: PyXLL supports a license key in its config, and its plotting integration uses an
embedded WebView2 control for interactive Plotly figures. A single redacted boundary keeps the
portable repository useful without treating the entitlement as desired-state source.

Sources:

- https://www.pyxll.com/docs/userguide/config/license.html
- https://www.pyxll.com/docs/userguide/config/pyxll.html
- https://www.pyxll.com/docs/userguide/plotting/index.html
- https://www.pyxll.com/docs/userguide/plotting/plotly.html

## Embedded Jupyter ribbon

**Decision**: Lock `pyxll-jupyter==0.7.1` and JupyterLab 4 or later in `quant-base`. Verify the
package's `pyxll` module/ribbon entry points, but load its installed ribbon XML explicitly and set
`disable_ribbon = 1` so its automatic ribbon entry point does not inject a second copy. Remove the
installer example ribbon from the active ribbon list because it has the same `pyxll` tab ID and
takes ownership of the merged tab label. Render the remaining `[JUPYTER]` policy with
`subcommand = lab`, saved-workbook directory preference, PySide6, and the research root as the
fallback directory.

**Rationale**: Installing PyXLL alone does not supply the Jupyter action. The integration package
owns the ribbon resource and runs its kernel inside Excel's existing PyXLL interpreter, so keeping
it in the same OpenBB environment is required for consistent imports and Excel magic functions.
The installed package remains the source of callbacks and ribbon XML, while explicit composition
makes ribbon construction deterministic in the installed PyXLL build. Disabling only automatic
ribbon injection prevents duplicate IDs; the module entry point and explicit callback imports remain
available. Configuration normalization also prevents the misleading installer-example label.

Sources:

- https://pypi.org/project/pyxll-jupyter/0.7.1/
- https://www.pyxll.com/docs/videos/pyxll-jupyter.html
