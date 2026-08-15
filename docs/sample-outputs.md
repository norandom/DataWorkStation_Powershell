# Sample outputs

## Workstation update plan

The short command is observational until `-Run` is explicit:

```text
PS> update
Workstation update plan (release 2.0.0)

Order Name                  Privilege            Status  DependsOn
----- ----                  ---------            ------  ---------
   10 Windows               WindowsAdministrator planned
   20 WinGet                CurrentUser          planned
   30 Scoop                 CurrentUser          planned WinGet
   40 Wsl                   CurrentUser          planned WinGet
   50 Linux                 WslRoot              planned Wsl
   60 Homebrew              CurrentUser          planned Linux
   70 Containers            WslRoot              planned Linux
   80 PowerShellEnvironment Mixed                planned WinGet,Scoop,Wsl,Linux,Homebrew,Containers

No updates were installed. Run update -Run to execute this plan.
```

A focused selection includes hard prerequisites but no unrelated roots:

```text
PS> update -Target Homebrew,Containers
Order Name       Privilege   Status  DependsOn
----- ----       ---------   ------  ---------
   20 WinGet     CurrentUser planned
   40 Wsl        CurrentUser planned WinGet
   50 Linux      WslRoot     planned Wsl
   60 Homebrew   CurrentUser planned Linux
   70 Containers WslRoot     planned Linux
```

Execution reports one terminal status per stage. `restart-required` is successful but remains an
operator action; a failed prerequisite gives dependants `skipped` with `BlockedBy` in JSON.

## Native development plan and Java state

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module JavaToolchain -Plan
Stage     Order Module         Runtime     Privileged Dependencies
Extended  176   JavaToolchain PowerShell7 False      PowerShell7
```

```text
PS> pwsh -NoProfile -File .\scripts\Set-JavaState.ps1 -Mode Test
Java toolchain: compliant
  package: Microsoft.OpenJDK.21
  JAVA_HOME: C:\Program Files\Microsoft\jdk-21.x.x-hotspot
  runtime/compiler major: 21/21
```

The aggregate `NativeDevelopment` smoke output reports separate C/C++, CMake, MSBuild, Rust, Cargo,
and Java fixtures so a compiler failure is not hidden behind package presence.

## PowerShell test framework

Framework inspection is observational and reports the exact repair impact:

```text
PS> .\scripts\Set-PesterState.ps1 -Mode Test
PowerShellTesting: compliant
  Declared Pester: 6.1.0
  PowerShell 7: 6.1.0
  Windows PowerShell: 6.1.0
  Shared module base: C:\Users\user\Documents\WindowsPowerShell\Modules
```

The ordinary suite uses bounded file-level parallelism on a supported PowerShell 7 runtime:

```text
PS> test-powershell
PowerShell tests: passed; 27 passed, 0 failed, 0 skipped in 8120 ms
  Runtime: Core 7.6.4; Pester 6.1.0; parallel=True; throttle=4

PS> test-powershell -Compatibility
PowerShell tests: passed; 27 passed, 0 failed, 0 skipped in 24110 ms
  Runtime: Desktop 5.1.26100.4652; Pester 6.1.0; parallel=False; throttle=1
  Sequential reason: Windows PowerShell compatibility lane is sequential.
```

Exact counts and timings vary with the selected files. A failure is named in the aggregate result
and returns a nonzero process exit code.

These sanitized transcripts show the shape of successful human-facing and machine-facing commands. Versions, timings, paths, and the set of installed skills can change.

## Dependency plan

Planning is read-only. Selecting `DeveloperTools` includes its package-manager prerequisites automatically:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module DeveloperTools -Plan
Workstation module plan for mode 'Test':

Stage    Order Name             Runtime     DependsOn
-----    ----- ----             -------     ---------
Inbox       18 PowerShell7      Native
Core        19 Go               PowerShell7
Core        20 Packages         Native      PowerShell7
Extended    45 LinuxHomebrew    PowerShell7 Packages
Extended    47 LinuxAutomation  PowerShell7 LinuxHomebrew
Extended    49 DeveloperDocker  PowerShell7 LinuxAutomation
Extended    50 DeveloperTools   PowerShell7 DeveloperDocker, Go
```

Go and the released hash command are independently selectable Windows resources:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module Go -Plan

Stage Order Name        Runtime     DependsOn
----- ----- ----        -------     ---------
Inbox    18 PowerShell7 Native
Core     19 Go          PowerShell7

PS> pwsh -NoProfile -File .\scripts\Set-GoState.ps1 -Mode Test
Go: compliant (1.26.5, auto)
  Package: compliant
  GoPath: compliant
  GoBinOnUserPath: compliant
  ToolchainManager: compliant
  GoRootUnmanaged: compliant

PS> pwsh -NoProfile -File .\scripts\Set-MalwareHashesState.ps1 -Mode Test
malware_hashes: compliant (v2.5.0)
  ReleaseAsset: compliant
  ReleaseHash: compliant
  CommandHash: compliant
  ReleaseVersion: compliant
  StaticHashSmoke: compliant
