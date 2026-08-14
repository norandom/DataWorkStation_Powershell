# Native awk and sed for PowerShell

The workstation provides `awk.exe` and `sed.exe` as native Windows commands for PowerShell pipelines. It does not install or use Git Bash, MinGit, Cygwin, MSYS, or MSYS2.

## Human-readable commands

Inspect the focused state without changing it:

```powershell
pwsh -NoProfile -File .\scripts\Set-NativeTextToolsState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Test -Module NativeTextTools -Plan
```

Install or repair only this capability:

```powershell
pwsh -NoProfile -File .\scripts\Set-NativeTextToolsState.ps1 -Mode Ensure
# Equivalent orchestration:
.\Apply-Workstation.ps1 -Mode Ensure -Module NativeTextTools
```

Verify the commands directly:

```powershell
'alpha beta' | awk '{print $2}'
'abc' | sed 's/b/B/'
```

The expected outputs are `beta` and `aBc`.

## Package and shell boundary

WinGet installs `frippery.busybox-w32`, a native Win32 portable executable. BusyBox is a multicall program, not Bash. Its binary contains many applets, including an `ash`-style `sh` implementation, but this workstation does not add a `sh`, `bash`, or Git Bash command and does not select BusyBox as a shell. Desired state exposes only hash-matched copies named `awk.exe` and `sed.exe` under `%USERPROFILE%\.local\bin`, which is already part of the managed PowerShell `PATH`.

This avoids a POSIX compatibility runtime and avoids adding Git's `usr\bin` directory to the Windows `PATH`. The upstream shell applet remains technically callable through `busybox.exe sh`; it is installed code but not an integrated or managed shell. If eliminating that dormant applet becomes a hard security requirement, the package must be replaced with separately sourced native binaries, because WinGet currently has a native standalone `sed` package but no equivalent standalone `awk` package.

`Test` checks the focused WinGet package state, requires the two exposed executables to match the WinGet-managed binary by SHA-256, and runs functional pipeline smoke tests. `Ensure` refreshes the two copies after a package upgrade. No elevation or restart is required.
