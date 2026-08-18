# Contract: Native Development Desired State

## Module planning

```powershell
.\Apply-Workstation.ps1 -Mode Test -Module MsvcBuildTools -Plan [-Json]
.\Apply-Workstation.ps1 -Mode Test -Module CMake -Plan [-Json]
.\Apply-Workstation.ps1 -Mode Test -Module RustToolchain -Plan [-Json]
.\Apply-Workstation.ps1 -Mode Test -Module JavaToolchain -Plan [-Json]
.\Apply-Workstation.ps1 -Mode Test -Module NativeDevelopment -Plan [-Json]
```

The aggregate plan contains the PowerShell 7 stage gate, Sudo, the four focused toolchain modules,
and PowerShellProfile. Planning invokes no resource and resolves no compiler command.

## Focused state

```powershell
pwsh -NoProfile -File .\scripts\Set-MsvcBuildToolsState.ps1 -Mode Test [-Json]
pwsh -NoProfile -File .\scripts\Set-CMakeState.ps1 -Mode Test [-Json]
pwsh -NoProfile -File .\scripts\Set-RustState.ps1 -Mode Test [-Json]
pwsh -NoProfile -File .\scripts\Set-JavaState.ps1 -Mode Test [-Json]
pwsh -NoProfile -File .\scripts\Set-NativeDevelopmentState.ps1 -Mode Test [-Json]
```

- Human-readable state is the default.
- `-Json` returns one bounded object with schema version, status, changed=false in Test, and resource rows.
- Drift returns nonzero.
- Test does not invoke WinGet installation, rustup mutation, compiler execution, or persistent environment writes.

## Explicit repair

```powershell
.\Apply-Workstation.ps1 -Mode Ensure -Module MsvcBuildTools
.\Apply-Workstation.ps1 -Mode Ensure -Module CMake
.\Apply-Workstation.ps1 -Mode Ensure -Module RustToolchain
.\Apply-Workstation.ps1 -Mode Ensure -Module JavaToolchain
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeDevelopment
```

Build Tools repair is visibly privileged and can download several gigabytes. It selects only the
declared compiler and SDK components and uses no-restart installer behavior. CMake/Ninja, rustup,
and OpenJDK 21 are separate focused dependencies. Aggregate Ensure never interprets package success as smoke-test
success.

## Explicit smoke validation

```powershell
pwsh -NoProfile -File .\scripts\Set-NativeDevelopmentState.ps1 -Mode Smoke [-Json]
```

Smoke mode generates only known benign fixtures in a unique temporary directory, imports the same
x64 build environment as the profile, runs all seven compile/build/test scenarios, reports bounded
results, and removes the directory. It never scans or builds repository source.

## Shell contract

After either managed profile loads:

```powershell
Get-Command msvc-activate
msvc-activate
Get-Command cl.exe,link.exe,lib.exe,nmake.exe,msbuild.exe,cmake.exe,ninja.exe,rustc.exe,cargo.exe,java.exe,javac.exe,jar.exe,jshell.exe
Get-ChildItem Env:CC,Env:CXX,Env:CMAKE_GENERATOR,Env:CARGO_HOME,Env:RUSTUP_HOME,Env:JAVA_HOME
```

Profile loading alone does not import MSVC or persist `CC`/`CXX`. Explicit activation imports the
x64 environment into the current process, places Microsoft tools ahead of inherited conflicting
commands, and sets process-only `CC=CXX=cl.exe`. Re-import is idempotent. Projects may still select
another CMake generator or Rust toolchain/target explicitly.
Ghidra resolves the same OpenJDK 21 package and does not require a second Java distribution.
