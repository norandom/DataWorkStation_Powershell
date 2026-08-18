# Sample outputs

## Local workstation snapshot

These versions were reported by this workstation on 2026-08-16. They show the output shape; managed
versions will change as package declarations are updated.

```text
PS> go version
go version go1.26.5 windows/amd64

PS> rustc --version
rustc 1.97.1 (8bab26f4f 2026-07-14)

PS> cargo --version
cargo 1.97.1 (c980f4866 2026-06-30)

PS> cmake --version | Select-Object -First 1
cmake version 4.4.2

PS> javac -version
javac 21.0.12

PS> msvc-activate
PS> cl
Microsoft (R) C/C++ Optimizing Compiler Version 19.44.35228 for x64
usage: cl [ option... ] filename... [ /link linkoption... ]
```

The MSVC usage message confirms that explicit activation imported the compiler environment. It is
expected when `cl` is called without a source file. A new shell leaves MSVC inactive until
`msvc-activate` is run.

## Managed aliases

`workstation-help -Type Aliases` reported these six aliases on the same workstation:

```text
Kind  Name             Description                  Source
----  ----             -----------                  ------
Alias host-static      Alias for is-this-malware     loaded profile
Alias sandbox-static   Alias for malware-sandbox     loaded profile
Alias terminal-link    Alias for Show-TerminalLink   loaded profile
Alias wget             Alias for aria2c               loaded profile
Alias workstation-help Alias for Get-WorkstationHelp loaded profile
Alias wshelp           Alias for Get-WorkstationHelp loaded profile
```

Each alias is a short name for an existing human-readable command:

| Alias | Use case | Example |
|---|---|---|
| `host-static` | Inspect bounded bytes, hashes, entropy, PE metadata, and strings without executing or uploading a suspicious file. | `host-static C:\Samples\unknown.exe` |
| `sandbox-static` | Plan static inspection or document dissection in Windows Sandbox. The example plans only; add the displayed confirmation switches after reviewing the generated `.wsb`. | `sandbox-static C:\Samples\invoice.pdf -Mode Dissect` |
| `terminal-link` | Print a clickable OSC 8 link in Contour while retaining readable text in other terminals or redirected output. | `terminal-link 'https://learn.microsoft.com/sysinternals/' 'Sysinternals documentation'` |
| `wget` | Download through the managed `aria2c` wrapper with resume and segmented-transfer defaults. | `wget https://example.invalid/archive.zip -d $HOME\Downloads` |
| `workstation-help` | List managed commands, aliases, and repository skills, or filter them by name and type. | `workstation-help -Type Commands -Name '*memory*'` |
| `wshelp` | Use the short interactive name for `workstation-help`. | `wshelp -Type Skills -Name '*crash*'` |

Use `workstation-help -Type Aliases -Json` when another command needs the same inventory. Alias
discovery is read-only. The static-analysis aliases remain plan-first or non-executing unless their
documented confirmation switches are supplied.

## Workstation update plan

The short command is observational until `-Run` is explicit:

