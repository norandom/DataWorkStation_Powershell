# Native forensic tool lifecycle

The runtime and build paths are deliberately separate. Operators install a
reviewed release package; they do not compile forensic software during setup or
ordinary update.

This page covers the lightweight, attributable `ewf-verify` package. The optional
[Autopsy Windows forensic workstation](autopsy.md) is a separate GUI module with its own official
MSI, matched Sleuth Kit command suite, embedded patched libewf runtime, and Defender boundary. It
does not replace this verifier or its read-only report contract.

## Observe or install the approved package

```powershell
pwsh -NoProfile -File .\scripts\Set-NativeForensicToolsState.ps1 -Mode Plan
pwsh -NoProfile -File .\scripts\Set-NativeForensicToolsState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeForensicTools
```

`Plan` and `Test` are observational. `Ensure` is the explicit state change. It
accepts exactly one `Approved` `ewfverify` record, verifies the release asset
size, package SHA-256 and attestation, rejects unsafe or unexpected archive
paths, checks every internal size and SHA-256, stages a versioned per-user
directory, and atomically commits it. A failed post-commit check restores the
previous installation.

Possible states are `Absent`, `Compliant`, `Drifted`, and `Unapproved`.
Verification refuses to run unless the state is compliant, and repeats the
installed-file check immediately before native invocation.

## Catalog and package boundary

`config/forensic-builds/` pins build inputs: upstream source and detached
signature, the isolated signer key/fingerprint, standalone native Windows
GnuPG identity, converter commit, MSVC toolchain, architecture, SDK, and build
arguments. `config/forensic-tools.psd1` is the independent runtime trust anchor.
It pins release tag, asset name, size, package SHA-256, internal file hashes,
source/build identity, parser profile, license, certification, and review state.

The package contains only:

- `ewfverify.exe`, `libewf.dll`, and `zlib.dll`;
- manifest and SHA-256 inventory;
- libewf, zlib, and bzip2 license texts;
- SPDX SBOM and build provenance.

bzip2 remains a pinned source/license input but is not shipped because the
observed Windows runtime imports do not require it. Acquisition, mounting,
export, and recovery tools remain out of scope.

## Build and certify a candidate

These are maintainer operations. They are not part of `update` or module Ensure.
Review the plan locally before manually dispatching the full-SHA-pinned Windows
workflow:

```powershell
pwsh -NoProfile -File .\scripts\Build-NativeForensicTool.ps1 `
  -BuildRecord .\config\forensic-builds\ewfverify-20231119-b1.psd1 `
  -Plan -Json

gh workflow run forensic-tool-build.yml `
  -f build_record=config/forensic-builds/ewfverify-20231119-b1.psd1
```

The workflow builds on native Windows, verifies the detached source signature
with an isolated keyring, checks AMD64 PE imports, assembles the allowlisted
package, runs the seven-case benign certification corpus in Windows PowerShell
5.1 and PowerShell 7, creates an attestation, and uploads once to a draft
release. It never uses `--clobber`.

The required cases are valid, corrupt, incomplete, hashless, unsupported,
hostile output, and report-persistence failure. Any missing or mismatched case
blocks candidate validation. The hostile-output case tests bounded decoding and
terminal sanitization; it never evaluates native text as PowerShell.

## Approve and publish

Candidate review must cover the source signature, package and internal hashes,
PE imports, licenses, SBOM, provenance, both-shell corpus results, and GitHub
attestation. Approval is a reviewed catalog commit, not a workflow side effect.
The catalog record does not contain a self-referential approval commit.

After approval, inspect the publication plan from a clean checkout:

```powershell
pwsh -NoProfile -File .\scripts\Publish-NativeForensicTool.ps1 `
  -RecordId forensic-ewfverify-20231119-b1 `
  -BuildRecord .\config\forensic-builds\ewfverify-20231119-b1.psd1 `
  -PackagePath .\candidate\ewfverify-20231119-windows-x64-b1.zip
```

The separate manual publish workflow supplies `-Publish
-ConfirmPublication`. Publication verifies the clean containing commit, exact
catalog bytes, build-record digest, approved package, certification,
attestation, draft state, and single asset before publishing. It records the
catalog-file SHA-256 and containing commit in the release notes and does not
replace an existing asset.

Any source, dependency, compiler, recipe, option, or security correction needs
a new build revision. Old catalog records and release assets remain unchanged
so historical `ewf-verify` reports stay attributable.

## Native-Windows boundary

No forensic package build, installation, verification, or reporting step uses
WSL, Linux containers, Cygwin, MSYS/MSYS2, MinGW, or Git Bash. This boundary is
part of the evidence model, not a statement that those environments are unsafe
for unrelated development.
