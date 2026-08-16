# Quickstart: Native EWF Verification

This document describes the intended command contract. The feature is still in design; these commands become available after implementation and certification.

## Prerequisites

- Windows 11 Pro x64
- Windows PowerShell 5.1 or the repository-managed PowerShell 7
- this repository checked out at a reviewed commit
- an approved native forensic tool record

No WSL distribution, Linux container, Cygwin, MSYS/MSYS2, MinGW runtime, or Git Bash participates in this workflow.

Before the first forensic package is published, a maintainer must explicitly enable GitHub immutable releases and migrate the existing release workflow away from asset replacement. Planning does not change that repository setting.

## Inspect and install the approved verifier

Start with the read-only views:

```powershell
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Plan
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Test
```

Install or repair the pinned approved release explicitly:

```powershell
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Ensure
```

`Ensure` downloads the exact immutable release asset, validates the Git-catalog package hash and internal allowlist, and installs it to a versioned per-user directory. It does not install a compiler or build from source.

## Plan an evidence verification

```powershell
ewf-verify -Path C:\Evidence\image.E01 -ReportDirectory C:\Reports -Plan
```

Plan mode checks the tool identity, selected segment, discovered segment order, format support, and report destination. It does not invoke `ewfverify`, lock the evidence for a verification transaction, or write a completed report.

With `-Json`, plan output follows `contracts/ewf-verification-plan.schema.json`. It is deliberately
separate from the completed verification-report schema and contains no media hashes.

## Verify and produce a human report

```powershell
ewf-verify -Path C:\Evidence\image.E01 -ReportDirectory C:\Reports
```

The command reports a status and the new report directory. Only `verified` exits with code 0. A readable image without a stored digest is `readable-no-stored-hash`, not verified.

## Use the machine contract

```powershell
$result = ewf-verify -Path C:\Evidence\image.E01 -ReportDirectory C:\Reports -Json |
    ConvertFrom-Json

$result.status
$result.evidence.segments | Select-Object ordinal, name, preSha256, postSha256, unchanged
```

The same operation produces human and JSON forms; AI orchestration does not have a separate privileged path.

## Inspect the durable report

```powershell
$report = Get-Content -Raw C:\Reports\<run-id>\report.json | ConvertFrom-Json
$report.tool
$report.tool.catalogFileSha256
$report.tool.catalogCommit
$report.mediaDigests
$report.artifacts
Get-FileHash C:\Reports\<run-id>\stdout.bin -Algorithm SHA256
```

The run directory contains readable and JSON reports, raw bounded stdout/stderr, the upstream log when available, and an artifact digest inventory. Copy the whole directory with case notes; do not edit it in place.

## Maintainer build and publication

Building is exceptional and never part of workstation update:

```powershell
.\scripts\Build-NativeForensicTool.ps1 `
    -BuildRecord .\config\forensic-builds\ewfverify-20231119-b1.psd1

.\scripts\Test-ForensicReleaseCandidate.ps1 `
    -PackagePath <candidate.zip> `
    -BuildRecord .\config\forensic-builds\ewfverify-20231119-b1.psd1
```

After the draft asset, attestation, certification output, and final hashes have been reviewed, commit the `Approved` runtime record. Publication is then a separate confirmed action:

```powershell
.\scripts\Publish-NativeForensicTool.ps1 `
    -ToolId ewfverify `
    -Version 20231119 `
    -BuildRevision b1 `
    -ConfirmPublish
```

The publish command validates the draft against the approved Git record and refuses replacement of any existing tag or asset.

The approved catalog record does not self-reference its own commit. Publication must run from a
clean checkout and adds the resolved catalog commit plus catalog-file SHA-256 to release provenance.

## Planned validation gates

```powershell
.\tests\Test-NativeForensicVerification.ps1

Invoke-Pester .\tests\pester\NativeForensicVerification.Tests.ps1
powershell.exe -NoProfile -Command "Invoke-Pester '.\tests\pester\NativeForensicVerification.Tests.ps1'"

ears-sdd validate --feature specs/008-native-forensic-verification --phase implementation
lint-powershell
uv run --group docs mkdocs build --strict
```

The certification workflow additionally validates PE architecture/imports, the pinned package manifest and SBOM, offline operation, hostile native output, persistence failures, evidence mutation, corrupt/missing segments, and expected results for the benign corpus.
