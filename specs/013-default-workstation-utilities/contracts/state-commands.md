# State Command Contracts

## mpv

```powershell
pwsh -NoProfile -File .\scripts\Set-MpvState.ps1 -Mode Test
.\Apply-Workstation.ps1 -Mode Ensure -Module Mpv
```

`Test` compares package, command, managed configuration, and decoder support without mutation.
`Ensure` may install the declared package and merge only the bounded managed block. It requires no
elevation and returns nonzero when post-change state is not compliant.

## Safe-Chain

```powershell
pwsh -NoProfile -File .\scripts\Set-SafeChainState.ps1 -Mode Test
Get-Command pnpm,pnpx -CommandType Function | Format-List Name,Definition
pnpm safe-chain-verify
pnpx safe-chain-verify
pnpm --version
.\Apply-Workstation.ps1 -Mode Ensure -Module SafeChain
```

`Test` reports Windows and trusted Debian binary, registration, and declared command-wrapper state
without network or state changes. The protected inventory includes pnpm/pnpx. `Ensure` may download
verified installers, execute them in the declared user boundaries, and reconcile shell
registrations or missing wrappers. Hash mismatch or incomplete readback returns nonzero.

## Orchestrator

Focused selection automatically includes declared dependencies. Explicit module selection cannot
be combined with legacy skip switches. Neither module is privileged or destructive.
