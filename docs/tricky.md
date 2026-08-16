# Tricky cases

`tricky` gives operators and automation the same case structure, evidence index, and commands.

```powershell
tricky new api-timeout -Problem 'DNS succeeds but localhost port 8080 times out' -Target 'localhost:8080'
tricky add api-timeout -Path ./pcap-api-timeout
tricky inspect api-timeout
tricky inspect api-timeout -Json
tricky report api-timeout -Open
```

## Case layout

```text
tricky-api-timeout/
  case.json
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

## Stable automation output

Use `-Json` when another process consumes the result and `-AsObject` inside PowerShell. The case and report currently use schema version `1`; consumers should check it before relying on fields.
