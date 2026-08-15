# Data Model: Native Windows Development Toolchain

## NativeToolModule

| Field | Type | Rules |
|---|---|---|
| `Name` | enum | `MsvcBuildTools`, `CMake`, `RustToolchain`, `JavaToolchain`, or `NativeDevelopment`. |
| `Stage` | enum | `Extended`. |
| `Runtime` | enum | `PowerShell7`; profile behavior is separately dual-shell tested. |
| `DependsOn` | list | Same- or earlier-stage module names only. |
| `Privileged` | boolean | True only for Build Tools and aggregate closure. |
| `Default` | boolean | Aggregate true; focused dependencies false. |

## MsvcInstallation

| Field | Type | Rules |
|---|---|---|
| `InstanceId` | string | Unique registered Build Tools instance. |
| `InstallationPath` | absolute path | Resolved dynamically; never persisted as the desired version. |
| `ProductId` | string | Build Tools product, not an IDE edition. |
| `RequiredComponents` | set | VC x64/x86 tools and Windows 11 SDK 26100. |
| `ExcludedComponents` | set | ARM, ATL/MFC, C++/CLI, UWP, and IDE workload identifiers. |
| `Version` | version | Highest compatible registered instance wins. |
| `RestartRequired` | boolean | Reported, never acted upon automatically. |

State transitions:

```text
absent/partial/obsolete --Ensure (explicit, elevated)--> compliant or restart-pending
compliant              --Ensure-----------------------> compliant without replacement
any                    --Test-------------------------> unchanged observation
```

## NativeShellEnvironment

| Field | Scope | Rules |
|---|---|---|
| `CC`, `CXX` | User + current process | `cl.exe`. |
| `CMAKE_GENERATOR` | User + current process | `Ninja`; explicit project `-G` can override. |
| `CARGO_HOME`, `RUSTUP_HOME` | User + current process | Directories below the user's home. |
| Cargo bin | User PATH + current process | Exactly one normalized entry. |
| `PATH`, `INCLUDE`, `LIB`, `LIBPATH` | Current process only | Imported from the selected developer environment. |
| VS/VC/SDK variables | Current process only | Imported dynamically; version-specific values are not persisted. |
| `RUSTUP_TOOLCHAIN`, `CARGO_BUILD_TARGET` | Unmanaged/absent | Project selection remains effective. |
| `JAVA_HOME` | User + current process | Dynamically resolved Microsoft OpenJDK 21 root. |
| JDK bin | User PATH + current process | Exactly one normalized `%JAVA_HOME%\bin` entry. |

## JavaInstallation

| Field | Type | Rules |
|---|---|---|
| `PackageId` | string | `Microsoft.OpenJDK.21`; shared with the Ghidra prerequisite. |
| `MajorVersion` | integer | `21`. |
| `InstallationPath` | absolute path | Resolved from installed state; versioned path is never hard-coded. |
| `Commands` | set | `java.exe`, `javac.exe`, `jar.exe`, and `jshell.exe`. |

## ToolState

| Field | Type | Rules |
|---|---|---|
| `Name` | string | Stable human resource name. |
| `State` | enum | `compliant`, `drift`, `missing`, `partial`, `obsolete`, `restart-pending`. |
| `Detail` | bounded string | Version/path/component or repair impact. |
| `Changed` | boolean | Always false in Test. |

## SmokeResult

| Field | Type | Rules |
|---|---|---|
| `Fixture` | enum | C, C++, CMake, MSBuild, rustc, Cargo, or Java. |
| `Status` | enum | passed, failed, skipped, timeout. |
| `ExitCode` | integer/null | External process result. |
| `DurationMilliseconds` | integer | Bounded measurement. |
| `TemporaryPath` | path/null | Removed after success and ordinary failure. |

Relationships:

```text
NativeDevelopment -> MsvcBuildTools -> MsvcInstallation
NativeDevelopment -> CMake          -> CMake + Ninja + CMAKE_GENERATOR
NativeDevelopment -> RustToolchain  -> rustup + stable MSVC + Rust directories
NativeDevelopment -> JavaToolchain  -> Microsoft OpenJDK 21 + JAVA_HOME
NativeDevelopment -> PowerShellProfile -> NativeShellEnvironment
NativeShellEnvironment -> SmokeResult
```
