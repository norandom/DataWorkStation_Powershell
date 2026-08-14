---
description: Run the deterministic EARS/TDD validator and report actionable failures.
scripts:
  sh: ../scripts/ears-sdd.sh
  ps: ../scripts/ears-sdd.ps1
---

## Human command

The user can run the same check without an agent:

```text
ears-sdd validate --phase <spec|plan|tasks|final>
```

## Agent execution

Interpret `$ARGUMENTS` as the phase; use `final` when it is empty. Execute `{SCRIPT}` with:

```text
validate --project . --phase <phase> --json
```

Parse the JSON result and report each finding with its file and requirement ID. If validation
fails, change only the specification, plan, task, traceability, or policy configuration artifacts
that caused the failure. Never paste requirement prose or requirement IDs into production code to
make a finding disappear. Do not implement product behavior as part of this validation command.
