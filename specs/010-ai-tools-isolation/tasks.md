# Tasks: AI Tools and WSL Isolation

**Input**: Design documents from `specs/010-ai-tools-isolation/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/commands.md`,
`quickstart.md`

**Tests**: Mandatory. Every behavior group starts with a focused failing selector. Automated
validation must not execute installers, mutate WSL state, terminate distributions, launch an
agent, or transfer real evidence.

## Phase 1: Setup and Red Evidence

- [X] T001 Record official delivery identities, WSL/nono limitations, Berg source pin, brownfield paths, and rejected alternatives in `specs/010-ai-tools-isolation/research.md`
- [X] T002 Run the spec and plan EARS gates for `specs/010-ai-tools-isolation/traceability.toml` and record zero findings before implementation
- [X] T003 Add all 37 focused selectors to `tests/Test-AiToolsIsolation.ps1`, run `-Section All`, and preserve the missing `config/ai-tools.psd1` red result for REQ-001–REQ-037

---

## Phase 2: Foundational Contracts

**Purpose**: Establish reviewed identities, injected adapters, streaming helpers, and routing
shapes shared by the user stories.

- [X] T004 Add canonical tool, editor, AI-NixOS, and four-distribution trust declarations in `config/ai-tools.psd1`, `config/developer-editor.psd1`, `config/ai-nixos-wsl.psd1`, and `config/wsl-trust-boundaries.psd1` for REQ-001–REQ-012, REQ-014, REQ-016, and REQ-023–REQ-032 using `#EnabledProducts`, `#OpenCodeTargets`, `#EditorInventory`, `#AiDistributionIdentity`, `#NonoInstallChannel`, and `#TrustMatrixStatus`
- [X] T005 Add deterministic observation/rendering and injected process/filesystem boundaries in `scripts/AiTools.Core.ps1`, `scripts/DeveloperEditor.Core.ps1`, and `scripts/WslBoundary.Core.ps1` for REQ-003–REQ-004, REQ-013, and REQ-032–REQ-033 using `#ObservationalStatus`, `#OutputParity`, `#EditorMerge`, `#TrustMatrixStatus`, and `#BoundaryFailure`
- [X] T006 Extend four-way local WSL selector parsing and distinct-name validation in `.wsl-env.sample` and `scripts/Import-WslEnvironment.ps1` for REQ-014 and REQ-032 using `#AiDistributionIdentity` and `#TrustMatrixStatus`
- [X] T007 Add the opt-in governed module and capability skeletons in `config/workstation-modules.psd1`, `Apply-Workstation.ps1`, and `config/capabilities.psd1` for REQ-002, REQ-035, and REQ-036 using `#OptInBoundary`, `#RoutingAndDocumentation`, and `#FocusedModuleBoundary`

**Checkpoint**: Synthetic records can be evaluated without live vendor/WSL state and the feature is
governed before its state commands can be published.

---

## Phase 3: User Story 1 - Select and Maintain AI Tools (Priority: P1) MVP

**Goal**: Report and explicitly reconcile only the five enabled Windows products through their
reviewed channels, with OpenCode CLI reserved for AI NixOS.

**Independent Test**: Inject absent/compliant/wrong-channel/failing installer records; Test/Plan
remain observational, output matches JSON, Ensure selects the exact channel, and unrelated tools
are untouched.

### Tests for User Story 1

- [X] T008 [US1] Run and refine the failing `#EnabledProducts`, `#OptInBoundary`, `#ObservationalStatus`, `#OutputParity`, and `#OpenCodeTargets` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-001–REQ-005 before implementation
- [X] T009 [P] [US1] Run and refine the failing `#ClaudeInstallChannel`, `#AntigravityCliChannel`, `#ClineCliChannel`, and `#CopilotCli` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-006–REQ-009 before implementation

### Implementation for User Story 1

