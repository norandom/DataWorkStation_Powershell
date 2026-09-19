---
name: diagnose-problem
description: Route an ambiguous Windows workstation failure such as "this tool is not working," unexplained errors, or mixed symptoms across events, networking, memory, crashes, and performance. Use when the correct evidence source is not yet clear. Do not use when the request already clearly belongs to a narrower network, crash, memory, or profiling skill.
---

# Diagnose a Problem

Create a bounded, evidence-first investigation that a human can inspect and continue.

## Workflow

1. Read `../../../AGENTS.md` and `../../../docs/workflows/problem-not-working.md`.
2. State the observed behavior, target, time window, and expected behavior. Do not invent missing facts.
   Record executable/build, working-machine comparison and actual user/SID; the shell's HKCU may
   differ from the affected user's. Search exact build/error combinations early when regression is plausible.
3. Create a case with `tricky new <name> -Problem '<behavior>' -Target '<target>'` unless an existing case already covers it.
4. Add existing evidence with `tricky add <name> -Path <path>`. References are preferred for large traces; use `-Copy` only for a portable bundle.
5. Run `tricky inspect <name> -Json`. Treat its recommendation as routing advice, not proof of cause.
6. Inspect relevant existing evidence before collecting more. Prefer the specialist skill selected by the symptom and artifact type.
7. If a concrete evidence gap remains, propose the smallest exact capture command, duration or stop condition, privilege requirement, and expected artifact. Do not start it without user authorization when it changes state or records external activity.
8. Run `tricky report <name>` after evidence changes. Report observations, inferences, competing explanations, gaps, and next action separately.
   Use `tricky note <case> -NoteType Observation|Hypothesis|Contradiction|Change|Result|NextStep -Message <text>`
   to keep those findings in the case. Changes need original state, backup, prediction, result and rollback decision.

## Routing

- DNS, IPv6, firewall, ports, or reachability: use `$diagnose-network`.
- HTTP status, TLS negotiation or authenticated service operations: use `$diagnose-http`.
- Crash, segfault, silent exit, exception, or hang: use `$investigate-crash`.
- RAM, commit, WSL, container, or pool growth: use `$diagnose-memory`.
- Native/system CPU: use `$profile-native`.
- Python CPU: use `$profile-python`.
- .NET CPU: use `$profile-dotnet`.

Never start every tracer for a generic failure.
An error dialog or the request to "debug" an executable does not by itself imply a crash.
Artifact existence does not establish coverage: check target, reproduction window, event count and loss.
