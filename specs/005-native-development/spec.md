# Feature Specification: Native Windows Development Toolchain

**Feature Branch**: `main` (working-tree feature)

**Created**: 2026-08-15

**Status**: Implemented and validated

**Input**: User description: "Install a compact standalone Windows C/C++ compiler, Rust, and the Java JDK already selected for Ghidra without Visual Studio, MinGW, MSYS, Cygwin, or Git Bash; keep compiler, build, Rust, Java, and javac commands available in ordinary PowerShell; declare CC, CXX, JAVA_HOME, and related environment state; preserve PowerShell 5.1 and Core compatibility."

**Amended 2026-08-18**: Keep ordinary shells neutral and expose explicit `msvc-activate`; do not
persist `CC` or `CXX`, and import the complete MSVC environment only into the activated process.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Activate compilation from every ordinary PowerShell session (Priority: P1)

A developer opens either supported PowerShell runtime and uses the native x64 compiler, linker, and
build engine after running one consistent activation command, without finding or launching a
special developer prompt.

**Why this priority**: Predictable native compilation without globally shadowing same-named tools
is required by Rust and native project builds.

**Independent Test**: Start clean Windows PowerShell 5.1 and PowerShell Core processes, load the
managed profile, prove MSVC remains inactive, invoke `msvc-activate`, inspect the process
environment, then compile and execute minimal C and C++ programs.

**Acceptance Scenarios**:

1. **Given** a new managed PowerShell session, **When** the profile loads, **Then** `msvc-activate` is available and the MSVC environment remains inactive.
2. **Given** a new managed shell, **When** the developer invokes `msvc-activate` and compiles and links a simple C or C++ source, **Then** the resulting program executes successfully with the declared x64 host and target.
3. **Given** both supported PowerShell runtimes, **When** their explicitly activated native-development environments are compared, **Then** they expose the same toolchain selection and process-only compiler variables.

---

### User Story 2 - Build CMake projects with a compact default (Priority: P1)

A developer configures and builds ordinary CMake projects from PowerShell with a fast command-line
generator while retaining direct access to the Microsoft build engine for projects that require it.

**Why this priority**: CMake and the Microsoft build engine are explicit future project
dependencies, and the compact default avoids installing an IDE.

**Independent Test**: Configure, build, and run a minimal CMake C++ project with the default
generator, then build a minimal project directly with the Microsoft build engine.

**Acceptance Scenarios**:

1. **Given** a project without an explicit generator, **When** it is configured, **Then** the declared compact command-line generator is selected.
2. **Given** a project that directly uses the Microsoft build engine, **When** its project file is built, **Then** the build completes without a Visual Studio IDE.
3. **Given** a project that supplies its own generator, **When** it is configured, **Then** the project choice overrides the workstation default.

---

### User Story 3 - Develop Rust with the native Windows ABI (Priority: P1)

A developer uses Rust's stable native Windows toolchain from any managed shell, while projects can
still select their own Rust release or target.

**Why this priority**: Rust was explicitly requested and must interoperate with the same native
Windows linker and libraries without introducing a Unix-emulation toolchain.

**Independent Test**: Inspect the selected Rust host and user directories, compile and execute a
minimal program, and run a minimal Cargo test.

**Acceptance Scenarios**:

1. **Given** a new managed shell, **When** the developer resolves Rust commands, **Then** the stable native Windows toolchain and package manager are available.
2. **Given** a minimal Rust project, **When** it builds and tests, **Then** it links with the declared native Windows ABI successfully.
3. **Given** a project-local toolchain declaration, **When** a Rust command runs in that project, **Then** the project selection takes precedence over the workstation default.

---

### User Story 4 - Develop Java and run Ghidra with one JDK (Priority: P1)

A developer compiles and runs Java from either managed shell, while Ghidra reuses the same declared
long-term-support JDK instead of owning a second Java installation.

**Why this priority**: The JDK is already a Ghidra prerequisite, and making it a first-class
development dependency prevents optional malware tooling from controlling the general shell.

**Independent Test**: Inspect package and environment state in both shells, compare the runtime and
compiler major versions, then compile and execute a minimal Java source file.

**Acceptance Scenarios**:

