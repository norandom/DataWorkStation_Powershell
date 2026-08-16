# Verify an EWF image

`ewf-verify` checks an existing segmented EWF image without mounting it or
changing its bytes. Start with a plan:

```powershell
ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports -Plan
```

The plan resolves the segment set, approved tool record, and report destination.
It does not hash evidence, run `ewfverify`, install software, or create a report.
Review it, then omit `-Plan` to perform the read-only verification:

```powershell
ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports
```

Use `-Json` on either command for the machine-facing contract. The plan and
verification report have separate schemas under
`specs/008-native-forensic-verification/contracts/`; a plan is not evidence that
verification ran.

## Prerequisites and execution boundary

This path requires Windows 11 Pro x64 and the optional `NativeForensicTools`
module. It is native Windows only. It does not use WSL, Linux containers,
Cygwin, MSYS/MSYS2, MinGW, or Git Bash. Test the declared state before changing
it:

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module NativeForensicTools -Plan
pwsh -NoProfile -File .\scripts\Set-NativeForensicToolsState.ps1 -Mode Test
```

Installation is an explicit operation and succeeds only for an `Approved`
catalog record:

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeForensicTools
```

If the catalog contains only a `Candidate`, Test reports `Unapproved` and Ensure
refuses installation. Ordinary `update` reports that candidate but does not
adopt, build, or publish it.

## What the command does

The verifier:

1. Resolves a contiguous, certified EWF segment family from the selected file.
2. Opens every segment read-only and holds the handles for the transaction.
3. Streams a SHA-256 and length for every segment before native verification.
4. Revalidates the approved catalog and every installed executable and DLL.
5. Invokes the absolute cataloged `ewfverify.exe` path with a literal argument
   vector; it does not interpret tool output as PowerShell.
6. Retains bounded stdout, stderr, and upstream log bytes, while rendering only
   a sanitized preview.
7. Re-hashes the still-open segment handles and overrides apparent success if
   any byte or length changed.
8. Writes a new staging directory and atomically commits it under the report
   destination. Existing reports are never replaced.

The selected report directory must be separate from the evidence tree. The
command uses no network service and initiates no network communication.

## Status and exit meaning

| Status | Exit | Meaning |
| --- | ---: | --- |
| `planned` | 0 | Read-only plan only; verification did not run. |
| `verified` | 0 | Stored digest verified and all wrapper integrity checks passed. |
| `integrity-failed` | 1 | The native verifier or stored-digest comparison failed. |
| `evidence-changed` | 1 | Segment bytes or lengths changed during the transaction. |
| `parser-output-unrecognized` | 1 | Output did not match the certified parser profile. |
| `readable-no-stored-hash` | 2 | The image was readable but contains no stored digest to verify. |
| `unsupported` | 3 | The selected format or segment layout is not certified. |
| `tool-integrity-failed` | 4 | Catalog, executable, DLL, or installed-file identity did not match. |
| `report-failed` | 5 | Durable report persistence failed or would overwrite existing output. |

Only `verified` is a successful verification result. `readable-no-stored-hash`
is deliberately not promoted to success.

## Read the retained report

Every completed run directory contains:

| Artifact | Purpose |
| --- | --- |
| `report.txt` | Concise operator-readable result and sanitized previews. |
| `report.json` | Stable result, evidence, invocation, tool, and provenance facts. |
| `artifacts.json` | Retained artifact sizes, SHA-256 identities, and truncation facts. |
| `stdout.bin` / `stderr.bin` | Bounded raw native streams; do not print them directly to a terminal. |
| `ewfverify.log` | Bounded upstream log plus its complete source-stream identity. |

The JSON report records the exact catalog-file SHA-256, its containing Git
commit when resolvable, release/package/file/source identities, the literal
argument vector, native exit code, segment order, pre/post lengths and hashes,
media digests, warnings, and failure facts. A truncated raw artifact retains
both the saved-byte identity and the full source stream's length and SHA-256.

## Scope and attack surface

This command verifies consistency; it does not prove acquisition legality,
chain of custody, evidentiary meaning, or absence of malicious content. Parsing
a hostile disk-image format still exposes a native parser to attacker-controlled
bytes. The controls reduce that surface by shipping only the verifier and its
required native DLLs, forbidding network imports, pinning all bytes, running
without elevation, avoiding mounts, and retaining read-only evidence handles.

Do not use case evidence for package certification. The repository-owned corpus
contains deterministic benign images. Corrupt, incomplete, unsupported,
hostile-output, and persistence-failure cases are derived only below temporary
test storage.

For package provenance, approval, and release operation, see [Native forensic
tool lifecycle](forensic-tools.md). Representative output is in [Sample
outputs](sample-outputs.md#ewf-verification).
