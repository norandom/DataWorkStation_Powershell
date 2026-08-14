---
description: Create the implementation plan and complete requirement-to-verification traceability.
strategy: wrap
---

{CORE_TEMPLATE}

## Traceability postcondition

Update `traceability.toml` beside the active `spec.md`. Every `REQ-NNN` must map to either one or
more automated test selectors or a justified manual verification. Keep implementation technology
and design detail in `plan.md`; do not copy requirement prose into production code.

Tell the user to run:

```text
ears-sdd validate --phase plan
```
