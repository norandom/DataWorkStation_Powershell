# Analysis and differencing cases

Choose the narrowest case that answers the question. Every command below plans by default. A plan
may copy inert input bytes into a new ignored case, but it does not start Windows Sandbox, a
container, or the target.

| Question | Human command | Isolation boundary | Primary evidence |
| --- | --- | --- | --- |
| What can bounded bytes tell me? | `host-static <path>` | Bounded host byte reader | identity, entropy, strings, PE metadata, indicators |
| What is embedded in this Office/PDF file? | `malware-container <path>` or Sandbox `Dissect` | Rootless `Debian-MW` container or Windows Sandbox | OLE/OOXML/PDF inventories and extracted-object hashes |
| What does one binary disassemble to? | `disass <path>` | Windows Sandbox | Rizin text and `disassembly.sqlite` line index |
| Can Ghidra recover useful code? | `decomp <path>` | Windows Sandbox | best-effort decompiler output and explicit completion state |
| How did a binary change structurally? | `binary-diff <baseline> <candidate>` | Rootless `Debian-MW` container | BinExport graphs, canonical BinDiff SQLite, query sidecar |
| What behavior differs from a clean guest? | `sandbox-behavior-control`, `sandbox-behavior-target`, then `sandbox-behavior-diff` | Windows Sandbox | process, file, registry, handle, ETW, and available network deltas |

`wsl-dev` and the ordinary developer container engine are never suspicious-file boundaries.

## Graph-first binary comparison

Plan a comparison and review the returned manifest and container arguments:

```powershell
binary-diff C:\Samples\product-1.exe C:\Samples\product-2.exe
```

After review, explicitly run the non-executing parsers:

```powershell
binary-diff C:\Samples\product-1.exe C:\Samples\product-2.exe -Run -ConfirmContainer
binary-diff-report <case-directory>
binary-diff-report <case-directory> -Json
```

The pipeline is deliberately structural:

```text
baseline binary  -> Ghidra -> baseline.BinExport  --\
                                                     BinDiff -> baseline_vs_candidate.BinDiff
candidate binary -> Ghidra -> candidate.BinExport --/
                                      |
                   bounded code export + match projection -> binary-analysis.sqlite
```

