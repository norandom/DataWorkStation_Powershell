# Research: General Sandbox and Binary Differencing

## Decision 1: Reuse the existing clean-control Sandbox engine

**Decision**: Add general-purpose behavior commands over the existing `Detonate` control, target,
and canonical evidence comparison implementation.

**Rationale**: The existing path already enforces explicit Sandbox and execution approval, identical
policies, guest-side telemetry, control non-execution, auto-close, bounded evidence ingestion, and
native Git unified diff semantics. A second runner would create divergent safety behavior.

**Alternatives considered**: A new general runner was rejected because it would duplicate the
highest-risk code. Renaming the malware commands was rejected because it would break existing users.

## Decision 2: Use BinExport and BinDiff for the canonical binary comparison

**Decision**: Analyze both files with Ghidra, export each program through BinExport v2, and run the
BinDiff engine over those graph exports. Retain both `.BinExport` files and the official `.BinDiff`
SQLite result.

**Rationale**: BinExport is the exporter component designed for BinDiff and supports Ghidra in
headless mode. BinDiff matches functions and basic blocks using call-graph and control-flow-graph
structure and writes pair metadata, function matches, basic-block matches, instruction matches,
similarity, and confidence into SQLite. This directly satisfies the user's requirement that graph
structure remain primary.

**Alternatives considered**:

- BinNavi was rejected. Its official repository is archived, development stopped, it requires a
  central PostgreSQL database, and its provided exporter supports IDA rather than Ghidra.
- Ghidriff was rejected as the canonical matcher. It is useful for patch-oriented JSON/Markdown
  code review, but the requested invariant is a graph-export-to-SQL pipeline rather than a rendered
  decompiled-code diff.
- Raw bytes, version resources, Rizin text, and decompiled C were rejected as primary matching
  inputs. They remain supporting evidence only.

Sources: [BinExport](https://github.com/google/binexport),
[BinDiff](https://github.com/google/bindiff),
[BinDiff matching concepts](https://github.com/google/bindiff/blob/main/docs/concepts.md), and
[archived BinNavi](https://github.com/google/binnavi).

## Decision 3: Keep queryable code in a separate SQLite sidecar

**Decision**: Extend the isolated Ghidra exporter to emit bounded line-oriented function,
instruction, basic-block, edge, call, and best-effort decompilation records. A Python component
inside the static container validates and imports them into `binary-analysis.sqlite`. It also copies
the bounded BinDiff match projection needed for address joins, but never changes the original
`.BinDiff` database.

**Rationale**: The BinDiff schema is intentionally a match database; it contains matched addresses
and graph counts, not a full decompiled-code corpus. A sidecar provides familiar SQL without
breaking BinDiff compatibility or confusing derived code with semantic matching.

**Alternatives considered**: Adding decompiled C columns to `.BinDiff` was rejected because it
mutates a third-party format. Direct JDBC writes from Ghidra were rejected because they add a Java
database driver and a second database writer. Host-side importing was rejected because raw parser
records must remain inside isolation.

## Decision 4: Run binary differencing only in the dedicated static container

**Decision**: Add a two-input binary-diff action to the existing rootless `Debian-MW` container
orchestrator. Both inputs are read-only, the root is read-only, networking is `none`, capabilities
are dropped, no engine socket is mounted, and neither input is executed.

**Rationale**: Binary diffing needs a long-lived, declared toolchain and more temporary storage than
the lightweight Sandbox path. The repository already has a fail-closed rootless static boundary and
separate explicit image build.

**Alternatives considered**: Host Ghidra was rejected because complex parsing of untrusted binaries
is outside the host boundary. Windows Sandbox remains suitable for single-binary best-effort work,
but duplicating the BinExport/BinDiff stack in both backends would increase state and testing cost.

## Decision 5: Pin every added artifact and treat tool output as hostile

**Decision**: Pin the BinExport source/release, BinDiff package, and any build dependency with
reviewed SHA-256 values in the image declaration. The binary-diff command never downloads or repairs
tools. Databases and graph exports are opaque host artifacts; only the existing bounded Python
evidence boundary may create summaries.

**Rationale**: Both input parsers and their output formats expand attack surface. Reproducible image
state and bounded summaries preserve the repository's existing security contract.
