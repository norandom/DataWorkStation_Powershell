# CLI Contract: Analysis Differencing

## General Sandbox behavior

Planning is the default and starts no Sandbox:

```powershell
sandbox-behavior-control <path> [-DurationSeconds N] [-Json]
sandbox-behavior-target <path> [-DurationSeconds N] [-Json]
```

Each launch is separately explicit:

```powershell
sandbox-behavior-control <path> -Run -ConfirmSandbox
sandbox-behavior-target <path> -Run -ConfirmSandbox -ConfirmExecution
```

Networking remains off. `-AllowNetwork` is an additional explicit risk decision and must match on
both sides. Compare only completed compatible cases:

```powershell
sandbox-behavior-diff -ControlCase <case> -TargetCase <case> [-ShowDiff] [-Json]
```

These commands delegate to the existing Sandbox plan, runner, evidence reader, and comparison
engine. They do not create another execution path.

## Graph-based binary comparison

Planning validates and copies two bounded regular files into a new ignored case but does not start a
container:

```powershell
binary-diff -Baseline <old-binary> -Candidate <new-binary> [-Json]
```

Static parsing requires explicit container confirmation:

```powershell
binary-diff -Baseline <old-binary> -Candidate <new-binary> -Run -ConfirmContainer [-Json]
```

The command has no execution or network switch. It must report a missing/stale image and repair
command rather than build or download implicitly.

Report an existing case before proposing another run:

```powershell
binary-diff-report -Case <case> [-Json]
```

## Output

Default output is a bounded human summary. `-Json` emits schema version 1 with the same facts:
status, backend, case, baseline and candidate hashes, policy, tool states, graph artifacts, semantic
database record, query-sidecar record, match summary, failures, limitations, and `undetermined`
verdict. Raw databases, graph exports, code, and logs are never embedded.

## Stable artifacts

```text
manifest.json
container-plan.json
output/baseline.BinExport
output/candidate.BinExport
output/baseline_vs_candidate.BinDiff
output/binary-analysis.sqlite
output/binary-diff-summary.json
output/ghidra-baseline.log
output/ghidra-candidate.log
output/bindiff.log
```