- [X] T010 [US1] Implement human/JSON Test and Plan plus explicit Ensure orchestration in `scripts/Set-AiToolsState.ps1` for REQ-001–REQ-005 using `#EnabledProducts`, `#OptInBoundary`, `#ObservationalStatus`, `#OutputParity`, and `#OpenCodeTargets`
- [X] T011 [US1] Implement exact Claude and Antigravity official-script invocations without WinGet fallback in `scripts/Set-AiToolsState.ps1` and `config/ai-tools.psd1` for REQ-006–REQ-007 using `#ClaudeInstallChannel` and `#AntigravityCliChannel`
- [X] T012 [US1] Implement exact Cline and GitHub Copilot global npm package reconciliation in `scripts/Set-AiToolsState.ps1` for REQ-008–REQ-009 using `#ClineCliChannel` and `#CopilotCli`
- [X] T013 [US1] Implement pinned official OpenCode Desktop download, digest/signature verification, and Windows-only observation in `scripts/Set-AiToolsState.ps1` for REQ-005 and REQ-034 using `#OpenCodeTargets` and `#UpdateRevalidation`
- [X] T014 [US1] Add synthetic installer/provenance failure coverage and make all US1 selectors pass in both PowerShell runtimes without executing a vendor installer in `tests/Test-AiToolsIsolation.ps1` for REQ-001–REQ-009 and REQ-034

**Checkpoint**: The native AI category is independently inspectable and opt-in; selected Ensure
commands have no undeclared source fallback.

---

## Phase 4: User Story 2 - Run OpenCode in a Layered AI Sandbox (Priority: P1)

**Goal**: Provision and integrity-check a separate restricted AI NixOS, then launch its root-owned
OpenCode only through a maintenance-owned, reviewed, fail-closed nono boundary.

**Independent Test**: Synthetic Nix/integrity/runtime adapters and benign path/network probes prove
the project grant, every denial, child inheritance, policy drift handling, and refusal before agent
startup when any prerequisite is missing.

### Tests for User Story 2

- [X] T015 [US2] Run and refine failing `#AiDistributionIdentity`, `#AiNixIntegrity`, `#AiDailyPrivilege`, `#AiInteropBoundary`, and `#AiMountBoundary` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-014–REQ-015 and REQ-023–REQ-025 before implementation
- [X] T016 [P] [US2] Run and refine failing `#NonoInstallChannel`, `#NonoLaunchContract`, `#NonoFailClosed`, `#NonoFilesystemPolicy`, `#NonoCredentialPolicy`, `#NonoNetworkPolicy`, and `#NonoProfileDrift` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-016–REQ-022 before implementation

### Implementation for User Story 2

- [X] T017 [US2] Add the locked restricted AI generation, non-root daily user, non-login maintenance owner, root-owned OpenCode/launcher/policy, and four-layer self-check in `nixos-ai/flake.nix`, `nixos-ai/flake.lock`, `nixos-ai/configuration.nix`, `nixos-ai/local.nix.in`, and `nixos-ai/self-check.nix` for REQ-014–REQ-016 and REQ-023–REQ-025 using `#AiDistributionIdentity`, `#AiNixIntegrity`, `#NonoInstallChannel`, `#AiDailyPrivilege`, `#AiInteropBoundary`, and `#AiMountBoundary`
- [X] T018 [US2] Add the reviewed official-lineage project/credential/socket/network policy in `nixos-ai/opencode-profile.json` and pin its digest in `config/ai-nixos-wsl.psd1` for REQ-017 and REQ-019–REQ-022 using `#NonoFilesystemPolicy`, `#NonoCredentialPolicy`, `#NonoNetworkPolicy`, and `#NonoProfileDrift`
- [X] T019 [US2] Implement pinned image provisioning, stdin-only source deployment, explicit selected-distro restart, Windows-initiated maintenance-owned `brew install nono`, and full integrity Test/Plan/Ensure in `scripts/Set-AiNixOsWslState.ps1` for REQ-014–REQ-016, REQ-018, and REQ-023–REQ-025 using `#AiNixIntegrity`, `#NonoInstallChannel`, `#NonoFailClosed`, `#AiDailyPrivilege`, `#AiInteropBoundary`, and `#AiMountBoundary`
- [X] T020 [US2] Implement project validation and the immutable guest preflight/exec contract in `scripts/Invoke-OpenCodeSandbox.ps1` for REQ-017–REQ-022 using `#NonoLaunchContract`, `#NonoFailClosed`, `#NonoFilesystemPolicy`, `#NonoCredentialPolicy`, `#NonoNetworkPolicy`, and `#NonoProfileDrift`
- [X] T021 [US2] Add benign synthetic boundary probes including missing/patched nono, user-D-Bus, escaping symlink, child process, forbidden path, and unavailable secure network enforcement in `tests/Test-AiToolsIsolation.ps1` for REQ-017–REQ-025, then make every US2 selector pass under both PowerShell runtimes

