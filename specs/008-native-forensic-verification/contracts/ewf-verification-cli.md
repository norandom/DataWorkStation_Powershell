# Contract: EWF Verification CLI

## Human command

```powershell
ewf-verify -Path C:\Evidence\image.E01 -ReportDirectory C:\Reports
```

The script entry point is also directly usable:

```powershell
.\scripts\Invoke-EwfVerification.ps1 -Path C:\Evidence\image.E01 -ReportDirectory C:\Reports
```

Machine consumers add `-Json` to the same command. The default output is a short human status, evidence identity, tool identity, and report path.

## Parameters

| Parameter | Contract |
|---|---|
| `-Path` | Required path to one segment in an EWF set. The command discovers and validates the remaining local segments. |
| `-ReportDirectory` | Required parent directory for a new run report. Existing completed reports are not overwritten. |
| `-Plan` | Performs input, catalog, installed-tool, segment-inventory, and output-path checks without invoking the verifier or writing a report. |
| `-Json` | Writes exactly one JSON result object to stdout. Diagnostics remain structured fields, not interleaved host text. |

No parameter enables WSL, a Linux container, acquisition, mounting, export, recovery, evidence repair, or a network fallback.

## Status and exit contract

| Status | Exit | Meaning |
|---|---:|---|
| `verified` | 0 | Stored digest verified, tool identity valid, and evidence unchanged. |
| successful `-Plan` | 0 | Preconditions are valid; no verification was run. |
| `integrity-failed` | 1 | Stored evidence integrity did not verify. |
| `evidence-changed` | 1 | At least one segment changed during the held-handle transaction. |
| `parser-output-unrecognized` | 1 | Upstream output could not be mapped safely. |
| `readable-no-stored-hash` | 2 | The image is readable but has no stored digest to verify. |
| `unsupported` | 3 | Format, version, naming, or segment layout is not certified. |
| `tool-integrity-failed` | 4 | Catalog, package, executable, dependency, or provenance validation failed. |
| `report-failed` | 5 | A complete durable report could not be committed. |

Only `verified` represents completed forensic verification. Planning success is explicitly marked as `planned`, never `verified`.

## Output rules

- Human output never reproduces unsanitized native control characters.
- Verification JSON follows `ewf-verification-report.schema.json`.
- Plan JSON follows `ewf-verification-plan.schema.json`; it uses status `planned`, identifies prospective inputs and operations, and contains no media hashes or verification artifacts.
- The exact native argument vector and exit code are recorded.
- stdout/stderr raw bytes are report artifacts, subject to fixed documented size bounds.
- A failed report commit cannot be reported as verification success.

## Tool-state command

```powershell
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Plan
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Test
.\scripts\Set-NativeForensicToolsState.ps1 -Mode Ensure
```

`Plan` is read-only. `Test` reports catalog/install drift. `Ensure` is an explicit state change that installs only an `Approved` release asset after hash validation. Each mode also supports `-Json`.

## Maintainer-only commands

```powershell
.\scripts\Build-NativeForensicTool.ps1 -BuildRecord .\config\forensic-builds\ewfverify-20231119-b1.psd1
.\scripts\Test-ForensicReleaseCandidate.ps1 -PackagePath <candidate.zip> -BuildRecord <record.psd1>
.\scripts\Publish-NativeForensicTool.ps1 -ToolId ewfverify -Version 20231119 -BuildRevision b1 -ConfirmPublish
```

These are native-Windows, explicit commands. They are never called by workstation update or runtime verification. Publication fails if the release is not a matching draft, the approved catalog does not match the asset, release immutability is unavailable, or the tag/asset already exists with a different identity.
