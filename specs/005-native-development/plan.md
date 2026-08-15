# Implementation Plan: Native Windows Development Toolchain

**Branch**: `main` | **Date**: 2026-08-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-native-development/spec.md`

## Summary

Add a compact, native Windows x64 development toolchain as five focused Extended-stage modules:
standalone MSVC Build Tools, CMake plus Ninja, rustup plus the stable MSVC toolchain, Microsoft
OpenJDK 21, and an aggregate integration gate. A managed profile component imports the current Microsoft developer
environment into every PowerShell 5.1/Core session while stable user variables remain desired
state. Test mode is observational; the privileged Build Tools install is explicit and never
restarts Windows.

## Technical Context

**Language/Version**: Windows PowerShell 5.1-compatible desired-state scripts; PowerShell 7.6+ default lane

**Primary Dependencies**: WinGet, Visual Studio Build Tools 2022, MSVC v143 x64/x86 component, Windows 11 SDK 26100 component, CMake, Ninja, rustup stable MSVC, Microsoft OpenJDK 21 LTS

**Storage**: Existing package registrations, Visual Studio instance catalog, per-user environment variables, managed PowerShell profile components

**Testing**: Dependency-free PowerShell contract harness, Pester 6 adapters, synthetic environment fixtures, live focused Test/Ensure, temporary compile/link/run fixtures

**Target Platform**: x64 Windows 11 Pro; Windows PowerShell 5.1 and newest installed PowerShell Core

**Project Type**: PowerShell workstation desired-state and operator CLI

**Performance Goals**: Profile initialization occurs once per shell and subsequent initialization is constant-time; smoke fixtures complete within two minutes each

**Constraints**: No Visual Studio IDE, MinGW, MSYS/MSYS2, Cygwin, Git Bash, ARM toolsets, UWP, ATL/MFC, or C++/CLI; no automatic restart; preserve unrelated user environment and project overrides

**Scale/Scope**: Five modules, one profile component, four focused state resources, one integration resource, and seven smoke fixtures

## Constitution Check

- **Human/AI parity**: Every module has a documented `Apply-Workstation.ps1` plan/test/ensure command and each focused resource remains directly runnable.
- **Evidence before mutation**: Package, component, environment, and command state are tested before Ensure. Compile smoke tests use generated benign temporary fixtures rather than existing project code.
- **EARS/TDD**: All 31 requirements have planned selectors; contract tests fail before implementation and trace mappings are promoted only after passing.
- **Focused desired state**: MSVC, CMake, Rust, Java, and aggregate integration remain separate catalog modules with explicit stage, runtime, privilege, and dependency metadata.
- **Deterministic interfaces**: Resources default to human output, support bounded `-Json`, return nonzero drift, and declare PowerShell runtime compatibility.
- **Platform safety**: Build Tools installation is the only privileged boundary; component allowlists exclude the IDE and Unix-emulation toolchains; installers use `--norestart`.

No constitutional exception is required. The same checks still pass after Phase 1 design.

## Project Structure

### Documentation (this feature)

```text
specs/005-native-development/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── traceability.toml
├── checklists/requirements.md
├── contracts/native-development-cli.md
└── tasks.md
```

### Source Code (repository root)

```text
.config/
├── cmake.winget
├── java.winget
├── ninja.winget
└── rustup.winget
config/
└── native-development.psd1
profile/
└── NativeDevelopment.ps1
scripts/
├── Set-MsvcBuildToolsState.ps1
├── Set-CMakeState.ps1
├── Set-JavaState.ps1
├── Set-RustState.ps1
└── Set-NativeDevelopmentState.ps1
tests/
├── Test-NativeDevelopmentState.ps1
└── pester/NativeDevelopment.Tests.ps1
```

Existing integration points change narrowly: `Apply-Workstation.ps1`,
`config/workstation-modules.psd1`, `config/capabilities.psd1`,
`scripts/Set-PowerShellProfile.ps1`, README, desired-state/module/alias/sample-output docs, and the
Pester adapter inventory.

**Structure Decision**: Reuse the repository's focused PowerShell resource pattern. Package
declarations remain separate from state logic, the profile owns process-scoped developer variables,
and test fixtures are generated under temporary directories.

## Requirement-to-design translation

| Requirements | Design decision | Verification |
|---|---|---|
| REQ-001, REQ-002 | Five Extended-stage catalog entries; aggregate dependencies pull focused modules and the managed profile | `ModuleContract` |
| REQ-003, REQ-023, REQ-026 | Test-only observation, bounded JSON, explicit privilege/restart fields, and no restart command | `StateContract`, `SafetyContract` |
| REQ-004, REQ-005, REQ-006 | Build Tools product with only VC x64/x86 and Windows SDK component IDs; required dependencies implicit; explicit excluded-component audit | `MsvcContract` |
| REQ-007, REQ-008, REQ-009, REQ-011, REQ-025 | Idempotent profile component locates the latest compatible instance and imports `VsDevCmd` x64 environment once per shell | `ProfileContract`, `DualShellContract` |
| REQ-010 | User-scoped `CC=cl.exe` and `CXX=cl.exe`, refreshed into the current process | `EnvironmentContract` |
| REQ-012 | Same component is deployed and launched under both PowerShell runtimes | `DualShellContract` |
| REQ-013, REQ-014 | Separate CMake and Ninja package declarations; user `CMAKE_GENERATOR=Ninja`; explicit `-G` remains authoritative | `CMakeContract`, `CMakeSmoke` |
| REQ-015, REQ-016, REQ-017 | Official rustup package, stable x64 MSVC default, user Rust directories and cargo path, absent forced target variables | `RustContract`, `RustSmoke` |
| REQ-018 | Package/component exclusion allowlist and negative command/source assertions | `SafetyContract` |
| REQ-019 | Temporary C and C++ compile/link/run fixtures | `CompilerSmoke` |
| REQ-020 | Temporary CMake/Ninja project | `CMakeSmoke` |
| REQ-021 | Temporary MSBuild project that invokes the native compiler | `MsBuildSmoke` |
| REQ-022 | Temporary rustc executable and Cargo test crate | `RustSmoke` |
| REQ-024 | Capability route and human documentation updated atomically | `CommandSurface`, strict MkDocs |
| REQ-027, REQ-028, REQ-029 | Official OpenJDK 21 package, dynamic JDK root, normalized user environment, and dual-shell commands | `JavaContract`, `DualShellContract`, `JavaSmoke` |
| REQ-030 | Ghidra package declaration reuses the same OpenJDK identifier and no private runtime is introduced | `JavaContract`, `SafetyContract` |
| REQ-031 | Temporary Java compile/run fixture | `JavaSmoke` |

## Complexity Tracking

No constitution violations or exceptional architecture are introduced.