**Checkpoint**: A managed OpenCode launch cannot fall back to unsandboxed execution and the AI
daily account cannot persistently replace its launcher, policy, OpenCode, or nono binary.

---

## Phase 5: User Story 3 - Preserve WSL Credential Boundaries (Priority: P1)

**Goal**: Restrict AI, DevOps NixOS, and Debian-MW; inspect credential metadata without reading
secrets; keep ordinary Debian explicitly trusted.

**Independent Test**: Synthetic/live-read-only trust reports cover all four distributions and fail
for interop, automount, sudo, shared mounts/sockets, Windows-linked credentials, permissive modes,
or wrong roles.

### Tests for User Story 3

- [X] T022 [US3] Run and refine failing `#DevOpsInteropBoundary`, `#DevOpsCredentialBoundary`, `#MalwareWslBoundary`, `#TrustedDebianRole`, `#TrustMatrixStatus`, and `#BoundaryFailure` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-026–REQ-028 and REQ-031–REQ-033 before implementation

### Implementation for User Story 3

- [X] T023 [US3] Disable DevOps NixOS interop/automount and replace DrvFS deployment with root-owned standard-input streaming in `nixos/configuration.nix` and `scripts/Set-NixOsWslState.ps1` for REQ-026 using `#DevOpsInteropBoundary`
- [X] T024 [US3] Add metadata-only DevOps credential ownership/mode/link/socket inspection and the canonical four-distribution human/JSON report in `scripts/WslBoundary.Core.ps1` and `scripts/Test-WslTrustBoundary.ps1` for REQ-027 and REQ-032–REQ-033 using `#DevOpsCredentialBoundary`, `#TrustMatrixStatus`, and `#BoundaryFailure`
- [X] T025 [US3] Disable Debian-MW interop/automount/no-sudo drift and replace its pyinfra DrvFS dependency with standard-input staging in `scripts/Set-RootlessPodmanState.ps1` and `config/wsl-trust-boundaries.psd1` for REQ-028 and REQ-033 using `#MalwareWslBoundary` and `#BoundaryFailure`
- [X] T026 [US3] Document ordinary Debian as the only trusted integrated utility environment and prohibit AI/hostile/key-storage routing to it in `docs/ai-tools-isolation.md`, `docs/nixos-wsl.md`, and `docs/malware-analysis.md` for REQ-031 using `#TrustedDebianRole`
- [X] T027 [US3] Add synthetic trust-matrix fixtures and make all US3 selectors pass in both PowerShell runtimes without starting/stopping a distribution or reading secret contents in `tests/Test-AiToolsIsolation.ps1` for REQ-026–REQ-028 and REQ-031–REQ-033

**Checkpoint**: All four roles are visible; restricted guests lack routine host-crossing primitives;
Windows remains the explicit residual administrator.

---

## Phase 6: User Story 4 - Stage Hostile Files in Debian-MW (Priority: P2)

**Goal**: Import a bounded case into the private Debian-MW filesystem and export attributable
results without mounting Windows inside the analysis distribution.

**Independent Test**: A benign fixture round trip preserves hashes; existing targets, reparse
points, links, traversal, sockets/devices, and out-of-case members fail before commit.

