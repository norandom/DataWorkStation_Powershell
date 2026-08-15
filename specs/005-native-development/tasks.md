# Tasks: Native Windows Development Toolchain

**Input**: Design documents from `specs/005-native-development/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, and
`quickstart.md`

**Tests**: Mandatory. Contract selectors are written and observed failing before the corresponding
state or profile behavior is implemented. Live package installation remains an explicit operator
task after synthetic contracts pass.

## Phase 1: Setup and traceability

**Purpose**: Establish the approved feature and executable test boundary.

- [x] T001 Create and validate `specs/005-native-development/spec.md`, `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/native-development-cli.md`, checklist, and initial `traceability.toml`
- [x] T002 Create the dependency-free section runner in `tests/Test-NativeDevelopmentState.ps1` and Pester adapter in `tests/pester/NativeDevelopment.Tests.ps1`
- [x] T003 Add the native-development adapter to `tests/Test-PowerShellTestingState.ps1#Adapters` and the final command to `.specify/ears-sdd.toml`

---

## Phase 2: User Story 1 - Compile from every ordinary shell (Priority: P1) 🎯 MVP

**Goal**: Standalone MSVC and MSBuild are directly available with complete x64 environment state
in PowerShell 5.1 and Core.

**Independent Test**: Run `tests/Test-NativeDevelopmentState.ps1 -Section ModuleContract`,
`MsvcContract`, `ProfileContract`, `EnvironmentContract`, and `DualShellContract`.

- [x] T004 [US1] Add and observe failing module/stage/dependency assertions for REQ-001 and REQ-002 in `tests/Test-NativeDevelopmentState.ps1#ModuleContract`
- [x] T005 [US1] Add and observe failing standalone product, component allowlist, exclusion, Test/JSON, privilege, and no-restart assertions for REQ-003 through REQ-006, REQ-023, and REQ-026 in `tests/Test-NativeDevelopmentState.ps1#MsvcContract`, `#StateContract`, and `#SafetyContract`
- [x] T006 [US1] Add and observe failing dynamic x64 import, command precedence, stable/persistent variable, versioned/process variable, idempotence, and dual-shell assertions for REQ-007 through REQ-012 and REQ-025 in `tests/Test-NativeDevelopmentState.ps1#ProfileContract`, `#EnvironmentContract`, and `#DualShellContract`
- [x] T007 [US1] Implement compiler/component declarations for REQ-004 through REQ-006 in `config/native-development.psd1` using selectors `#MsvcContract` and `#SafetyContract`
- [x] T008 [US1] Implement observational and explicit standalone Build Tools state for REQ-003 through REQ-006, REQ-023, and REQ-026 in `scripts/Set-MsvcBuildToolsState.ps1` using selectors `#MsvcContract`, `#StateContract`, and `#SafetyContract`
- [x] T009 [US1] Implement dynamic idempotent x64 developer-environment import for REQ-007 through REQ-012 and REQ-025 in `profile/NativeDevelopment.ps1` and `scripts/Set-PowerShellProfile.ps1` using selectors `#ProfileContract`, `#EnvironmentContract`, and `#DualShellContract`
- [x] T010 [US1] Add `MsvcBuildTools` catalog/orchestrator integration for REQ-001 and REQ-002 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, then run all US1 selectors to green

---

## Phase 3: User Story 2 - Build CMake and MSBuild projects (Priority: P1)

**Goal**: CMake uses Ninja by default, explicit generators remain valid, and MSBuild stays directly
available.

**Independent Test**: Run `tests/Test-NativeDevelopmentState.ps1 -Section CMakeContract`, then the
explicit `CMakeSmoke` and `MsBuildSmoke` selectors after installation.

- [x] T011 [US2] Add and observe failing focused package, default-generator, project-override, and no-shell assertions for REQ-013, REQ-014, and REQ-018 in `tests/Test-NativeDevelopmentState.ps1#CMakeContract`
- [x] T012 [US2] Add explicit temporary CMake/Ninja and MSBuild fixtures for REQ-020 and REQ-021 in `tests/Test-NativeDevelopmentState.ps1#CMakeSmoke` and `#MsBuildSmoke`
- [x] T013 [US2] Implement official CMake/Ninja package and environment state for REQ-013, REQ-014, REQ-018, and REQ-023 in `.config/cmake.winget`, `.config/ninja.winget`, and `scripts/Set-CMakeState.ps1` using selector `#CMakeContract`
- [x] T014 [US2] Add `CMake` catalog/orchestrator integration for REQ-001 and REQ-002 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, then run `#CMakeContract` to green

---

## Phase 4: User Story 3 - Develop Rust with the native ABI (Priority: P1)

**Goal**: Official rustup supplies stable x64 MSVC Rust with declared user directories and no
forced project override.

**Independent Test**: Run `tests/Test-NativeDevelopmentState.ps1 -Section RustContract`, then the
explicit `RustSmoke` selector after installation.

- [x] T015 [US3] Add and observe failing official-package, stable-host, directory, PATH, override-absence, and GNU-exclusion assertions for REQ-015 through REQ-018 in `tests/Test-NativeDevelopmentState.ps1#RustContract` and `#SafetyContract`
- [x] T016 [US3] Add explicit temporary rustc and Cargo fixtures for REQ-022 in `tests/Test-NativeDevelopmentState.ps1#RustSmoke`
- [x] T017 [US3] Implement official rustup, stable MSVC, user-directory, PATH, and override-preservation state for REQ-015 through REQ-018 and REQ-023 in `.config/rustup.winget` and `scripts/Set-RustState.ps1` using `#RustContract`
- [x] T018 [US3] Add `RustToolchain` catalog/orchestrator integration with the compiler dependency for REQ-001 and REQ-002 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, then run `#RustContract` to green