```

The Spec Kit policy tool is independently selectable and does not pull in WSL or Dagger:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module SpecDrivenDevelopment -Plan
Workstation module plan for mode 'Test':

Stage    Order Name                   Runtime     DependsOn
-----    ----- ----                   -------     ---------
Inbox       18 PowerShell7            Native
Core        20 Packages               Native      PowerShell7
Extended    55 SpecDrivenDevelopment  PowerShell7 Packages
```

After `Ensure`, its narrow test reports the release and command independently:

```text
PS> pwsh -NoProfile -File .\scripts\Set-SpecDrivenDevelopmentState.ps1 -Mode Test

Resource                    State       Detail
--------                    -----       ------
SpecKitEarsTddPackage       compliant   release v0.1.0; specify-cli==0.16.3
EarsSddCommand              compliant   ...\uv\tools\spec-kit-ears-tdd\Scripts\ears-sdd.exe
```

The same resource test returns the same state under inbox Windows PowerShell 5.1.

## Staged PowerShell and Windows Terminal

The bootstrap plan works from the inbox shell before `pwsh.exe` exists:

```text
PS> powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-Workstation.ps1 -Mode Test -Module PowerShell7 -Plan
Workstation module plan for mode 'Test':

Stage Order Name        Runtime DependsOn
----- ----- ----        ------- ---------
Inbox    18 PowerShell7 Native
```

The profile smoke test launches both runtimes, while the focused Terminal test is observational:

```text
PS> powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-WorkstationBaseline.ps1 -Section PowerShellRuntimes
PASS PowerShellRuntimes
Workstation baseline tests passed (14 assertions).

PS> pwsh -NoProfile -File .\scripts\Set-WindowsTerminalState.ps1 -Mode Test
Windows Terminal settings: compliant (...\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json).
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

## Suspicious-file triage

Static inspection does not execute or upload the file and does not claim a verdict:

```text
PS> is-this-malware C:\Samples\synthetic.exe

SchemaVersion : 1
Status        : complete
Verdict       : undetermined
Sample        : @{Name=synthetic.exe; Size=4096; Sha256=AC96...; Type=PE32+; Entropy=0.3475}
Signature     : @{Status=NotSigned; Signer=}
Pe            : @{EntryPointRva=4660; ImageBase=5368709120; Sections=System.Object[]}
Indicators    : {@{Category=api; Value=VirtualAlloc}, @{Category=direct-syscall; Value=0F 05 at file offset 0x2F0}}
Execution     : not-run
Upload        : not-performed
```

Planning an isolated job makes the consent boundary visible and does not launch it:

```text
PS> malware-sandbox C:\Samples\synthetic.exe -Mode Detonate

Status               : planned
Verdict              : undetermined
Mode                 : Detonate
SandboxConfiguration : ...\analysis.wsb
NetworkEnabled       : False
DurationSeconds      : 30
CloseWhenComplete    : True
Telemetry            : {process, file, file-handles, registry, dns...}
Execution            : not-run
```

Target plans retain the host report and arrange an independent guest report from the same verified release:

```text
MalwareHashes : @{Release=v2.5.0; ToolMappedReadOnly=True; HostState=complete; SandboxState=planned}
```

After an approved Sandbox run, bounded evidence ingestion reports only validated cross-boundary fields:

```text
PS> pwsh -NoProfile -File .\scripts\Read-MalwareEvidence.ps1 -Case <case>
Status        : validated
AnalysisStatus: complete
HashAgreement : matched
```

`matched` means the host source and read-only guest copy produced identical deterministic hashes. It does not mean the target is safe.

Default jobs close Windows Sandbox after `result.json` is finalized. An explicitly reviewed
`-KeepSandboxOpen` plan instead shows `CloseWhenComplete : False` in the manifest and plan output.

A clean-control plan is visibly distinct but retains the same reviewed policies:

```text
PS> malware-control C:\Samples\synthetic.exe -Mode Detonate -DurationSeconds 30

Status                     : planned
Verdict                    : undetermined
Role                       : Control
Mode                       : Detonate
NetworkEnabled             : False
DurationSeconds            : 30
ToolInventoryFingerprint   : 8A...
IsolationPolicyFingerprint : F4...
Execution                  : not-run
```

After separately approved control and target runs, the normal comparison uses a standard unified
diff and retains both input trees:

```text
PS> malware-diff -ControlCase $control -TargetCase $target

Status                    : complete
Verdict                   : undetermined
Compatibility             : compatible
DiffStatus                : differences
ControlCanonicalDirectory : ...\comparison-...\control
TargetCanonicalDirectory  : ...\comparison-...\target
DiffPath                  : ...\comparison-...\evidence.diff
DiffCommand               : git.exe diff --no-index --no-ext-diff --text ...
```

The canonical paths can be passed to another common directory-diff tool. Diff status
`differences` is not a command failure or a malware verdict. Reports cross-link same-hash static,
document, reverse-engineering, and dynamic cases without treating a static indicator as observed
execution. Default output never renders raw evidence. `-ShowDiff` prints the escaped canonical diff;
unknown traces and parser artifacts appear only as path, size, and SHA-256.

The complete rootless static-parser path is also plan-first:

```text
PS> malware-container C:\Samples\invoice.pdf

