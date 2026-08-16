# Codex skills

Repository-local skills live under `.agents/skills/`. Each skill covers one decision domain and
calls the same commands documented for operators.

| Skill | Use it for |
|---|---|
| `diagnose-problem` | Route an ambiguous "not working" report |
| `diagnose-network` | DNS, IPv6, ports, firewall, and reachability |
| `investigate-crash` | Silent exits, faults, hangs, dumps, and event evidence |
| `diagnose-memory` | RAM, commit, WSL, containers, and kernel pools |
| `profile-native` | Native or system-wide WPR/WPA profiling |
| `profile-python` | Python py-spy flame graphs |
| `profile-dotnet` | .NET EventPipe and Speedscope |
| `maintain-workstation` | Desired-state testing and repair |
| `is-this-malware` | Host-safe static triage, isolated parsing, and explicitly approved Sandbox detonation |
| `optimize-skills` | Review, gate, stage, and explicitly adopt one SkillOpt proposal |

Skills inspect existing evidence before starting a capture. They show the exact action before
changing privileged state. Narrow descriptions route a task to one specialist workflow.

`optimize-skills` works on one selected skill from a reviewed task file. Microsoft SkillOpt stages
proposals under ignored local state. It cannot auto-adopt a proposal or rewrite the repository
contract.
