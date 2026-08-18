# Research: Native Windows Development Toolchain

## Decision 1: Use standalone Build Tools with individual components

**Decision**: Install `Microsoft.VisualStudio.2022.BuildTools` and request only
`Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and
`Microsoft.VisualStudio.Component.Windows11SDK.26100`, without workload expansion.

**Rationale**: Microsoft documents that individual component selection installs required
dependencies without recommended or optional workload components. The selected compiler component
provides the current v143 x64/x86 tools, while SDK 26100 provides the Windows headers, libraries,
and resource compiler. The Build Tools product supplies MSBuild without the IDE.

**Alternatives considered**: The Desktop C++ workload pulls substantially more recommended tools;
Visual Studio Community adds the IDE and license considerations; LLVM alone does not satisfy the
explicit MSBuild/MSVC requirement; MinGW/MSYS violates the platform constraint.

Sources: [MSVC Build Tools installation](https://learn.microsoft.com/en-us/cpp/overview/acquire-msvc),
[Build Tools component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=visualstudio),
[installer component semantics](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2022).

## Decision 2: Import the developer environment on explicit activation

**Decision**: Resolve the latest compatible Build Tools instance with the bundled instance locator,
then import the output of its developer-command initialization for `amd64` host and target once per
activated shell through the human `msvc-activate` command.

**Rationale**: MSVC depends on `PATH`, `INCLUDE`, `LIB`, `LIBPATH`, SDK, and toolset variables. The
versioned values must track side-by-side instance and SDK updates. Explicit per-process import keeps
ordinary shells neutral, preserves user state, and lets child build processes inherit a complete
environment. It also prepends Microsoft's `link.exe` ahead of the existing Coreutils command only
when native compilation is requested.

**Alternatives considered**: Persisting the full developer environment would overwrite unrelated
user PATH state and become stale after updates; hard-coded installation paths break side-by-side
instances; wrapper scripts impose overhead and do not make the environment available to arbitrary
child build tools.

Sources: [MSVC command-line environment](https://learn.microsoft.com/en-nz/cpp/build/building-on-the-command-line?view=msvc-170),
[developer shell architecture arguments](https://learn.microsoft.com/en-us/visualstudio/ide/reference/command-prompt-powershell?view=visualstudio).

## Decision 3: Use Ninja as CMake's default without removing MSBuild

**Decision**: Install official CMake and Ninja packages and set user
`CMAKE_GENERATOR=Ninja`. Keep `msbuild.exe` directly available, and do not set generator platform,
toolset, or instance variables.

**Rationale**: Ninja provides the compact command-line behavior requested. CMake explicitly
supports `CMAKE_GENERATOR` as the default only when `-G` is absent, so project or command-line
choices remain authoritative.

**Alternatives considered**: A Visual Studio generator is less Linux-like and creates solution
metadata; NMake is slower and less portable; the Visual Studio CMake component adds unwanted
workload content.

Source: [CMake generator environment variable](https://cmake.org/cmake/help/latest/envvar/CMAKE_GENERATOR.html).

## Decision 4: Use rustup stable MSVC and preserve project overrides

**Decision**: Install `Rustlang.Rustup`, use the default Rust profile, and select
`stable-x86_64-pc-windows-msvc`. Declare user `CARGO_HOME` and `RUSTUP_HOME`, add Cargo's bin
directory to user PATH, and omit `RUSTUP_TOOLCHAIN` and `CARGO_BUILD_TARGET`.

**Rationale**: Rust recommends the MSVC ABI for Windows interoperability and requires the MSVC
linker/libraries. A rustup default remains below project directory overrides and
`rust-toolchain.toml` in selection precedence. The default profile includes rustfmt and clippy for
development.

**Alternatives considered**: A GNU host introduces MinGW/MSYS expectations; a global target or
toolchain environment variable would override project intent; the minimal profile omits ordinary
developer formatting and lint tools.

Sources: [rustup on Windows](https://rust-lang.github.io/rustup/installation/windows.html),
[toolchain selection](https://rust-lang.github.io/rustup/concepts/toolchains.html),
[override precedence](https://rust-lang.github.io/rustup/overrides.html),
[profiles](https://rust-lang.github.io/rustup/concepts/profiles.html).

## Decision 5: Keep installation and smoke testing separate

**Decision**: Focused Ensure resources install or configure state; the aggregate resource performs
integration inspection and explicit temporary smoke validation. Ordinary Test never downloads,
installs, compiles, or changes persistent environment.

**Rationale**: This preserves observational desired-state semantics and makes compile execution a
visible operator action. Synthetic contract tests validate commands without invoking installers.

**Alternatives considered**: Compiling during every Test would execute tools and create files despite
the observational contract; package self-repair inside profile startup would hide mutation.

## Decision 6: Promote the Ghidra JDK to an independent Java toolchain

**Decision**: Install `Microsoft.OpenJDK.21` as a focused `JavaToolchain` dependency, dynamically
resolve its installed root, persist user `JAVA_HOME`, and normalize `%JAVA_HOME%\bin` on user PATH.
The Ghidra tool declaration continues to reference the same package identifier.

**Rationale**: The package is the complete Microsoft JDK 21 LTS and contains `java`, `javac`, `jar`,
and `jshell`. Managing it independently keeps ordinary Java development available when the optional
malware-analysis bundle is absent and avoids two Java distributions. Microsoft documents both the
WinGet identifier and `JAVA_HOME`/PATH setup for Windows.

**Alternatives considered**: A Ghidra-private copy couples the shell to optional malware tooling;
a JRE omits `javac`; installing the latest non-LTS Java line could move independently of the managed
Ghidra compatibility baseline; hard-coding a versioned directory breaks package upgrades.

Sources: [Microsoft OpenJDK installation](https://learn.microsoft.com/en-us/java/openjdk/install),
[Java on Windows](https://learn.microsoft.com/en-us/windows/dev-environment/java).