[BinExport](https://github.com/google/binexport) emits the call graph and per-function control-flow
graphs that [BinDiff](https://github.com/google/bindiff) consumes. BinDiff matches normalized graph
structure—basic blocks, edges, and calls—and records pair and function similarity/confidence. This
is the primary comparison.

The workflow does **not** compare file versions, raw bytes, string dumps, assembly text, or
decompiled text as a substitute when graph export or matching fails. Those representations are
useful supporting evidence, but address movement, compiler changes, inlining, and formatting make
them unsuitable as the authoritative relationship. A graph-tool failure therefore produces
`missing-tool`, `timed-out`, or `partial`, not a different kind of “successful” diff.

BinNavi is not the storage layer here. Its public repository is archived, its original database is
central PostgreSQL, and its exporter path is IDA-oriented. The maintained Ghidra path is BinExport;
the canonical match result is already queryable SQLite.

## Artifact roles

- `baseline.BinExport` and `candidate.BinExport` are the retained graph exports. They are protobuf
  evidence, not raw executables.
- `baseline_vs_candidate.BinDiff` is BinDiff's canonical SQLite result. The workflow opens it
  read-only and never alters its tables.
- `binary-analysis.sqlite` is a separate derived sidecar. It contains `binaries`, `functions`,
  `basic_blocks`, `instructions`, `edges`, `calls`, and a bounded `function_matches` projection.
  Functions and relationships are keyed by binary role and normalized address.
- `binary-diff-summary.json` is the only small result schema exposed by default. It contains source
  hashes, graph similarity/confidence, function counts, tool states, `Execution=not-run`, and
  `Verdict=undetermined`.

Decompiler success is recorded per function. Missing code remains missing; it is never invented
from disassembly. The sidecar can be partial while the canonical graph match remains complete.

## Representative SQL

SQLite databases and every string they contain are hostile evidence. Do not open them in a host
GUI, deserialize them in PowerShell, or print arbitrary text directly into a trusted terminal.
Copy a case into a disposable, offline analysis boundary before running exploratory SQL. The
following read-only queries describe the intended schema.

Pair-level graph score from the immutable BinDiff database:

```sql
SELECT similarity, confidence FROM metadata;
```

Changed graph-matched functions with the matching algorithm and graph counts:

```sql
SELECT printf('0x%x', f.address1) AS baseline_address,
       printf('0x%x', f.address2) AS candidate_address,
       f.name1, f.name2, f.similarity, f.confidence,
       a.name AS algorithm, f.basicblocks, f.edges, f.instructions
FROM function AS f
JOIN functionalgorithm AS a ON a.id = f.algorithm
WHERE f.similarity < 1.0
ORDER BY f.similarity, f.confidence;
```

Join a graph match to supporting Ghidra analysis in the sidecar:

```sql
SELECT m.similarity, m.confidence, m.algorithm,
       b.name AS baseline_name, c.name AS candidate_name,
       b.decompile_state AS baseline_decompile,
       c.decompile_state AS candidate_decompile
FROM function_matches AS m
LEFT JOIN functions AS b
  ON b.role = 'Baseline' AND b.address = m.baseline_address
LEFT JOIN functions AS c
  ON c.role = 'Candidate' AND c.address = m.candidate_address
ORDER BY m.similarity, m.confidence;
```

The sidecar also supports address-scoped `instructions`, outgoing `calls`, and `edges` queries. A
row in `function_matches` is copied from the read-only `.BinDiff` database; it does not redefine the
match.

## General Sandbox behavior diff

The general names reuse the same clean-control engine as suspicious-file analysis:

```powershell
# Plan only.
sandbox-behavior-control C:\Installers\tool.exe -DurationSeconds 30
sandbox-behavior-target C:\Installers\tool.exe -DurationSeconds 30

# Launch only after reviewing each plan.
sandbox-behavior-control C:\Installers\tool.exe -DurationSeconds 30 -Run -ConfirmSandbox
sandbox-behavior-target C:\Installers\tool.exe -DurationSeconds 30 `
  -Run -ConfirmSandbox -ConfirmExecution

# Compare two already completed, policy-compatible cases.
sandbox-behavior-diff -ControlCase <control-case> -TargetCase <target-case>
```

The control never reads or invokes the target. The target requires separate Sandbox and execution
confirmations. Documents and unsupported interpreters are refused for behavior execution; use
`Dissect` or the rootless static parser instead. The comparison uses native Git's ordinary
`diff --no-index` over bounded canonical evidence, not a private or raw-evidence diff.

## Interpretation and residual attack surface

A high graph score means the analyzed structures are similar; it is not a trust verdict. A low
score can reflect compiler or optimization changes. Packed, malformed, stripped, cross-architecture,
split, merged, or inlined functions can reduce coverage or confidence. “Added” and “removed” mean
unmatched functions in the analyzed graphs, not necessarily new or deleted source functions.

Both Ghidra and BinDiff parse attacker-controlled bytes and graph files. They run rootless with no
network, a read-only root and inputs, dropped capabilities, no-new-privileges, a numeric user, and
bounded CPU, memory, PIDs, time, temporary space, artifacts, strings, and records. Parser compromise,
kernel/container escape, resource exhaustion within remaining bounds, and malicious output files
remain residual risks. Results crossing back to Windows are opaque path/size/hash records except
for the small schema validated and sanitized by the Python evidence boundary.

For dynamic work, Windows Sandbox adds a separate hypervisor boundary but still exposes the narrow
writable case output. Inspect existing snapshots, ETL, EVTX, PCAPNG, dumps, and case artifacts
before collecting again. Quiet static or dynamic evidence never proves safety, and this workflow
always reports `Verdict=undetermined`.