1. **Given** a new managed shell, **When** the developer resolves Java tools, **Then** `java`, `javac`, `jar`, and `jshell` are immediately available from the declared JDK 21 installation.
2. **Given** Java state is compliant, **When** runtime and compiler versions are inspected, **Then** both report the same declared major release and `JAVA_HOME` identifies their JDK root.
3. **Given** Ghidra is installed later, **When** its headless launcher resolves Java, **Then** it reuses the independently managed JDK rather than requiring a second package or private runtime.

---

### User Story 5 - Manage a compact toolchain safely (Priority: P2)

A workstation operator can plan, inspect, install, update, or reinitialize each toolchain part
independently and can see the large privileged installation boundary before accepting it.

**Why this priority**: The toolchain is useful only if its substantial disk and privilege impact
remains explicit, repeatable, and separable from ordinary workstation state.

**Independent Test**: Exercise focused plans and synthetic inventories for absent, partial,
compliant, and obsolete state; verify observational tests, dependency order, excluded components,
and human/machine result shapes.

**Acceptance Scenarios**:

1. **Given** an absent toolchain, **When** state is tested, **Then** the missing packages, components, variables, and expected repair impact are reported without changing the host.
2. **Given** explicit repair of one focused module, **When** dependencies are resolved, **Then** only the requested toolchain part and its declared prerequisites are applied.
3. **Given** a compliant installation, **When** repair runs again, **Then** no toolchain or environment state is replaced unnecessarily.

### Edge Cases

- The compiler suite is installed but lacks the x64 compiler or Windows SDK component.
- Multiple Build Tools or Visual Studio instances are registered side by side.
- A native Coreutils `link.exe` precedes the Microsoft linker before shell initialization.
- The current shell started before package installation or upgrade and has a stale process `PATH`.
- A user already has unrelated `PATH` entries or project-specific compiler and Rust configuration.
- A build directory was configured previously with a different CMake generator.
- A Rust project contains a directory override or `rust-toolchain.toml`.
- Multiple JDK releases exist and another Java directory precedes the managed JDK on inherited PATH.
- The JDK package is present for Ghidra but `JAVA_HOME` is absent or points to an obsolete version.
- Package or toolchain downloads fail after a partial installation.
- The Build Tools installer reports a restart requirement.

## Requirements *(mandatory)*

### Functional Requirements

- REQ-001: The workstation catalog shall expose independently selectable native compiler, CMake, Rust, Java, and aggregate native-development modules.
- REQ-002: When a native-development module is planned, the workstation orchestrator shall place every prerequisite in the same or an earlier dependency stage before its dependant.
- REQ-003: When native-development state is tested, the workstation DSL shall report drift and repair impact without installing, updating, or reconfiguring software.
- REQ-004: When compiler state is explicitly ensured, the workstation DSL shall install standalone build tools without installing a Visual Studio IDE.
- REQ-005: When standalone build tools are installed, the workstation DSL shall select only the x64/x86 compiler tools, the Windows SDK, the build engine, and their required dependencies.
- REQ-006: The workstation DSL shall exclude ARM toolsets, ATL/MFC, managed C++ support, UWP tooling, emulation shells, and IDE workloads from declared compiler state.
- REQ-007: When `msvc-activate` is invoked, the profile shall dynamically select the current compatible build-tools instance for an x64 host and x64 target.
- REQ-008: When the native build environment is initialized, the profile shall expose the compiler, Microsoft linker, librarian, native build utility, and build engine directly on the process command path.
- REQ-009: When a conflicting non-Microsoft linker command exists earlier in the inherited path, explicit MSVC activation shall resolve the Microsoft linker for the activated process.
- REQ-010: When compiler state is managed, the workstation shall keep user-scoped `CC` and `CXX` absent and set process-scoped `CC=cl.exe` and `CXX=cl.exe` only after successful MSVC activation.
- REQ-011: When compiler environment state is imported, the profile shall expose the selected include, library, SDK, toolset, and installation variables without persisting version-specific values at user or machine scope.
- REQ-012: When either supported PowerShell runtime loads the managed profile, it shall expose `msvc-activate` without automatically importing the MSVC environment.
- REQ-013: When CMake state is explicitly ensured, the workstation DSL shall install CMake and the compact command-line build backend without installing a Unix shell.
- REQ-014: The managed CMake state shall declare the compact backend as the user default while allowing an explicit project generator to override it.
- REQ-015: When Rust state is explicitly ensured, the workstation DSL shall install the official toolchain manager and select the stable x64 native Windows toolchain.
- REQ-016: The managed Rust state shall declare persistent user directories for toolchains and packages and keep the package command directory on the user path.
- REQ-017: The managed Rust state shall leave project toolchain and target overrides effective by omitting global toolchain-override and build-target variables.
- REQ-018: The native-development feature shall avoid installing or depending on MinGW, MSYS, MSYS2, Cygwin, Git Bash, or a GNU Rust host toolchain.
- REQ-019: When compiler smoke validation runs, it shall compile, link, and execute minimal C and C++ programs in a temporary directory.
- REQ-020: When CMake smoke validation runs, it shall configure, build, and execute a minimal project with the declared default backend.
- REQ-021: When build-engine smoke validation runs, it shall build and execute a minimal project directly with the Microsoft build engine.
- REQ-022: When Rust smoke validation runs, it shall compile and execute a minimal Rust program and complete a minimal package test.
- REQ-023: When a package or component is absent, partial, or obsolete, the workstation DSL shall return a nonzero observational result with actionable human output and bounded machine output.
- REQ-024: When native-development commands or state contracts change, the repository shall update capability routing, operator documentation, and representative output together.
- REQ-025: Repeated `msvc-activate` invocation shall be idempotent within one shell without duplicating inherited path entries.
- REQ-026: When a toolchain installer requires elevation or reports restart state, the workstation DSL shall make that boundary explicit without restarting Windows automatically.
- REQ-027: When Java state is explicitly ensured, the workstation DSL shall install the official x64 Microsoft OpenJDK 21 LTS package independently of the optional malware-analysis bundle.
- REQ-028: The managed Java state shall resolve the installed JDK root dynamically, persist `JAVA_HOME` at user scope, and keep exactly one normalized `%JAVA_HOME%\bin` entry on the user path.
- REQ-029: When either supported PowerShell runtime loads the managed profile, `java`, `javac`, `jar`, and `jshell` shall resolve from the declared JDK with the runtime and compiler reporting the same major release.
- REQ-030: When Ghidra is selected, its Java prerequisite shall reuse the independently declared OpenJDK package without introducing a second Java distribution or private runtime.
- REQ-031: When Java smoke validation runs, it shall compile and execute a minimal source file in a temporary directory.

