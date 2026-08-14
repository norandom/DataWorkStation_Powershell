<!--
Sync Impact Report
- Version change: template -> 1.0.0
- Added principles:
  - I. Human/AI Command Parity
  - II. Evidence Before Capture or Mutation
  - III. EARS Traceability and Test-First Change
  - IV. Focused Desired State and Dependency Safety
  - V. Deterministic Operator Interfaces
- Added sections:
  - Platform and Safety Constraints
  - Development and Publication Workflow
- Removed sections: none; template placeholders were resolved.
- Deferred items: none.
-->
# DataWorkStation PowerShell Constitution

## Core Principles

### I. Human/AI Command Parity
Every AI workflow MUST be grounded in a documented, human-readable command that an operator can
run directly. Skills MAY compose those commands, but MUST NOT hide a separate automation-only
implementation. `config/capabilities.psd1` MUST remain the routing catalog when commands or
evidence types change. This keeps diagnosis, desired state, and recovery inspectable without an
agent.

### II. Evidence Before Capture or Mutation
Existing EVTX, ETL, PCAPNG, dump, profile, and snapshot evidence MUST be inspected before another
capture is started. Privileged or state-changing operations MUST remain explicit and MUST NOT
silently capture, attach, kill, remove software, disable protection, reinitialize policy, or reboot
Windows. Test and plan operations MUST be observational. This reduces avoidable system changes and
preserves the provenance of diagnostic evidence.

### III. EARS Traceability and Test-First Change
Every normative feature requirement MUST have one stable `REQ-NNN` identifier, exactly one EARS
`shall` obligation, and a verification mapping in the feature's `traceability.toml`. New behavior
MUST begin with a failing automated test, followed by the smallest implementation change and a
passing regression run. Brownfield behavior MAY enter through an explicitly identified
characterization or manual verification, but its migration tasks MUST place automated
characterization before behavior-changing work. Requirement prose and identifiers MUST NOT bleed
into production code merely to satisfy validation.

### IV. Focused Desired State and Dependency Safety
Workstation state MUST be divided into focused modules with declared dependencies, supported modes,
privilege, destructiveness, and stable execution order in `config/workstation-modules.psd1`.
Dependencies MUST be tested or ensured before dependants use them. Destructive modules MUST be
opt-in and require explicit confirmation. Repository skills MUST remain focused and separate; an
omnibus workstation skill is prohibited. These constraints make partial application predictable
and keep high-risk state visible.

### V. Deterministic Operator Interfaces
Human output MUST be the default, and machine consumption MUST use explicit structured output such
as `tricky ... -Json`. Commands MUST return actionable nonzero failures where their contract
requires a gate. PowerShell 7 and inbox Windows PowerShell 5.1 compatibility MUST be preserved where
the command documentation declares it. Examples and expected output MUST be kept with the operator
documentation so behavior is reviewable before execution.

## Platform and Safety Constraints

- Windows 11 Pro is the supported host because the managed baseline uses Hyper-V, Windows Sandbox,
  Windows sudo, and other Pro workstation capabilities.
- Local configuration, credentials, licenses, machine paths, evidence, and generated state MUST NOT
  be committed unless a reviewed public sample exists and the data is safe to publish.
- Security controls, hardening, Defender exclusions, firewall policy, Sandbox, debloat, WSL, and
  debugger operations MUST document their privilege boundary and residual attack surface.
- SkillOpt MUST target one explicit skill from reviewed tasks, keep gating enabled, stage proposals
  by default, and require explicit adoption. It MUST NOT run unattended optimization.
- Native PowerShell tooling MUST NOT depend on Git Bash, MinGit, MSYS, MSYS2, or Cygwin unless a
  future specification explicitly changes that platform decision.

## Development and Publication Workflow

1. Specify observable behavior as EARS requirements and acceptance scenarios.
2. Complete requirement-to-test or justified manual traceability before implementation planning is
   approved.
3. Generate dependency-ordered tasks; every behavior task MUST name its requirement and put the
   failing test task first.
4. Implement only approved tasks, preserving unrelated worktree changes and explicit privilege
   boundaries.
5. Before publishing, run `lint-powershell`, Tricky human and JSON smoke tests, and
   `uv run --group docs mkdocs build --strict`.
6. Update operator documentation, sample output, capability routing, and release notes whenever a
   public command or state contract changes.

## Governance

This constitution governs specifications, plans, tasks, implementation, review, and publication in
this repository. Amendments require a documented rationale, a semantic-version change, an impact
report, and updates to affected artifacts. MAJOR versions remove or redefine a principle, MINOR
versions add or materially expand governance, and PATCH versions clarify existing rules. Every
feature review MUST check constitution compliance; an exception requires an explicit Complexity
Tracking entry in its plan and cannot silently weaken a MUST requirement.

**Version**: 1.0.0 | **Ratified**: 2026-08-13 | **Last Amended**: 2026-08-14
