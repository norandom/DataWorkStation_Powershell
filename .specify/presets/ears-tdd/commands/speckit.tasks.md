---
description: Generate test-first tasks with complete requirement coverage.
strategy: wrap
---

{CORE_TEMPLATE}

## Test-first postcondition

Tests are mandatory. Place each failing-test task before its corresponding implementation task.
Every behavior task must identify its `REQ-NNN` coverage and test selector. Do not permit a generic
"add tests later" task.

Tell the user to run:

```text
ears-sdd validate --phase tasks
```