```text
PS> update
Workstation update plan (release 2.2.0)

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

## Windows Exploit Protection plan

Plan is non-elevated and does not read or modify the live mitigation policy:

```text
PS> powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-ExploitProtectionState.ps1 -Mode Plan
Exploit Protection Plan: Recommended workstation system mitigations
Profile: Recommended
Outcome: planned
Administrator required for live Test or mutation: True
Affected applications require restart after change: False
Enable: DEP, EmulateAtlThunks, BottomUp, HighEntropy, SEHOP, TerminateOnError
Disable: SEHOPTelemetry
```

The command then lists all seven managed controls and nine observation-only controls. Its JSON form
is the same canonical result rather than a second evaluation path:

```json
{
  "SchemaVersion": 1,
  "Mode": "Plan",
  "Profile": "Recommended",
  "Compliant": null,
  "DriftCount": 0,
  "Outcome": "planned",
  "Enable": ["DEP", "EmulateAtlThunks", "BottomUp", "HighEntropy", "SEHOP", "TerminateOnError"],
  "Disable": ["SEHOPTelemetry"],
  "Changes": [],
  "SnapshotPath": null,
  "ProcessRestartRequired": false
}
```

The complete object also contains `DisplayName`, `Description`, `BasedOn`,
`RequiresAdministrator`, captured-artifact provenance, and the `Controls` collection. Test returns
exit code 1 for drift; successful Ensure or Reinitialize reports whether applications must be
restarted, but never restarts them.

## Spec feature governance

The publication guard is observational and validates only features referenced by non-grandfathered
state declarations:

```text
PS> pwsh -NoProfile -File .\scripts\Test-SpecFeatureGovernance.ps1
Spec feature governance: compliant
Checked modules/state routes: 47/30
Governed modules: ExploitProtection
Governed state routes: windows-exploit-protection
Legacy fingerprint: ffa053bc99617bcf72f825ac6ce6a972dc18f09b750bb668c567f85bc9b45fb3 (expected ffa053bc99617bcf72f825ac6ce6a972dc18f09b750bb668c567f85bc9b45fb3)
Feature specs/011-exploit-protection: artifacts=True; final=True; errors=0; warnings=0; requirements=23
```

The `-Json` form reports schema version 1, the same counts, governed identities, referenced feature
gate, legacy fingerprint, failures, and outcome. A missing feature reference, artifact, or failed
EARS gate produces an attributed failure and nonzero exit.

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

The four boundary names identify where each command runs:

```text
PS> workstation-help -Type Commands -Name '*static'

Kind    Name           Source
----    ----           ------
Command host-static    profile/Aliases.ps1
Command sandbox-static profile/Aliases.ps1

PS> wsl-dev uname -a
PS> wsl-mw podman info --format json
```

The reproducible Kubernetes/IaC boundary reports both declared-state drift and content integrity:

```text
PS> nixos-check
NixOS WSL: compliant
  Distribution: NixOS
  User: mc
  Repository sources: matched
  Store integrity: verified
  Source integrity: matched
  Command integrity: verified
  Detail: Active generation matches the deployed flake and its Nix store closure is intact.

PS> wsl-nix helm version --short
v3.20.2+gv3.20.2

PS> wsl-nix kubectl version --client
Client Version: v1.36.3

PS> wsl-nix pulumi version
v3.255.0
```

Versions are examples from the locked input and change only when the reviewed flake lock changes. `nixos-check -Json` returns the same state for automation. A store content mismatch reports `altered`; a source or generation mismatch reports `drifted`.

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

## Autopsy and Sleuth Kit

The complete optional setup reports the GUI, private helpers, case root, and Defender boundary
separately:

```text
PS> .\Apply-Workstation.ps1 -Mode Test -Module Autopsy

Resource                 State      Detail
--------                 -----      ------
AutopsyMsi               compliant  4.23.1 installed; 4.23.1 required
AutopsyPrivateTools      complete   9 reviewed bindings
AutopsyManagedFiles      verified   11 exact size/SHA-256 records
AutopsyCaseRoot          present    C:\Users\operator\Documents\Autopsy Cases
DefenderCaseExclusion    active     C:\Users\operator\Documents\Autopsy Cases
DefenderProcessExclusion active     C:\Program Files\Autopsy-4.23.1\bin\autopsy64.exe
DefenderService          retained   Running
```

The matching native TSK tools resolve directly from `PATH`:

```text
PS> mmls -V
The Sleuth Kit ver 4.15.0

PS> ./scripts/Set-SleuthKitState.ps1 -Mode Test
SleuthKitTree verified 92 files; SHA-256 C8E39797BAC346638A6DBE78D21BAB6F9AD9A23A2DE06B334A4C9DD772B6B878

PS> autopsy-regripper -h
Rip v.4.0 - CLI RegRipper tool
Rip [-r Reg hive file] [-f profile] [-p plugin] [options]
```

Protection status distinguishes disabled scanning from the retained engine process:

```text
PS> autopsy-defender-status

