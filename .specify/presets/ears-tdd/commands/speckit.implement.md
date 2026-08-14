---
description: Implement approved tasks test-first and enforce the final EARS traceability gate.
strategy: wrap
---

Before executing implementation tasks, run the human validator command shown in the project docs:

```text
ears-sdd validate --phase tasks
```

If validation fails, stop and repair specification, plan, task, or traceability artifacts. Do not
"fix" policy failures by copying requirement prose into production code.

{CORE_TEMPLATE}

After the project's configured tests pass, run:

```text
ears-sdd validate --phase final
```
