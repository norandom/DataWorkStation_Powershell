# Contract: Native Forensic Tool Catalog

## Files and authority

- `config/forensic-tools.psd1` is the Git-tracked runtime trust anchor. It contains reviewed release records and the independently expected package/file hashes.
- `config/forensic-builds/<tool>-<version>-<revision>.psd1` contains candidate build inputs and recipe identity.
- GitHub Releases stores immutable binary packages and attestations. A release-provided checksum is corroborating evidence, not a substitute for the Git catalog digest.

## Required approved record

An `Approved` record must contain:

- schema version, tool ID, upstream version, and build revision
- precise certified formats and parser profile
- release repository, immutable tag, exact asset name and byte size
- SHA-256 of the package and every shipped executable/DLL
- source archives, byte sizes, SHA-256 values, signatures/authenticity results, and origin URLs
- build commit/workflow, runner, architecture, compiler, linker, MSBuild, Windows SDK, converter, arguments, and SBOM identity
- certification corpus/version, PowerShell lanes, workflow result, attestation identity, reviewed candidate/build digest, approval decision identity, reviewer, and timestamp
- package license identities and allowlisted internal paths

Records must use literal versions, full commits, and exact asset URLs derived from immutable tags. Floating `latest`, branches, mutable web pages, and unpinned dependencies are invalid.

## Review states

| State | Installation behavior |
|---|---|
| `Candidate` | Build/test only; never installed by normal workstation state. |
| `Approved` | Eligible for explicit installation after all checks pass. |
| `Withdrawn` | Preserved for historical report attribution but blocked from new installation. |
| `Superseded` | Preserved for historical attribution but blocked from new installation. |

## Catalog and approval identity

An approved record must not contain the Git hash of the commit that contains itself. Approval uses
two independently reviewable identities:

1. the record stores the digest of the candidate/build evidence and the approval decision; and
2. the publish command, running from a clean checkout, resolves the commit containing the exact
   catalog bytes and writes that commit plus the catalog-file SHA-256 into release provenance.

Every verification report records the catalog-file SHA-256. It records the Git commit when those
exact bytes resolve to a clean reviewed commit; otherwise it records `null` and a warning. Package,
file, release, and provenance verification remains mandatory even when Git metadata is unavailable.

## Revision rule

A change to any source, dependency, compiler/linker/SDK identity, converter, workflow behavior, recipe, option, packaging layout, parser profile, or security correction requires a new build revision and immutable release. Rebuilding and replacing an existing release asset is forbidden.

## Install validation

Installation must:

1. select the explicit current `Approved` record;
2. download the exact immutable release asset to a staging location;
3. validate byte size, SHA-256, release identity, and available GitHub attestation;
4. validate archive paths before extraction;
5. validate every allowlisted internal file and reject extras;
6. atomically move it to a versioned per-user directory; and
7. leave the prior compliant version recoverable until the new state tests compliant.

Runtime verification repeats installed-file digest checks before execution and invokes the absolute cataloged executable path. The raw verifier is not exposed as an unversioned PATH command.

Ordinary update considers only explicit `Candidate` records in the checked-out catalog. It does not
query upstream projects or GitHub Releases for newer forensic versions.

## Release rules

- Build uploads to a draft release; publish happens only after the catalog record is approved.
- Publication is a confirmed maintainer action and requires GitHub immutable releases.
- Upload and publish operations never use `--clobber`.
- A rerun against an existing identity may verify it but cannot mutate it.
- All third-party workflow actions are pinned to full commit SHAs.
- Authenticode state is recorded truthfully. An unsigned binary relies on the catalog digest, immutable release, attestation, and provenance; it is never described as signed.
