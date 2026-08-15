# Data Model: General Sandbox and Binary Differencing

## BehaviorPair

Fields: control case, target case, duration, network policy, telemetry policy, tool fingerprint,
isolation fingerprint, close policy, compatibility state, canonical control directory, canonical
target directory, unified diff, telemetry gaps, and status.

State transitions:

```text
planned -> control-complete -> target-complete -> comparable -> diffed
planned -> incomplete
control-complete + target-complete -> incompatible
```

## BinaryDiffCase

Fields: case ID, baseline identity and SHA-256, candidate identity and SHA-256, backend, image and
tool fingerprints, isolation policy, confirmation state, graph artifacts, semantic database,
query sidecar, per-tool state, failures, summary, and verdict (`undetermined`).

State transitions:

```text
planned -> approved -> analyzing-baseline -> analyzing-candidate -> matching -> indexing -> complete
planned -> refused
approved -> partial | failed | timed-out
```

## GraphExport

Fields: binary role (`Baseline` or `Candidate`), source SHA-256, format version, analyzer identity,
architecture, executable format, function count, call-edge count, basic-block count, control-flow
edge count, instruction count, artifact path, size, SHA-256, and completion state.

## SemanticMatchDatabase

The immutable `.BinDiff` database retains:

- input file identities and graph counts;
- overall similarity and confidence;
- function matches with baseline/candidate addresses and names;
- function similarity, confidence, algorithm, and graph-match counts;
- basic-block and instruction address matches.

The workflow verifies the expected tables and reads only bounded aggregate projections inside the
container. It never alters this database.

## StaticQuerySidecar

Tables:

- `binaries(role, sha256, format, architecture, analysis_state)`
- `functions(role, address, name, namespace, signature, size, instruction_count, decompile_state, decompiled_code)`
- `basic_blocks(role, function_address, address, end_address)`
- `instructions(role, function_address, block_address, address, mnemonic, operands)`
- `edges(role, function_address, source_address, target_address, edge_type)`
- `calls(role, caller_address, callsite_address, callee_address, callee_name)`
- `function_matches(baseline_address, candidate_address, similarity, confidence, algorithm, basic_blocks, edges, instructions)`

Views expose changed and unmatched functions without mutating or replacing the semantic source.
Every free-text field is bounded before insertion; absence and failure are explicit states.

## BinaryDiffSummary

Fields: schema version, case, input hashes, backend, tool versions, analysis states, artifact
path/size/hash records, overall similarity and confidence, matched/changed/added/removed/ambiguous
counts, failures, limitations, and verdict. Raw graph, database, log, and code content is excluded.
