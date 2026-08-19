# Windows hardening profile and attack surface

Process and memory mitigations such as DEP, ASLR, CFG, SEHOP, and hardware shadow stacks are kept in
the separate [Windows Exploit Protection profiles](exploit-protection.md) DSL and module.

The `DeveloperBaseline` profile carries the applicable controls from the retired
`WindowsHardeningScript\Harden_PS.ps1` into narrow, testable desired state. It targets a Windows 11
Pro developer workstation. It is not a generic CIS or Microsoft Security Baseline implementation.

## Human-readable commands

Inspect the declaration without elevation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Plan
```

Compare it with the machine, then explicitly repair drift:

```powershell
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Test
sudo powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-HardeningState.ps1 -Mode Ensure
```

Add `-Json` for machine-readable Plan, Test, Ensure, or Reinitialize output. The full workstation orchestrator runs `DeveloperBaseline` automatically after Windows sudo and optional features; use `-SkipHardening` to omit it. `Reinitialize` saves the complete observed pre-change state under `state/hardening-snapshots/` before writing. The resource never restarts Windows.

For a narrow orchestrated run, use `.\Apply-Workstation.ps1 -Mode Test -Module Hardening`. Its module plan automatically places `Sudo` first.

## What the profile enforces

| Area | Desired state | Security effect | Compatibility cost |
|---|---|---|---|
| Name resolution | LLMNR and smart multi-homed fallback disabled; NetBIOS disabled on every IP-enabled adapter | reduces Responder-style local name-poisoning and credential-relay opportunities | legacy short-name discovery must use DNS or an explicit address |
| TCP/IP | IPv4/IPv6 source routing and ICMP redirects disabled | rejects attacker-controlled routing shortcuts | unusual routed lab networks might require exceptions |
| SMB | SMB1 disabled, signing required on client and server, insecure guest and plaintext-password fallback disabled | blocks SMB1 exploitation and impairs SMB relay/on-path tampering | old NAS devices and guest-only shares may stop working; signing adds some CPU cost |
| Credentials | anonymous SAM/session access restricted, remote SAM limited to administrators, NTLMv2-only, WDigest caching disabled | reduces anonymous enumeration, downgrade paths, and recoverable plaintext credentials | obsolete SMB/NTLM clients and some remote inventory tools can fail |
| Remote access | Remote Assistance off, RDP NLA/encrypted RPC required, RDP drive redirection off, WinRM digest and unencrypted transport off, unauthenticated RPC restricted | reduces credential exposure and remote data transfer | RDP cannot redirect local drives; old WinRM/DCOM clients can fail |
| Execution and media | safe DLL search, Explorer DEP/heap termination retained, autorun/autoplay disabled | removes common removable-media and DLL-search execution paths | legacy shell extensions or media workflows may need manual launch |
| Printing and wireless | web printer discovery/HTTP printing disabled; OEM Wi-Fi autoconnect off; simultaneous connections minimized | reduces printer-driver discovery and unintended network attachment | web-discovered printers and some multi-network workflows require manual configuration |
| Lock screen | lock-screen camera and voice activation disabled | removes unauthenticated sensor entry points | those convenience features are unavailable while locked |
| Optional features | SMB1 and Windows PowerShell 2 disabled or absent | removes obsolete protocol and engine surfaces | scripts that require the PowerShell 2 engine cannot run |

The declaration is `config/hardening-profiles.psd1`. Registry values remain data; SMB runtime settings use the supported `Get/Set-SmbClientConfiguration` and `Get/Set-SmbServerConfiguration` interfaces because Windows 11 24H2 and later can own signing defaults without retaining the older registry values.

Microsoft documents SMB signing as required by default on current Windows 11 Pro releases, with the expected compatibility failure for unsigned or guest-only third-party servers. See [Control SMB signing behavior](https://learn.microsoft.com/windows-server/storage/file-server/smb-signing) and the [Windows 11 security baseline reference](https://learn.microsoft.com/intune/device-security/security-baselines/ref-windows-mdm-settings).

## Legacy-script review

The old script was not rerun. Each class of mutation was reviewed against the current machine and modern Windows behavior.

| Disposition | Legacy controls |
|---|---|
| Managed here | LLMNR/NetBIOS, source routing, SMB1/signing/guest fallback, anonymous and legacy authentication, WDigest, Remote Assistance/RDP/WinRM transport, autorun, web printing, Wi-Fi connection policy, and lock-screen sensors |
| Managed elsewhere | firewall rules, event/audit logging, Defender runtime/exclusions, SmartScreen, download zone marking, Windows features, packages, and profiling tools |
| Observed only | `RunAsPPL` and LSASS audit level; the current values are reported but not written |
| Outside this profile | UAC policy, including `EnableLUA`, consent prompts, secure-desktop prompts, and remote local-admin token filtering |
| Moved to a separate opt-in profile | reviewed AppX, capability, and optional-feature removals; see [Opt-in Windows debloat profile](debloat.md) |
| Excluded | file-association hijacks, old Chrome/Edge/Office policy trees, telemetry/privacy preferences, broad service/task disabling, remote SCM/task-scheduler endpoint removal, and optional smart-card/domain-only policy |
| Rejected as harmful or obsolete | Chrome minimum TLS 1.0, `DisableParallelAandAAAA`, multicast suppression, destructive removal of Desktop App Installer/OpenSSH/codecs, and blanket removal of Windows capabilities |

LSA protection is observation-only because the legacy value `RunAsPPL=1` can create firmware-backed
UEFI state that needs a special removal procedure. This workstation already reports value 1, and
the profile does not make it more persistent. Microsoft distinguishes UEFI-locked value 1 from
reversible value 2 in [Configure added LSA protection](https://learn.microsoft.com/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection).
Credential Guard and VBS remain under Windows platform policy and are reported separately during a
security review.

Defender MAPS/sample submission and the legacy ASR rule are not silently adopted. Cloud submission changes privacy boundaries, and aggressive ASR blocking can interfere with newly built or low-prevalence developer binaries. Stage those settings in audit mode and review evidence before making them a separate Defender profile.

## Migration evidence on this workstation

The 2026-08-14 review ran on Windows 11 Pro 25H2, build 26200.9168. Most defensible legacy settings were still present. The initial profile test found the physical Wi-Fi adapter inheriting NetBIOS behavior and SMB signing being supplied by the Windows runtime rather than a durable legacy client registry value.

`Ensure` disabled NetBIOS on the Wi-Fi adapter and converged the registry/runtime controls. The corrected post-change `Test` is compliant. SMB1 is disabled, both PowerShell 2 feature names are absent from the image, SMB client and server signing are required, insecure guest logons are disabled, and both IP-enabled adapters reported NetBIOS option 2. LSASS protected-process value 1 and audit value 8 were observed but not modified.

## Residual attack surface

Hardening reduces attack paths; it does not make the host closed.

| Surface | Current boundary |
|---|---|
| Physical Ethernet/Wi-Fi inbound | default inbound is Block; the managed firewall allows TCP 22, 3389, 8080, and 8081 plus Tailscale UDP 41641, and honors expert-approved local application rules on every profile |
| Tailscale inbound | the Tailscale interface is unrestricted, so authenticated tailnet peers can reach any service bound to that interface unless the service has its own access control |
| Listening Windows services | after convergence, RPC 135, SMB 445, and Hyper-V 2179 were bound on wildcard addresses; NetBIOS 139 remained on Hyper-V virtual-switch addresses, not the physical Wi-Fi address |
| RDP and WinRM | both services were stopped and RDP connections were disabled at review time, but this hardening profile does not disable the services; if enabled later, the firewall already permits physical TCP 3389 |
| SMB | SMB remains available to allowed networks. Signing and authentication protect integrity and identity but do not replace share permissions or least privilege |
| Hyper-V and Sandbox | the hypervisor, VM management service, virtual switches, and Windows Sandbox component increase privileged virtualization code and host/guest integration surface |
| Outbound traffic | outbound firewall policy is Allow. Malicious code that executes can contact external services unless Defender, DNS/network controls, or an application policy blocks it |
| Application execution | no WDAC/AppLocker allowlist is imposed. SmartScreen warning mode permits user override, and the legacy script-file association tricks were rejected |
| Defender exclusions | paths declared under `defender.exclusions` in ignored `config.json` are scanning blind spots. Keep them narrow and treat code arriving there as trusted-input risk |
| Print spooler | web discovery and HTTP printing are disabled, but the spooler remains enabled for local printing and retains its service/driver surface |

No process was started to test reachability. Listener and firewall inspection is a point-in-time snapshot; use `ports`, `connections`, `firewall-status`, and the hardening `Test` command before drawing incident conclusions.

## Rollback and exceptions

The resource converges only to the declared profile; it does not provide a bulk "undo legacy
hardening" mode. To make an exception, change one DSL value, document its compatibility rationale,
and run Test before Ensure. For temporary diagnosis, use a scoped service, firewall, or protocol
exception instead of disabling the complete profile.