DefenderServiceInstalled  : True
DefenderServiceStatus     : Running
DefenderProcessRunning    : True
RealTimeProtectionEnabled : False
BehaviorMonitorEnabled    : False
IoavProtectionEnabled     : False
```

See [Autopsy Windows forensic workstation](autopsy.md) before changing protection or using private
write-capable tools.

## EWF verification

Start with the non-mutating plan:

```text
PS> ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports -Plan
Plan: 3 EWF segment(s), tool ewfverify 20231119-b1.
Report destination: C:\EvidenceReports
```

After review, a successful run returns a short operator result and retains the
details in a new report directory:

```text
PS> ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports
EWF verification: verified
Evidence: C:\Evidence\disk.E01
Tool: ewfverify 20231119-b1
Report: C:\EvidenceReports\ewf-20260816T184200Z-7ad9...
```

The JSON form exposes the same stable facts without printing raw native output:

```text
PS> ewf-verify C:\Evidence\disk.E01 -ReportDirectory C:\EvidenceReports -Json | ConvertFrom-Json | Select-Object status,verified,reportDirectory

status   verified reportDirectory
------   -------- ---------------
verified     True C:\EvidenceReports\ewf-20260816T184200Z-7ad9...
```

Images without a stored digest are not reported as verified:

```text
PS> ewf-verify C:\Evidence\hashless.E01 -ReportDirectory C:\EvidenceReports
EWF verification: readable-no-stored-hash
Evidence: C:\Evidence\hashless.E01
Tool: ewfverify 20231119-b1
Report: C:\EvidenceReports\ewf-20260816T184500Z-1f82...
Detail: Verification completed with status: readable-no-stored-hash
```

Paths and run IDs are illustrative. Inspect `report.txt` first, then
`report.json` and `artifacts.json`. Treat `stdout.bin`, `stderr.bin`, and the
upstream log as hostile bytes; the human report contains bounded sanitized
previews.

## Quantitative research environment

```text
PS> quant-status -Project thesis
Quantitative research environment: compliant
Root: C:\Users\mariu\Source\quant-research
- base quant-base: compliant
- overlay thesis: compliant
```

Drift remains observational:

```text
PS> quant-status -Project Base
Quantitative research environment: drift detected
- base quant-base: drift detected
  openbb-extensions: Generated OpenBB reference omits installed extensions.
```

The base status also reports licensed Excel integration without exposing the key:

```text
PS> quant-status -Project Base
Quantitative research environment: compliant
Root: C:\Users\mariu\Source\quant-research
- base quant-base: compliant
  PyXLL: package, x64 add-in, OpenBB pythonw.exe, WebView2, and interactive plots compliant
  License: present (value redacted)
```

The relocation report never executes its preview:

```text
PS> source-relocation-plan -Target D:\Source
Source relocation plan (observational only)
Source: C:\Users\mariu\Source
Target: D:\Source
Execution available: False
Future dry-run copy preview: robocopy "C:\Users\mariu\Source" "D:\Source" ... /L
```

Paths, capacity, warnings, and fingerprints are workstation-specific. Use `-Json` for the same
checks as one structured object; a blocker returns nonzero.

## AI tools and WSL trust boundary

The native AI category is opt-in. Its default human report names each reviewed delivery channel
without installing anything:

```text
PS> pwsh -NoProfile -File .\scripts\Set-AiToolsState.ps1 -Mode Test
AI tools: drifted (opt-in)
  OpenCode Desktop: absent; target=Windows; channel=GitHubRelease
  Claude Code: wrong-channel; target=Windows; channel=OfficialPowerShell
  Antigravity CLI: absent; target=Windows; channel=OfficialPowerShell
  Cline CLI: absent; target=Windows; channel=NpmGlobal
  GitHub Copilot CLI: absent; target=Windows; channel=NpmGlobal
```

The trust report is observational and leaves stopped distributions stopped:

```text
PS> pwsh -NoProfile -File .\scripts\Test-WslTrustBoundary.ps1
WSL trust boundary: drifted
  TrustedUtility: mariu@Debian; trust=trusted-integrated; status=compliant
  DevOps: mariu@NixOS; trust=restricted; status=drifted
    failure: StoppedNotInspected
```

Use the corresponding `-Json` switch for the same fields as structured data. Distribution names,
users, installed products, and drift are host-specific.
