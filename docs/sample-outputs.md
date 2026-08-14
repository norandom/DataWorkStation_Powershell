# Sample outputs

These sanitized transcripts show the shape of successful human-facing and machine-facing commands. Versions, timings, paths, and the set of installed skills can change.

## Dependency plan

Planning is read-only. Selecting `DeveloperTools` includes its package-manager prerequisites automatically:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan
Workstation module plan for mode 'Test':

Order Name             DependsOn       Privileged Destructive
----- ----             ---------       ---------- -----------
   18 PowerShell7                       False      False
   20 Packages         PowerShell7      False      False
   45 LinuxHomebrew    Packages         False      False
   47 LinuxAutomation  LinuxHomebrew    False      False
   50 DeveloperTools   LinuxAutomation  False      False
```

## Focused desired-state test

Tests report each independently verifiable component and return a non-zero exit code if any item has drifted:

```text
PS> pwsh -NoProfile -File .\scripts\Set-TerminalFontState.ps1 -Mode Test
FiraCode-Bold.ttf: compliant
FiraCode-Light.ttf: compliant
FiraCode-Medium.ttf: compliant
FiraCode-Regular.ttf: compliant
FiraCode-Retina.ttf: compliant
FiraCode-SemiBold.ttf: compliant
```

## Contour deployment and graphics gate

The Contour resource reports package provenance and migration state before accepting the renderer:

```text
PS> pwsh -NoProfile -File .\scripts\Set-ContourTerminalState.ps1 -Mode Test

Resource               State       Detail
--------               -----       ------
ContourMsi             compliant   0.6.3.8249 installed; 0.6.3.8249 required
ContourScoopPackage    removed     ...\scoop\apps\contour
ContourConfig          compliant   ...\contour\contour.yml; font=Berkeley Mono; starts=~
ContourDesktopShortcut compliant   ...\Desktop\Contour Terminal Emulator.lnk
LegacyContourShortcut  removed     ...\Desktop\Contour.lnk
ContourGraphicsGate    compatible  exit=0; runtime=4.72 s
```

The exact timing varies. If the graphics gate fails with OpenGL or GLSL errors, verify the active display driver and its installed INF before reporting an application crash.

## Command and skill discovery

The default helper combines managed commands, loaded aliases, and repository skills. Filters are useful at the prompt:

```text
PS> workstation-help -Type Skills -Name '*crash*'

Kind  Name               Target Description
----  ----               ------ -----------
Skill investigate-crash        Investigate Windows process crashes, silent exits, and hangs.
```

Use JSON when another command will consume the result:

```powershell
$skills = workstation-help -Type Skills -Json | ConvertFrom-Json
$skills | Select-Object Kind, Name
```

## Capability routing JSON

`tricky ... -Json` is the stable machine-facing form; the default remains optimized for people:

```powershell
$catalog = tricky capabilities -Json | ConvertFrom-Json
$catalog.Capabilities | Where-Object Id -eq 'crash-analysis' | Select-Object Id, Title
```

```text
Id             Title
--             -----
crash-analysis Crash, hang, and silent process exit
```
