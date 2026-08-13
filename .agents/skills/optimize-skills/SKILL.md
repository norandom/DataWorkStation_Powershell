---
name: optimize-skills
description: Improve one DataWorkStation repository skill through Microsoft SkillOpt-Sleep using reviewed task evidence, bounded edits, held-out validation, staged proposals, and explicit adoption. Use when the user asks to optimize, evolve, evaluate, or learn improvements for a repo-local `.agents/skills/*/SKILL.md`. Do not use for ordinary execution of a diagnostic skill.
---

# Optimize Skills

Treat generated edits as proposals. Keep one target skill, one reviewed task set, and one validation decision visible at a time.

## Workflow

1. Read `../../../docs/workflows/skill-optimization.md` and run `skillopt status` plus `skills-validate`.
2. Select exactly one existing repo-local skill. Never target `AGENTS.md`, profile scripts, configuration, or multiple live skills in one run.
3. If no reviewed task file exists, run `skillopt harvest <skill>`. Harvesting is local and read-only, but the generated file contains transcript-derived material under ignored `.skillopt-sleep/review/`.
4. Run `skillopt review <skill> -TasksFile <path>`. Inspect every intent, reference, check, outcome, and split; remove secrets, private data, irrelevant tasks, and weak or circular judges.
5. After human review, run `skillopt approve-tasks <skill> -TasksFile <path> -ConfirmReview`. Approval marks the file; it does not contact a provider.
6. Run `skillopt dry-run <skill> -TasksFile <path>` with the default mock backend first. Resolve malformed tasks or missing held-out coverage.
7. Only after explicit user authorization for provider calls, run `skillopt run <skill> -TasksFile <path> -Backend Codex -AllowProviderCalls`. This may send the reviewed task content to the Codex provider, but never raw transcript files.
8. Read the staged `report.md`, proposed skill, accepted/rejected edits, baseline/candidate scores, and gate decision. Compare the proposal to the live skill with `git diff --no-index` or an equivalent read-only diff.
9. Recommend adoption only when the gate accepted the proposal and the edit remains correct, concise, human/AI compatible, and within the target skill’s scope.
10. Adopt only after explicit user approval with `skillopt adopt <skill> -Staging <path> -ConfirmAdoption`. Then run `skills-validate`, inspect `git diff`, and forward-test the changed skill on a representative task before committing.

## Hard boundaries

- Never pass `--auto-adopt`, enable greedy gating, or schedule unattended optimization.
- Never use an unreviewed task file with a real backend.
- Never commit `.skillopt-sleep/`, raw transcripts, harvested tasks, provider prompts, or evidence logs.
- Do not claim general improvement from one accepted held-out run; report its exact tasks, scores, and limitations.
- Preserve the shell command contract and human-readable workflow. SkillOpt may improve orchestration text, not invent unavailable commands.
