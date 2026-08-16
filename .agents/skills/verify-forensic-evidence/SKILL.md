---
name: verify-forensic-evidence
description: Verify or interpret existing segmented EWF/E01 forensic images with the repository's read-only native Windows command and attributable reports. Use for EWF segment integrity, stored-digest checks, `ewfverify` failures, tool-integrity drift, or review of an existing EWF verification report. Do not use for acquisition, mounting, recovery, malware verdicts, or WSL/Linux forensic tooling.
---

# Verify Forensic Evidence

Use the same `ewf-verify` command documented for operators. Preserve the native
Windows boundary and treat every parser result as evidence, not a verdict.

## Workflow

1. Inspect any existing report directory before starting another verification.
   Read `report.txt`, then `report.json` and `artifacts.json`. Do not print raw
   `stdout.bin`, `stderr.bin`, or upstream logs directly to a terminal.
2. Confirm the selected path is an existing EWF segment and choose a report
   root outside the evidence tree.
3. Observe the tool state without repairing it:

   ```powershell
   pwsh -NoProfile -File .\scripts\Set-NativeForensicToolsState.ps1 -Mode Test
   ```

   If state is `Absent`, `Drifted`, or `Unapproved`, report it. Do not install,
   build, approve, publish, or update a forensic package unless the user asks
   explicitly for that separate state change.
4. Show the human-readable plan first:

   ```powershell
   ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports -Plan
   ```

5. If verification is requested, run the human command. Use `-Json` only when
   structured consumption is useful:

   ```powershell
   ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports
   ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports -Json
   ```

6. Report the status, exit meaning, evidence segment identities, pre/post
   equality, stored and calculated digest comparison, exact tool/package/catalog
   identity, report path, warnings, and evidence gaps. Separate observations
   from interpretation.

## Guardrails

- Use native Windows only. Never route EWF evidence through WSL, Linux
  containers, Cygwin, MSYS/MSYS2, MinGW, or Git Bash.
- Never mount, export, recover, acquire, rename, or modify the evidence.
- Never infer `verified` from readable content, a zero native exit alone, or a
  success-like string in raw output.
- Treat `readable-no-stored-hash` as an explicit evidence gap, not success.
- Treat `evidence-changed`, `tool-integrity-failed`, parser mismatch, and report
  persistence failure as failed verification boundaries.
- Do not claim the image is benign. EWF integrity does not establish chain of
  custody, evidentiary meaning, acquisition legality, or absence of malware.
- Prefer retained reports over rerunning. If another run is necessary, write a
  new report directory; never overwrite a completed run.

Use `docs/ewf-verification.md` for status/exit definitions and report fields.
Use `docs/forensic-tools.md` only when the user asks about package lifecycle.
