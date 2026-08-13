# Repository operating contract

- Preserve human/AI parity: add a human-readable command before documenting AI orchestration around it.
- Inspect existing EVTX, ETL, PCAPNG, dump, profile, and snapshot evidence before starting another capture.
- Keep privileged and state-changing operations explicit. Do not silently capture, attach, kill, disable protection, or reinitialize policy.
- Use `config/capabilities.psd1` as the routing catalog and update it with command changes.
- Use `tricky ... -Json` for machine consumption and the default output for humans.
- Keep Codex skills focused and separate under `.agents/skills/`; do not create one omnibus workstation skill.
- Use SkillOpt only on one explicit skill from reviewed tasks. Keep gating on, stage by default, and never auto-adopt or schedule unattended optimization.
- Run `lint-powershell`, Tricky smoke tests, and `uv run --group docs mkdocs build --strict` before publishing.
