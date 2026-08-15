# Verification log: Native Windows Development Toolchain

**Host**: x64 Windows 11 Pro
**Date**: 2026-08-15

## Applied state

- Standalone Visual Studio Build Tools 2022 `17.14.37` with only
  `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` and
  `Microsoft.VisualStudio.Component.Windows11SDK.26100` explicitly selected.
- CMake `Kitware.CMake` and Ninja `Ninja-build.Ninja` installed through focused WinGet
  Configuration resources; `CMAKE_GENERATOR=Ninja` persisted for the user.
- rustup installed with `stable-x86_64-pc-windows-msvc`; `rustc 1.97.1` observed and user Rust
  directories persisted without project override variables.
- Microsoft OpenJDK `21.0.12.8` installed at
  `C:\Program Files\Microsoft\jdk-21.0.12.8-hotspot`; `JAVA_HOME` and one normalized
  `%JAVA_HOME%\bin` user PATH entry persisted.
- Managed `NativeDevelopment.ps1` deployed to both Windows PowerShell and PowerShell Core profile
  component directories.

## Fresh-shell evidence

Fresh Windows PowerShell 5.1 and PowerShell Core sessions each resolved the same 13 commands:
`cl`, Microsoft `link`, `lib`, `nmake`, `msbuild`, `cmake`, `ninja`, `rustc`, `cargo`, `java`,
`javac`, `jar`, and `jshell`. Both reported `CC=cl.exe`, `CXX=cl.exe`, `CMAKE_GENERATOR=Ninja`,
the same Rust directories, and the same `JAVA_HOME`.

## Smoke evidence

`Set-NativeDevelopmentState.ps1 -Mode Smoke -Json` passed under PowerShell Core and Windows
PowerShell 5.1. The temporary C, C++, CMake/Ninja, direct MSBuild, rustc, Cargo test, and Java
compile/run fixtures all returned exit code zero and their temporary workspaces were removed.

The first Windows PowerShell Java fixture exposed its UTF-8 BOM behavior; the known ASCII fixture
was made explicitly ASCII and the complete compatibility smoke then passed.
