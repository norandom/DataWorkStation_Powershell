# Humans and AI use the same workstation

Scripts and profile commands are the supported interface. Documentation and Codex skills call those
commands directly instead of maintaining a separate automation implementation.

The interface makes Windows diagnostic tools easier to find and operate. Humans can use the default
output for direct troubleshooting. An AI can consume the structured form to handle slow or quirky
evidence work, but it still reaches the same explicit privilege and state-change boundaries.

## Contract

- Human-readable output is the interactive default.
- `-Json` is the stable process boundary; `-AsObject` is the PowerShell boundary where supported.
- Inspection is read-only unless a command clearly says capture, enable, disable, ensure, reinitialize, copy, mount, or kill.
- Existing evidence is inspected before new evidence is collected.
- Privileged actions remain visible and explicit.
- Reports record the command recommendation and why it was selected.

## Layers

| Layer | Purpose |
|---|---|
| `scripts/` and `profile/` | Atomic commands and implementation |
| `config/capabilities.psd1` | Machine-readable capability and routing catalog |
| `tricky` case schema | Shared evidence boundary and reports |
| `docs/` | Human workflows and reference |
| `.agents/skills/` | Focused AI procedures built from the same commands |
| SkillOpt staging | Reviewed, validation-gated proposals for one skill at a time |

SkillOpt may improve descriptions and routing examples. It handles one skill at a time, stages its
proposal outside Git, and validates the proposal against the command catalog. Adoption always
requires a separate review and command.
