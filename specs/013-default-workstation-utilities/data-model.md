# Data Model: Default Workstation Utilities

## mpv declaration

- Package identity and update policy
- Command path and executable discovery
- Managed block start/end markers and desired lines
- Required renderer, graphics API/context, and decoder capability
- Detected adapter and compliance state

The observed state transitions from absent or drifted to compliant only during explicit Ensure or
Reinitialize. Test reports the transition that would be needed without performing it.

## Safe-Chain platform declaration

- Platform identity: Windows or trusted Debian
- Release version, installer URI, installer digest, binary path, and binary digest
- Shell registration identity, expected initialization content, and declared command wrappers
- Observed presence, integrity, registration, wrapper coverage, and compliance

Each platform is evaluated independently. An unverified installer or binary is a terminal failure,
not a partially compliant state.

## Focused module declaration

- Name, stage, runtime, order, default, dependencies, supported modes
- Privilege and destructive flags
- Feature ownership path

The Safe-Chain capability route additionally links its module ownership and human inspection/state
commands to the same feature.