### Key Entities

- **Native compiler state**: Registered build-tools instance, selected components, host/target architecture, SDK, build engine, excluded workloads, privilege, and restart state.
- **Shell build environment**: Dynamically resolved command path plus include, library, SDK, toolset, installation, and stable compiler-selection variables.
- **CMake state**: Package, command-line backend, default generator, and explicit project override behavior.
- **Rust state**: Toolchain manager, stable native host, profile, user directories, command path, and permitted project overrides.
- **Java state**: JDK package and major release, dynamically resolved installation root, user environment, command path, and Ghidra reuse relationship.
- **Smoke result**: Language, runtime, commands, temporary workspace, process result, and cleanup outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: One hundred percent of new managed PowerShell 5.1 and PowerShell Core sessions expose `msvc-activate`, remain MSVC-inactive at startup, and resolve all thirteen declared development commands after activation without a separate developer prompt.
- **SC-002**: Minimal C, C++, CMake, direct build-engine, Rust, package-test, and Java fixtures each complete successfully from a fresh shell using explicit MSVC activation where required.
- **SC-003**: One hundred percent of declared compiler components belong to the compact x64/x86 compiler, SDK, or build-engine set, with zero declared IDE or Unix-emulation workloads.
- **SC-004**: Inspection changes zero packages, files, persistent variables, or toolchain selections and identifies every missing required component.
- **SC-005**: Both supported PowerShell runtimes report identical process-only compiler selection after activation and identical generator, Rust-directory, native-host, and Java-home values.
- **SC-006**: A second compliant repair changes zero managed toolchain resources, and repeated `msvc-activate` invocation produces no duplicate managed path entry.

## Assumptions

- The workstation is an x64 Windows 11 Pro system and x64 is the default host and target architecture.
- The standalone Build Tools license is acceptable to the operator; installation remains explicit and may require elevation.
- The current released Windows 11 SDK supported by the selected Build Tools release is appropriate for new projects.
- The compact CMake backend is installed as a separate native Windows executable.
- Rust uses its default development profile so formatting and lint components remain available.
- Microsoft OpenJDK 21 remains the supported LTS line for both general Java development and the managed Ghidra release.
- Project-specific CMake generators, Rust toolchain files, and target selections remain authoritative.
- Linux race-detector and CGo workflows continue to run inside the managed Linux container environment.
