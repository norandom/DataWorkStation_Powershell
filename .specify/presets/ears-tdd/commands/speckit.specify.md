---
description: Create a specification, then normalize every normative requirement into EARS form.
strategy: wrap
---

{CORE_TEMPLATE}

## EARS postcondition

Before finishing, ensure each normative requirement has a unique `REQ-NNN` ID, contains exactly
one `shall`, and uses an EARS form documented in the resolved specification template. Create the
feature's `traceability.toml`; entries may remain incomplete until planning, but requirement IDs
must already match the specification.

Tell the user to review the artifact and run:

```text
ears-sdd validate --phase spec
```
