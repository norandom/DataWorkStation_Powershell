# Quickstart: Analysis Differencing

## Plan a general behavior comparison

```powershell
$control = sandbox-behavior-control .\tests\fixtures\benign-sample.exe -Json
$target = sandbox-behavior-target .\tests\fixtures\benign-sample.exe -Json
```

Review both manifests and WSB files. Planning must not start Windows Sandbox. Launches, if desired,
require separate approval and commands from the [CLI contract](contracts/analysis-differencing-cli.md).

Compare already completed compatible cases:

```powershell
sandbox-behavior-diff -ControlCase $control.CaseDirectory `
  -TargetCase $target.CaseDirectory
```

## Plan a graph-based binary comparison

```powershell
binary-diff -Baseline C:\Binaries\app-1.0.exe `
  -Candidate C:\Binaries\app-1.1.exe
```

Confirm that both inputs are read-only, networking is `none`, execution is `not-run`, and the image
fingerprints are current. The plan must not start Podman or build the image.

After an explicit decision to allow static parser access:

```powershell
binary-diff -Baseline C:\Binaries\app-1.0.exe `
  -Candidate C:\Binaries\app-1.1.exe -Run -ConfirmContainer
```

## Query retained evidence

Open the sidecar only as hostile evidence in an isolated or disposable viewer. Representative
read-only queries are:

```sql
SELECT baseline_address, candidate_address, similarity, confidence
FROM function_matches
ORDER BY similarity, confidence;

SELECT role, address, name, decompile_state
FROM functions
WHERE name LIKE '%crypt%';

SELECT role, caller_address, callee_name
FROM calls
WHERE callee_name LIKE '%CreateProcess%';
```

The `.BinDiff` database remains the graph-match authority. `binary-analysis.sqlite` is a derived
code and disassembly sidecar, not an alternative matching engine.

## Automated validation

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-AnalysisDifferencing.ps1
pwsh -NoProfile -File .\tests\Test-AnalysisDifferencing.ps1
```

Automated tests use synthetic plans and records; they do not launch Windows Sandbox, start a
container, download tools, or execute either binary.
