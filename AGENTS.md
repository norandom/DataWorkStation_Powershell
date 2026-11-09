# Repository operating contract

- Use `main` as the repository branch. Publish releases with version tags; do not create stable branches.
- Preserve human/AI parity: add a human-readable command before documenting AI orchestration around it.
- Inspect existing EVTX, ETL, PCAPNG, dump, profile, and snapshot evidence before starting another capture.
- Keep privileged and state-changing operations explicit. Do not silently capture, attach, kill, disable protection, or reinitialize policy.
- Use `config/capabilities.psd1` as the routing catalog and update it with command changes.
- Use `tricky ... -Json` for machine consumption and the default output for humans.
- Keep Codex skills focused and separate under `.agents/skills/`; do not create one omnibus workstation skill.
- Use SkillOpt only on one explicit skill from reviewed tasks. Keep gating on, stage by default, and never auto-adopt or schedule unattended optimization.
- Run `lint-powershell`, Tricky smoke tests, and `uv run --group docs mkdocs build --strict` before publishing.
- Never use a drive root as the working directory or output directory for builds, dependency installs, tests, agents, or generated files. Use the relevant repository as the working directory.
- Put disposable caches, temporary directories, and build output under the configured `DEVELOPER_STORAGE_ROOT` (this workstation: `D:\BuildArtifacts`), in tool/project-specific subdirectories. Honor `UV_CACHE_DIR`, `CARGO_HOME`, `CARGO_TARGET_DIR`, the configured pnpm store, and developer-shell `TEMP`/`TMP`; pass an explicit output path for tools without a setting.
- Do not create root-level `.pnpm-store`, `*-build-*`, `target`, `dist`, or temporary directories. Before starting a job, resolve its working directory and output paths; if either is a drive root, choose a repository/artifact subdirectory first. Existing source repositories and explicitly requested WSL installation directories are separate from generated build output.
