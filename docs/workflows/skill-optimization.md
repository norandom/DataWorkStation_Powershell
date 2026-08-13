# Skill optimization

Microsoft SkillOpt-Sleep is an offline development loop for improving one natural-language skill from repeated tasks. It does not train model weights. This integration pins PyPI `skillopt==0.2.0` in an isolated `uv tool` environment.

## Installation boundary

Automatically installed:

- stable `skillopt==0.2.0` and its base dependency closure inside the isolated uv tool environment;
- the `skillopt-sleep`, `skillopt-train`, and `skillopt-eval` entry points supplied by that package;
- this repository's stricter, versioned `optimize-skills` Codex skill and PowerShell wrapper.

Not automatically installed or configured:

- Microsoft SkillOpt's mutable `main` branch or global user-level Codex plugin;
- WebUI, ALFWorld, SearchQA/datasets, Claude SDK, Qwen/vLLM, or other optional extras;
- provider credentials, a scheduled sleep cycle, auto-adoption, or an optimization target;
- packages in the AMD/PyTorch or any project Python environment.

The source-only preview currently contains interfaces newer than PyPI 0.2.0. The workstation stays on the released interface until a later version is deliberately reviewed and pinned.

## Safety contract

| Boundary | Workstation policy |
|---|---|
| Target | One explicit `.agents/skills/NAME/SKILL.md` |
| Input | Human-reviewed task JSON, never an implicit real-backend harvest |
| Provider | Mock by default; Codex requires `-AllowProviderCalls` |
| Gate | Enabled with mixed scoring and no-regression preference |
| Output | Ignored `.skillopt-sleep/staging/` proposal |
| Adoption | Explicit staging path plus `-ConfirmAdoption` |
| Memory | `CLAUDE.md` evolution disabled; `AGENTS.md` is never targeted |
| Scheduling | Not exposed by the managed wrapper |
| Evidence logs | Disabled; secret redaction remains enabled |

## Review-first sequence

```powershell
skills-validate
skillopt-status

skillopt-harvest diagnose-network
skillopt-review diagnose-network -TasksFile ./.skillopt-sleep/review/diagnose-network-tasks-YYYYMMDD-HHMMSS.json

# Edit/redact the JSON and verify its checks and train/validation split.
skillopt-approve-tasks diagnose-network -TasksFile ./path/to/tasks.json -ConfirmReview

# No provider call and no staging:
skillopt-dry-run diagnose-network -TasksFile ./path/to/tasks.json

# Explicit provider boundary; stages but does not adopt:
skillopt-run diagnose-network -TasksFile ./path/to/tasks.json -Backend Codex -AllowProviderCalls

skillopt-review diagnose-network -Staging ./.skillopt-sleep/staging/NIGHT
skillopt-adopt diagnose-network -Staging ./.skillopt-sleep/staging/NIGHT -ConfirmAdoption
skills-validate
git diff
```

`harvest` reads archived Codex sessions belonging to this project and writes a review draft marked `"reviewed": false`. Treat the draft as sensitive even though SkillOpt performs pattern-based redaction. The wrapper refuses real-backend use until an explicit approval marks it reviewed.

## What desired state does

`Apply-Workstation.ps1 -Mode Ensure` installs the pinned CLI and maintains conservative user defaults under `~/.skillopt-sleep/config.json`. It does not read sessions, create a schedule, call a model provider, generate a proposal, or adopt a skill.

## Interpreting results

An accepted result means the candidate improved that run’s held-out tasks. Before adoption, also check:

- the held-out set actually represents the skill’s scope;
- judges measure observable correctness rather than stylistic similarity;
- commands named by the proposal exist;
- the skill remains concise and does not absorb another skill’s responsibility;
- human and AI workflows still share the same atomic shell interface.