### Tests for User Story 4

- [X] T028 [US4] Run and refine failing `#MalwareCaseImport` and `#MalwareCaseExport` selectors with benign synthetic stream adapters in `tests/Test-AiToolsIsolation.ps1` for REQ-029–REQ-030 before implementation

### Implementation for User Story 4

- [X] T029 [US4] Implement bounded Windows validation, private guest staging, tar streaming, guest post-validation, SHA-256 inventory, and no-overwrite receipt in `scripts/Import-MalwareCase.ps1` for REQ-029 using `#MalwareCaseImport`
- [X] T030 [US4] Implement bounded guest result validation, tar streaming to a new Windows staging directory, post-extraction validation, SHA-256 receipt, and atomic destination commit in `scripts/Export-MalwareCase.ps1` for REQ-030 using `#MalwareCaseExport`
- [X] T031 [US4] Add traversal/link/interruption/hash-mismatch/existing-target fixtures and make all US4 selectors pass in both PowerShell runtimes without transferring real evidence in `tests/Test-AiToolsIsolation.ps1` for REQ-029–REQ-030

**Checkpoint**: Debian-MW static analysis no longer needs general Windows-drive visibility.

---

## Phase 7: User Story 5 - Maintain the Windows Developer Editor (Priority: P2)

**Goal**: Maintain stable VS Code, pinned-source Berg, four extensions, and local Berkeley Mono or
public Fira fallback while preserving unrelated editor state.

**Independent Test**: Synthetic settings and extension inventories cover local/fallback fonts,
withdrawn or wrong-publisher extensions, Berg hash drift, and preservation of unrelated keys.

### Tests for User Story 5

- [X] T032 [US5] Run and refine failing `#EditorInventory`, `#LocalFontPreference`, `#PortableFontFallback`, and `#EditorMerge` selectors in `tests/Test-AiToolsIsolation.ps1` for REQ-010–REQ-013 before implementation

### Implementation for User Story 5

- [X] T033 [US5] Add focused stable VS Code WinGet declaration and exact extension/Berg/font ownership in `.config/developer-editor.winget` and `config/developer-editor.psd1` for REQ-010–REQ-012 using `#EditorInventory`, `#LocalFontPreference`, and `#PortableFontFallback`
- [X] T034 [US5] Implement package/extension observation, pinned Berg source wrapping, installed-font validation, backup, and bounded settings merge in `scripts/DeveloperEditor.Core.ps1` and `scripts/Set-DeveloperEditorState.ps1` for REQ-010–REQ-013 using `#EditorInventory`, `#LocalFontPreference`, `#PortableFontFallback`, and `#EditorMerge`
- [X] T035 [US5] Add wrong-publisher/Berg-digest/font/settings-preservation fixtures and make all US5 selectors pass in both PowerShell runtimes without installing VS Code or extensions in `tests/Test-AiToolsIsolation.ps1` for REQ-010–REQ-013

**Checkpoint**: The editor story is independently maintainable and does not weaken the AI WSL
boundary.

---

## Phase 8: Cross-Cutting Integration and Publication

- [X] T036 Add update-stage revalidation, ignored runtime/case paths, portable secret exclusions, and Pester adapters in `scripts/Invoke-WorkstationUpdate.ps1`, `.gitignore`, `tests/pester/AiToolsIsolation.Tests.ps1`, and the Pester adapter registry for REQ-034 and REQ-037 using `#UpdateRevalidation` and `#PortableSecretExclusions`
- [X] T037 Update module/capability routing and complete operator/human/JSON examples in `config/workstation-modules.psd1`, `config/capabilities.psd1`, `docs/ai-tools-isolation.md`, `docs/desired-state.md`, `docs/workstation-modules.md`, `docs/sample-outputs.md`, and `mkdocs.yml` for REQ-035–REQ-036 using `#RoutingAndDocumentation` and `#FocusedModuleBoundary`
- [X] T038 Run all 37 selectors under Windows PowerShell 5.1 and PowerShell 7, Pester Core/Desktop adapters, catalog/governance baselines, Nix syntax/evaluation where available, `git diff --check`, and observational human/JSON commands
- [X] T039 Run `lint-powershell`, Tricky human and JSON smokes, `uv run --locked --group docs mkdocs build --strict --site-dir site`, and the Spec feature governance hook without any Ensure command
- [X] T040 Run `ears-sdd validate --feature specs/010-ai-tools-isolation --phase final`, append exact results and the explicit non-mutation record to `specs/010-ai-tools-isolation/quickstart.md`, and confirm every task is complete

