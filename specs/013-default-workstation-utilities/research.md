# Research: Default Workstation Utilities

## mpv package and renderer

- **Decision**: Use the official Windows CI/MSVC package with `gpu-next` on D3D11.
- **Rationale**: The package fits normal WinGet lifecycle management and the Windows graphics path
  matches the declared Radeon workstation without introducing another renderer stack.
- **Alternatives considered**: Legacy mpv builds, OpenGL-only rendering, and unmanaged archives.

## Decoder safety

- **Decision**: Use safe automatic hardware decoding with software fallback.
- **Rationale**: Playback remains available when a codec, driver, or file cannot use D3D11VA.
- **Alternatives considered**: Forced hardware decoding, which can turn an optimization failure into
  a playback failure, and software-only decoding, which leaves the available GPU unused.

## Configuration ownership

- **Decision**: Own one marker-bounded block in the user mpv configuration.
- **Rationale**: Desired state stays deterministic without taking ownership of personal settings.
- **Alternatives considered**: Replacing the complete file or maintaining an unbounded set of keys.

## Safe-Chain trust boundary

- **Decision**: Install only for the current Windows user and trusted developer Debian.
- **Rationale**: Those are package-development environments; restricted AI, DevOps NixOS, and
  malware-analysis environments have distinct trust and reproducibility boundaries.
- **Alternatives considered**: Installation in every WSL distribution or only on Windows.

## Safe-Chain integrity

- **Decision**: Pin and verify both installer and resulting binary digests per platform.
- **Rationale**: Installer authenticity alone does not prove the executable retained after setup.
- **Alternatives considered**: Mutable latest downloads or version-only checks.

## Safe-Chain command-wrapper coverage

- **Decision**: Treat every command in `SupportedCommands`, including pnpm and pnpx, as required
  initialization content on Windows and trusted Debian.
- **Rationale**: The initialization file can exist while a compatible package manager silently
  bypasses Safe-Chain; wrapper-level readback closes that gap.
- **Alternatives considered**: Testing only file presence or special-casing pnpm outside the shared
  protected-command inventory.
