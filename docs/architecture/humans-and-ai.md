# Humans and AI use the same workstation

The shell commands are the product boundary. Documentation and Codex skills describe how to combine them, but neither hides a second automation-only implementation.

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

SkillOpt may improve descriptions and routing examples, but generated changes remain reviewable, bounded to one skill, staged outside Git, and validated against the command catalog before explicit adoption.