Status             : planned
Backend            : RootlessContainer
Distribution       : Debian-MW
Role               : Target
Image              : dataworkstation/malware-static:2026.08.15-graph1
Network            : none
ReadOnlyRoot       : True
Execution          : not-run
Verdict            : undetermined
ContainerPlan      : ...\container-plan.json
```

A two-binary plan makes the structural primary result and two read-only inputs visible:

```text
PS> binary-diff C:\Samples\product-1.exe C:\Samples\product-2.exe

Status              : planned
AnalysisKind        : BinaryDiff
Backend             : RootlessContainer
Distribution        : Debian-MW
BaselineSha256      : 4A7E...
CandidateSha256     : 991C...
PrimaryComparison   : structural-graph
Network             : none
Inputs              : read-only
Execution           : not-run
Verdict             : undetermined
ContainerPlan       : ...\container-plan.json
```

After a separately confirmed parser run, the bounded report summarizes graph relationships. It
does not render hostile disassembly or decompiler output:

```text
PS> binary-diff-report .\evidence\malware\binary-diff-...

Status             : complete
AnalysisKind       : BinaryDiff
PrimaryComparison  : structural-graph
OverallSimilarity  : 0.9184
OverallConfidence  : 0.9631
MatchedFunctions   : 214
ChangedFunctions   : 17
AddedFunctions     : 6
RemovedFunctions   : 3
AmbiguousFunctions : 2
Execution          : not-run
Verdict            : undetermined
```

The retained `baseline.BinExport` and `candidate.BinExport` graphs feed the immutable
`baseline_vs_candidate.BinDiff` SQLite result. `binary-analysis.sqlite` is a separate query
sidecar; file versions, byte changes, assembly text, and decompiled text are never used as a
fallback primary comparison. Missing or timed-out graph tooling changes `Status` to `partial` and
appears in `ToolStatus` and `Failures`.

The local image is a separate opt-in state resource:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module MalwareContainerImage -Plan

Order Name                  DependsOn       Privileged Destructive
----- ----                  ---------       ---------- -----------
   49 RootlessPodman                         True       False
   66 MalwareContainerImage RootlessPodman   False      False

PS> lint-python
All checks passed!
```

A compliant image state reports matching reviewed identities:

```text
Status                           : compliant
Image                            : dataworkstation/malware-static:2026.08.15-graph1
ExpectedToolInventoryFingerprint : 10EDCAD1...
ActualToolInventoryFingerprint   : 10EDCAD1...
ExpectedBuildContextFingerprint  : 2917BC1C...
ActualBuildContextFingerprint    : 2917BC1C...
```

Only `malware-container ... -Run -ConfirmContainer` starts the static parser. It cannot enable
networking and never executes the sample or extracted content.

The four boundary names are intentionally visible:

```text
PS> workstation-help -Type Commands -Name '*static'

Kind    Name           Source
----    ----           ------
Command host-static    profile/Aliases.ps1
Command sandbox-static profile/Aliases.ps1

PS> wsl-dev uname -a
PS> wsl-mw podman info --format json
```

The explicitly approved benign integration check produces local, ignored evidence and requires an
actual guest handle observation:

```text
PS> pwsh -NoProfile -File .\scripts\Test-MalwareSandboxIntegration.ps1 -ConfirmSandbox -ConfirmExecution

SchemaVersion          : 1
Status                 : passed
Verdict                : undetermined
FileHandleEvidence     : ...\output\file-handles.jsonl
FileHandleObservations : 12
NetworkEnabled         : False
Note                   : This validates the benign evidence path only; it is not a malware verdict.
```

The observation count varies by timing. A missing Handle tool, collection failure, or process that
exits before a snapshot is reported explicitly and does not pass this end-to-end check.

The optional tool plan puts both dependency chains before the non-default module:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module MalwareAnalysisTools -Plan

Order Name                   DependsOn                 Privileged Destructive
----- ----                   ---------                 ---------- -----------
   10 Sudo                                              False      False
   18 PowerShell7                                       False      False
   20 Packages               PowerShell7                False      False
   30 WindowsFeatures        Sudo                        True       False
   56 MalwareHashes                                                     False  False
   65 MalwareAnalysisTools   Packages, WindowsFeatures, ProfilingTools, MalwareHashes  False  False
```

The Handle prerequisite can be checked without testing or installing the large analyzer bundle:

```text
PS> pwsh -NoProfile -File .\scripts\Set-MalwareAnalysisToolsState.ps1 -Mode Test -Tool Handle

Name   Source State          Path
----   ------ -----          ----
Handle WinGet drift detected
Malware analysis tool state: drift detected.
```

`-Mode Ensure -Tool Handle` is the corresponding explicit, focused state change.
