# Research: AI Tools and WSL Isolation

## Brownfield and red-test record

The repository initially had no OpenCode, Claude Code, Antigravity, Cline, Copilot CLI, VS Code,
Berg, AI-specific NixOS, WSL trust-matrix, or private Debian-MW case-transfer declarations. The
existing DevOps NixOS enabled interop and deployed from `/mnt/<drive>`. Debian-MW likewise invoked
its pyinfra source through a Windows mount. The initial focused contract run fails before any live
installer, guest mutation, termination, or evidence transfer.

## Selected delivery channels

- OpenCode documents WSL as its recommended Windows CLI environment and publishes official Windows
  desktop assets. Planning observed release `v1.18.18`; the declaration pins the selected asset and
  digest. Sources: <https://opencode.ai/docs/windows-wsl/>,
  <https://github.com/anomalyco/opencode/releases>.
- Claude Code uses the user-selected `irm https://claude.ai/install.ps1 | iex`. Read-only inspection
  on 2026-08-17 showed that the script retrieves a versioned manifest, verifies SHA-256, and runs
  the downloaded native installer. Observed latest: `2.1.233`.
- Antigravity CLI uses the user-selected
  `irm https://antigravity.google/cli/install.ps1 | iex`. Read-only inspection showed a Windows
  CLI-only `agy.exe`, versioned manifest, and SHA-512 verification. Observed latest: `1.1.13`.
- Cline documents `npm install -g cline`; observed package version `3.0.55`.
  Source: <https://docs.cline.bot/getting-started/installing-cline>.
- GitHub documents npm package `@github/copilot` for Copilot CLI on Windows; observed package
  version `1.0.80`. Source:
  <https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli>.
- VS Code stable is `Microsoft.VisualStudioCode`; the declared extensions are
  `saoudrizwan.claude-dev`, `ms-toolsai.jupyter`, `ms-python.python`, and the current stable
  VS Code bundled `GitHub.copilot-chat` identity.

Versions above are research observations, not an instruction to auto-adopt new upstream versions.
Updates must revise reviewed identities and re-run the feature gates.

## Decision: package Berg from pinned source

`jx22/berg` contains the theme JSON and MIT license but no VS Code `package.json` or release asset.
Its README says a Marketplace package existed in 2020, but that channel could not be established as
a reliable current identity. Pin commit `32e03bf59ae9408edc2d0c382a7003a57f1d2bc0` and the raw theme
SHA-256 `290433bf27cd893a3f13bd3c5e01238f0885d1dbbad7934bfc20f9f63b3873e1`, then generate a minimal
local theme extension owned by the desired-state resource. Source: <https://github.com/jx22/berg>.

## Decision: separate mutable package ownership from the AI user

The user requires `brew install nono`. Homebrew installations are mutable and normally owned by
the installing user. Letting the daily AI account own `nono` would allow one compromised agent run
to replace the binary or policy used by the next run. Create a non-login maintenance identity that
owns Homebrew and is invoked explicitly from trusted Windows; keep the daily AI user outside sudo
and unable to modify the prefix, launcher, OpenCode binary, or reviewed policy.

## Decision: use nono only behind a fail-closed capability gate

Official nono documentation supports WSL2 and the `nolabs-ai/opencode` profile, and Homebrew
publishes `brew install nono`. The normal network sandbox is unrestricted. Domain filtering is
disabled by default on WSL2; its documented proxy fallback requires `wsl2_proxy_policy:
"insecure_proxy"`. The design does not enable that fallback. The managed launcher requires
`nono setup --check-only`, a patched version (at least `0.55.0`, because earlier versions had the
documented user-D-Bus escape), the reviewed policy identity, negative path probes, and demonstrably
secure network enforcement. Otherwise it exits before OpenCode.

Sources: <https://github.com/nolabs-ai/nono>, <https://formulae.brew.sh/formula/nono>,
<https://nono.sh/network-filtering>, <https://github.com/advisories/GHSA-27vp-2mmc-vmh3>.

## Decision: disable host integration in every untrusted or secret-bearing distribution

Separate WSL VHDs do not stop a Linux process that can invoke Windows `wsl.exe`, access DrvFS, or
consume a shared agent socket. AI and Debian-MW are untrusted workloads; DevOps NixOS contains key
material. All three therefore disable interop, Windows PATH injection, and automatic Windows-drive
mounting. Ordinary Debian remains explicitly trusted and can perform administration.

The Windows host remains the administrative boundary and can enter any distribution as root. This
feature does not claim protection from that host or its administrator.

## Decision: stream deployment and cases instead of mounting Windows

Existing restricted-distribution deployment paths used `wslpath` over the repository drive. After
automount is disabled, Windows writes reviewed configuration through `wsl.exe` standard input to a
root-owned destination. Debian-MW case data crosses the same host boundary as a bounded tar stream,
never as a guest-visible host directory. Pre-transfer and post-transfer checks reject reparse
points, symlinks, absolute/traversal members, devices, sockets, and paths outside the selected case.

## Alternatives rejected

- A separate Windows account: explicitly rejected by the user.
- Windows ACLs on VHD internals: Windows cannot safely provide per-file Linux guest isolation
  inside a WSL ext4 VHD.
- WSL VHD separation alone: insufficient while interop or shared mounts remain.
- Store DevOps keys on Windows and share them: expands exposure and violates the private-filesystem
  requirement.
- Let the AI user own Homebrew/nono: enables persistent sandbox replacement.
- Enable nono's insecure WSL2 proxy fallback: contradicts the fail-closed network requirement.
- Use ordinary Debian for OpenCode: mixes a trusted administration environment with an untrusted
  autonomous agent.
