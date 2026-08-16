# Research: Native Forensic EWF Verification

## Decision 1: Use upstream `ewfverify` as the native verification engine

Use `ewfverify` from libyal's `libewf` project. It is purpose-built for Expert Witness Compression Format verification and supports native Microsoft Visual C++ builds. The wrapper will preserve the upstream result and evidence instead of reimplementing EWF parsing.

Alternatives rejected:

- A new PowerShell EWF parser would enlarge the trusted code base and be difficult to certify.
- WSL or a Linux container violates the native-Windows forensic boundary and complicates evidence-path and filesystem semantics.
- Mounting or exporting the image changes the scope from verification to evidence access and is intentionally excluded.

References: [libewf repository](https://github.com/libyal/libewf), [ewfverify manual](https://github.com/libyal/libewf/blob/main/documentation/ewfverify.1)

## Decision 2: Start with libewf 20231119 and pin all build inputs

The initial build uses libewf 20231119 because its official source release includes a detached signature. The newer 20240506 experimental release has no detached signature and can only enter the catalog as a separately reviewed build revision.

| Input | Identity | SHA-256 or authenticity |
|---|---|---|
| libewf source | `libewf-experimental-20231119.tar.gz` | `EC08D411A5DAB0ECC957D12B64AD9AE073136AA85C05B2CA77C33E03949B2AB7` |
| libewf detached signature | `.asc` asset | `E38080BBDD22E4652E03F02635F2BC10C94CB46A51EF784AB8C8E93CE3A72EF7` |
| libyal signing key | upstream documented key | `0ED9 020D A90D 3F6E 70BD 3945 D962 5E5D 7AD0 177E` |
| zlib | 1.3.2 source ZIP | `E8BF55F3017AA181690990CB58A994E77885DA140609FC8F94ABE9B65D2CAE28` |
| bzip2 | 1.0.8 source archive | `AB5A03176EE106D3F0FA90E381DA478DDAE405918153CCA248E682CD0C4A2269` |
| libyal `vstools` | commit | `ce1bd73b3e23b34e98c206b26df4c2d663500554`; GitHub reports a valid PGP signature |

The build record must also capture resolved URLs, byte sizes, compiler/linker/MSBuild/Windows SDK identities, runner image, arguments, and resulting file digests. A checksum file adjacent to a release asset is evidence, not the trust anchor; the Git-tracked approved catalog independently pins the expected package digest.

Detached-signature verification uses the official standalone GnuPG 2.5.21 Windows installer
`gnupg-w32-2.5.21_20260702.exe` as a build-only dependency. Its size is 5,772,160 bytes and its
SHA-256 is `6246C925A73167253444AFC24A0DEB83A3F43B7D636AF84D6AAF48A98A62F024`.
Windows reports a valid Authenticode signature from `g10 Code GmbH`, certificate thumbprint
`83CC4E382E5E4AF554C66E429E8F66FFE499910D`. The build imports the reviewed libyal public key from
the repository into an isolated temporary keyring, checks its full fingerprint
`0ED9020DA90D3F6E70BD3945D9625E5D7AD0177E`, and calls `gpgv.exe --keyring <isolated-keyring>` on
the detached signature and source archive. A mismatched installer identity, public-key fingerprint,
signature, signer, or unexpected Unix-compatibility runtime import fails the build. GnuPG and its
keyring are not shipped in the verifier package and do not participate in evidence verification.

References: [libewf releases](https://github.com/libyal/libewf/releases), [zlib](https://zlib.net/), [bzip2](https://sourceware.org/bzip2/), [vstools](https://github.com/libyal/vstools), [official GnuPG Windows binaries](https://gnupg.org/ftp/gcrypt/binary/), [gpgv manual](https://www.gnupg.org/documentation/manuals/gnupg26/gpgv.1.html)

## Decision 3: Build a minimal x64 package with native MSVC

Arrange the pinned `libewf`, `zlib`, and `bzip2` sources as sibling trees, use the pinned `vstools` revision to generate Visual Studio 2022 projects, and build the x64 Release `ewfverify` target and its dependencies with MSVC v143. Package only:

- `ewfverify.exe`
- `libewf.dll`, `zlib.dll`, and `bzip2.dll` when dynamically linked
- applicable licenses
- a package manifest, SBOM, and build provenance

Reject the candidate if PE inspection finds a non-AMD64 image, an unexpected file, networking library import, or a Cygwin/MSYS/MinGW runtime import. Do not include acquisition, mount, export, recovery, or interactive tools.

The compiler, converter, and source trees are build-time inputs only. Workstation installation downloads the approved release ZIP and never invokes a compiler.

## Decision 4: Separate candidate build, approval, and immutable publication

The lifecycle is deliberately two-phase because a catalog cannot pin an asset digest until the asset exists:

1. A reviewed candidate record fixes inputs and a proposed `forensic-ewfverify-20231119-b1` identity.
2. A manual Windows workflow builds, tests, attests, and uploads the asset to a draft release.
3. A maintainer records its final package/internal hashes and certification result in an `Approved` catalog commit. The record contains the reviewed candidate/build digest and approval decision, but never attempts to contain the hash of its own Git commit.
4. A separate confirmed publish command requires a clean checkout, resolves the commit that contains the exact catalog bytes, writes that commit and the catalog-file SHA-256 into release provenance, validates the draft against it, and publishes an immutable release.

Reruns may verify an existing asset but may not replace it. A source, dependency, toolchain, converter, recipe, option, or security change creates `b2` or later. Historical approved records remain available for report attribution; a withdrawn record remains descriptive but is not installable.

The existing documentation release workflow uses `gh release upload --clobber`; it must be converted to draft-upload-publish behavior before repository-wide release immutability is enabled. Enabling the GitHub setting is an explicit maintainer action, not part of planning.

Ordinary update discovers forensic candidates only from explicit `Candidate` records in the checked-out reviewed catalog. It performs no upstream or GitHub release discovery. A separate maintainer review may propose such a record.

References: [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases), [prevent release changes](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes), [artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)

## Decision 5: Treat verification as a held-handle evidence transaction

Open every segment using `FileAccess.Read` and sharing that permits other readers while denying write, delete, and rename. Keep the handles open while streaming each pre-verification SHA-256, running `ewfverify`, and streaming each post-verification SHA-256. This gives the wrapper a stable Windows object relationship and detects any mutation that still becomes observable.

The extension ordering mirrors the certified libewf sequence: numeric segment extensions through 99 and the documented alphabetic continuation thereafter. Gaps, duplicates, ambiguity, and unsupported naming fail before tool invocation.

Invoke the absolute path resolved from the approved catalog and pass the complete ordered set. Capture stdout and stderr as raw byte streams with fixed bounds, retain the upstream log, and parse only a sanitized decoded view. A tool `SUCCESS` cannot override changed segment bytes, failed package integrity, an unsupported image, or an unrecognized parser result.

## Decision 6: Use explicit non-verdict statuses

The report status is one of:

- `verified`: supported image, stored digest matches, tool/package verified, and evidence unchanged
- `readable-no-stored-hash`: readable, but the image lacks a stored digest to verify
- `integrity-failed`: the stored integrity value does not match
- `evidence-changed`: a segment length or hash changed during the transaction
- `unsupported`: format, version, segment set, or layout is not certified
- `tool-integrity-failed`: catalog, package, executable, or dependency identity failed
- `parser-output-unrecognized`: upstream output cannot be safely mapped
- `report-failed`: the durable report transaction could not complete

Only `verified` is success. This avoids presenting readability, parser heuristics, or absence of a stored hash as forensic verification.

## Decision 7: Certify with small, benign, reproducible fixtures

Commit a small segmented EWF corpus made from a documented non-case byte pattern, along with generation provenance, physical segment hashes, media hash, stored digest expectation, and expected status. Tests derive corrupt, missing-segment, hostile-output, and persistence-failure cases in temporary directories. They never download fixtures and never use case evidence.

The pinned `ewfacquirestream` utility can create the ordinary segmented fixture from standard input,
but it always calculates MD5 and therefore cannot establish the hashless case by itself. A small
test-only native fixture writer under `tests/fixtures/ewf/generator/` will link against the same
pinned libewf source and write the documented byte pattern without calling the MD5/SHA1 setter APIs.
The generated image must remain readable by the candidate `ewfverify` while reporting no stored
comparison digest. The generator source, compiler identity, arguments, and output hashes are
recorded; its executable is deleted after generation and is never committed or shipped. If the
library automatically inserts a stored digest or the resulting image is not independently readable,
the fixture-generation gate fails rather than relabeling a corrupt image as hashless.

Certification covers both Windows PowerShell 5.1 and PowerShell 7.x, the package manifest and imports, status mapping, raw-output preservation, JSON schema, report atomicity, offline behavior, and mutation detection. An upgrade cannot become `Approved` until this corpus passes.