---

## Phase 5: User Story 4 - Develop Java and run Ghidra with one JDK (Priority: P1)

**Goal**: Microsoft OpenJDK 21 provides Java development commands in both shells and is shared with
the existing Ghidra prerequisite.

**Independent Test**: Run `tests/Test-NativeDevelopmentState.ps1 -Section JavaContract`, then the
explicit `JavaSmoke` selector after installation.

- [x] T019 [US4] Add and observe failing package, dynamic JAVA_HOME, normalized PATH, command-version, dual-shell, and Ghidra-reuse assertions for REQ-027 through REQ-030 in `tests/Test-NativeDevelopmentState.ps1#JavaContract` and `#DualShellContract`
- [x] T020 [US4] Add an explicit temporary Java compile/run fixture for REQ-031 in `tests/Test-NativeDevelopmentState.ps1#JavaSmoke`
- [x] T021 [US4] Implement official OpenJDK 21 package, dynamic root, JAVA_HOME, normalized PATH, and Ghidra-reuse state for REQ-027 through REQ-030 in `.config/java.winget`, `config/native-development.psd1`, and `scripts/Set-JavaState.ps1` using `#JavaContract`
- [x] T022 [US4] Add `JavaToolchain` catalog/orchestrator integration for REQ-001, REQ-002, and REQ-030 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, then run `#JavaContract` to green

---

## Phase 6: User Story 5 - Manage and validate the aggregate safely (Priority: P2)

**Goal**: One focused aggregate plan/test/ensure coordinates all dependencies, while smoke
execution and the large privileged install remain explicit.

**Independent Test**: Run `tests/Test-NativeDevelopmentState.ps1 -Section IntegrationContract`,
`CommandSurface`, and the explicit post-install smoke selectors.

- [x] T023 [US5] Add and observe failing aggregate dependency, bounded JSON, non-mutating Test, explicit Smoke, and command/documentation assertions for REQ-001 through REQ-003, REQ-019 through REQ-024, REQ-026, and REQ-031 in `tests/Test-NativeDevelopmentState.ps1#IntegrationContract` and `#CommandSurface`
- [x] T024 [US5] Implement aggregate observation and explicit benign smoke orchestration for REQ-019 through REQ-023 and REQ-031 in `scripts/Set-NativeDevelopmentState.ps1` using `#IntegrationContract` and smoke selectors
- [x] T025 [US5] Add `NativeDevelopment` aggregate catalog/orchestrator integration for REQ-001 through REQ-003 in `config/workstation-modules.psd1` and `Apply-Workstation.ps1`, then run `#ModuleContract` and `#IntegrationContract` to green
- [x] T026 [US5] Update capability routing and human documentation for REQ-024 in `config/capabilities.psd1`, `README.md`, `docs/desired-state.md`, `docs/workstation-modules.md`, `docs/Aliases.md`, and `docs/sample-outputs.md` using `#CommandSurface`
- [x] T027 Promote all safely automated selectors in `specs/005-native-development/traceability.toml` and run `ears-sdd validate --phase final`
- [x] T028 Run focused Test, explain the multi-gigabyte privileged Build Tools and package impact, then explicitly Ensure `NativeDevelopment`; record host evidence in `specs/005-native-development/verification-log.md`
- [x] T029 Run direct command resolution plus C, C++, CMake, MSBuild, rustc, Cargo, and Java smoke tests in both declared shell contexts; record results in `specs/005-native-development/verification-log.md`
- [x] T030 Run modern and compatibility Pester, `lint-powershell`, Tricky human/JSON smoke, strict MkDocs, `git diff --check`, and the final EARS gate

## Dependencies and execution order

- Phase 1 blocks every story.
- US1 provides the linker and profile environment required by US2 smoke and US3 native linking.
- US2 and US3 focused contract implementation can proceed independently after the US1 catalog and
  environment contracts are stable.
- US4 can proceed after Phase 1 and shares only its package identifier with optional Ghidra state.
- US5 depends on all focused modules.
- Within every story, failing tests precede implementation and trace promotion follows passing tests.

## Requirement coverage

| Requirements | Failing-test task | Implementation/verification tasks |
|---|---|---|
| REQ-001, REQ-002 | T004, T019, T023 | T010, T014, T018, T022, T025 |
| REQ-003, REQ-023, REQ-026 | T005, T023 | T008, T013, T017, T024, T028 |
| REQ-004, REQ-005, REQ-006 | T005 | T007, T008 |
| REQ-007–REQ-012, REQ-025 | T006 | T009, T025 |
| REQ-013, REQ-014 | T011 | T013, T014, T025 |
| REQ-015–REQ-018 | T011, T015 | T013, T017, T018, T025 |
| REQ-019–REQ-022 | T012, T016, T023 | T024, T029 |
| REQ-024 | T023 | T026, T030 |
| REQ-027–REQ-030 | T019 | T021, T022, T029 |
| REQ-031 | T020, T023 | T024, T029 |

Coverage: 31 of 31 requirements have preceding failing-test tasks and named remediation or
verification tasks.

## Completion conditions

- All 30 tasks use stable checklist IDs and concrete paths.
- Every behavior task names requirements and selectors.
- Live package mutation occurs only in T028 after synthetic gates pass.
- All tasks are checked only after their stated evidence exists.
