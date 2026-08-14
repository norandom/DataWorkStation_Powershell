# Codex skills

Repository-local skills live under `.agents/skills/`, which Codex discovers while working in this repository. Each skill handles one decision domain and calls the same commands documented for humans.

| Skill | Use it for |
|---|---|
| `diagnose-problem` | Route an ambiguous “not working” report |
| `diagnose-network` | DNS, IPv6, ports, firewall, and reachability |
| `investigate-crash` | Silent exits, faults, hangs, dumps, and event evidence |
| `diagnose-memory` | RAM, commit, WSL, containers, and kernel pools |
| `profile-native` | Native or system-wide WPR/WPA profiling |
| `profile-python` | Python py-spy flame graphs |
| `profile-dotnet` | .NET EventPipe and Speedscope |
| `maintain-workstation` | Desired-state testing and repair |
| `is-this-malware` | Host-safe static triage, isolated parsing, and explicitly approved Sandbox detonation |
| `optimize-skills` | Review, gate, stage, and explicitly adopt one SkillOpt proposal |

Skills must inspect evidence before starting capture and must not change privileged state without making the exact action visible. Their descriptions are narrow so implicit activation selects one specialist rather than loading an omnibus runbook.

Skill improvement follows the same rule: `optimize-skills` operates on one selected skill from a reviewed task file. Microsoft SkillOpt stages proposals under ignored local state; it never receives permission to auto-adopt or rewrite the repository contract.
