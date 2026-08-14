## EARS requirements

Every normative requirement MUST have a unique `REQ-NNN` identifier and use one EARS form:

- Ubiquitous: `REQ-001: The <system> shall <response>.`
- Event-driven: `REQ-002: When <trigger>, the <system> shall <response>.`
- State-driven: `REQ-003: While <state>, the <system> shall <response>.`
- Optional feature: `REQ-004: Where <feature is present>, the <system> shall <response>.`
- Unwanted behavior: `REQ-005: If <condition>, then the <system> shall <response>.`

Use one observable obligation per requirement. Put design choices in `plan.md`, not in the requirement.

Create `traceability.toml` beside this specification. It maps every requirement to an automated
test or to a justified manual verification. Start from the installed policy's sample and keep the
mapping synchronized as requirements change.
