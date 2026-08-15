# Quickstart: Native Windows Development Toolchain

Run from the repository root.

## 1. Validate specification and plan

```powershell
.\ears-sdd.ps1 validate --project . --phase spec
.\ears-sdd.ps1 validate --project . --phase plan
.\ears-sdd.ps1 validate --project . --phase tasks
```

Expected: one feature, 31 requirements, and zero findings.

## 2. Inspect plans without changing state

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module MsvcBuildTools -Plan
.\Apply-Workstation.ps1 -Mode Test -Module CMake -Plan
.\Apply-Workstation.ps1 -Mode Test -Module RustToolchain -Plan
.\Apply-Workstation.ps1 -Mode Test -Module JavaToolchain -Plan
.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan
```

Expected: Extended-stage focused modules, the PowerShell 7 gate, and Sudo only where the compiler
installer requires it.

## 3. Test before repair

```powershell
pwsh -NoProfile -File .\scripts\Set-MsvcBuildToolsState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-CMakeState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-RustState.ps1 -Mode Test
pwsh -NoProfile -File .\scripts\Set-JavaState.ps1 -Mode Test
```

Expected on a fresh host: actionable drift without package or environment changes.

## 4. Apply the explicit toolchain

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeDevelopment
```

This explicitly authorizes the potentially multi-gigabyte privileged Build Tools download, plus
the non-IDE CMake/Ninja, Rust, and Microsoft OpenJDK 21 dependencies. It does not restart Windows.

## 5. Open a new shell and verify commands

```powershell
Get-Command cl.exe,link.exe,lib.exe,nmake.exe,msbuild.exe,cmake.exe,ninja.exe,rustc.exe,cargo.exe,java.exe,javac.exe,jar.exe,jshell.exe
Get-ChildItem Env:CC,Env:CXX,Env:CMAKE_GENERATOR,Env:CARGO_HOME,Env:RUSTUP_HOME,Env:JAVA_HOME
rustup show active-toolchain
java -version
javac -version
```

Expected: native x64 Microsoft commands, `CC=CXX=cl.exe`, `CMAKE_GENERATOR=Ninja`, user Rust
directories, stable x64 MSVC Rust, and matching OpenJDK 21 runtime/compiler commands.

## 6. Run explicit benign smoke fixtures

```powershell
pwsh -NoProfile -File .\scripts\Set-NativeDevelopmentState.ps1 -Mode Smoke
```

Expected: C, C++, CMake/Ninja, MSBuild, rustc, Cargo, and Java fixtures all pass. The command uses a
temporary directory and does not build repository code.
