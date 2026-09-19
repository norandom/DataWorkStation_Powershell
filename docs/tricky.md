# Tricky cases

`tricky` gives operators and automation the same case structure, evidence index, and commands.

```powershell
tricky new api-timeout -Problem 'DNS succeeds but localhost port 8080 times out' -Target 'localhost:8080'
tricky add api-timeout -Path ./pcap-api-timeout
tricky inspect api-timeout
tricky inspect api-timeout -Json
tricky note api-timeout -NoteType Observation -Message 'DNS succeeds; connection times out.'
tricky note api-timeout -NoteType NextStep -Message 'Inspect the existing packet capture for resets or drops.'
tricky report api-timeout -Open
```

## Case layout

```text
tricky-api-timeout/
  case.json
  notes.json
  evidence/
    events/ traces/ packets/ dumps/ profiles/ snapshots/
    references.json
  normalized/
  report.md
  report.json
  report.html
```

`tricky add` records a reference by default, which avoids duplicating a multi-gigabyte trace. Use `-Copy` when the case must be portable. Use `tricky inspect ... -Hash` when evidence integrity requires SHA-256; hashing is opt-in because large traces are common.

The HTML report is self-contained and has no runtime dependencies. It shows evidence volume, lists
every artifact, and separates retained evidence from capture gaps. A suggested capture command does
not run automatically.

`tricky note` maintains the case journal. `-NoteType` accepts `Observation`, `Hypothesis`,
`Contradiction`, `Change`, `Result` and `NextStep`; `-Message` is required and `-Path` can link
existing evidence. Record backups and rollback decisions for changes, and keep credentials out
of notes. The journal is included in inspection and all report formats.

An [HTTP diagnostic summary](workflows/http-authentication.md) contributes coverage information.
Missing target requests or reported event loss produces a `coverage-gap`; merely having an ETL
does not establish that the failure was captured. Unknown loss and missing reproduction-window
confirmation remain limits even when requests are present.

## Stable automation output

Use `-Json` when another process consumes the result and `-AsObject` inside PowerShell. The case and report currently use schema version `1`; consumers should check it before relying on fields.