---

## Dependencies & Execution Order

- Setup establishes research, traceability, and honest red evidence.
- Foundational contracts block every user story.
- US1 and US5 can proceed independently after the foundation.
- US2 depends on the AI selector/declaration foundation but not on native AI installer completion.
- US3 must finish before US4 because case streaming assumes the restricted Debian-MW boundary.
- Cross-cutting integration depends on every selected story.

## Parallel Opportunities

- T009 can refine vendor-channel tests while T008 refines generic state tests.
- T016 can refine sandbox-policy tests while T015 refines AI NixOS identity tests.
- After Phase 2, US1, US2, US3, and US5 touch mostly separate files; edits to shared catalogs are
  serialized through T007/T037.
- Dual-runtime and Pester lanes in T038 are observational and may run concurrently.

## Implementation Strategy

1. Establish deterministic adapters and catalog governance.
2. Deliver US1 as the smallest visible opt-in tool-selection MVP.
3. Deliver US2 before exposing the managed OpenCode command.
4. Harden and report all WSL roles, then add Debian-MW streaming.
5. Deliver the editor independently and integrate routing/docs last.
6. Never use automated tests to run vendor installers, mutate/restart WSL, launch an agent, or move
   real evidence.

## Requirement Coverage Matrix

| Requirements | Failing-test tasks | Implementation/passing tasks |
|---|---|---|
| REQ-001–REQ-005 | T003, T008 | T004–T007, T010, T013–T014 |
| REQ-006–REQ-009 | T003, T009 | T011–T012, T014 |
| REQ-010–REQ-013 | T003, T032 | T004–T005, T033–T035 |
| REQ-014–REQ-015 | T003, T015 | T004, T006, T017, T019, T021 |
| REQ-016–REQ-022 | T003, T016 | T004, T017–T021 |
| REQ-023–REQ-025 | T003, T015–T016 | T017, T019–T021 |
| REQ-026–REQ-028 | T003, T022 | T023–T025, T027 |
| REQ-029–REQ-030 | T003, T028 | T029–T031 |
| REQ-031–REQ-033 | T003, T022 | T024, T026–T027 |
| REQ-034 | T003, T008–T009 | T013–T014, T036 |
| REQ-035–REQ-036 | T003 | T007, T037–T039 |
| REQ-037 | T003 | T036, T038–T040 |

## Notes

- No task authorizes a live Ensure during implementation validation.
- Production files do not need requirement IDs; tests, tasks, and traceability own that mapping.
- Distribution unregister/removal is outside this feature.

## Phase 9: Convergence

- [X] T041 Add failing executable editor fixtures that prove VS Code inventory discovery of Berg,
  reject an obsolete hash-only wrapper, and select an embedded Berkeley Mono family from the
  per-user Windows font directory per Constitution III, REQ-010–REQ-011, and SC-009 (partial)
- [X] T042 Reconcile and validate the declared `teehausamberg.berg` extension identity/version and
  its `Berg Theme` contribution through the VS Code extension inventory instead of treating a
  downloaded theme digest as installed state per REQ-010 and SC-009 (partial)
- [X] T043 Extend installed-font validation to recognize the embedded family metadata of eligible
  font files in the per-user Windows font directory while preserving the portable Fira fallback
  per REQ-011–REQ-012 and SC-009 (partial)
