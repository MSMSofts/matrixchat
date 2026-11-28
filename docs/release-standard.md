<!--
SPDX-FileCopyrightText: 2026 MatrixChat contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixChat release standard

Use SemVer for GitHub release labels: vMAJOR.MINOR.PATCH, with
-alpha.N, -beta.N or -rc.N for prereleases. The first independent
candidate preserves the upstream application version 2.11.6+3580 and uses
the release label v2.11.6-rc.1. Do not misrepresent the label as the embedded
app version; increment the mobile build number for a new signed distribution.

## Candidate assembly

The checked-in release/candidate.json names an exact commit and completed
build, security and PR runs. The draft workflow validates the run identities,
all seven platform artifact manifests and SHA-256 files, extracts versioned
packages without modifying their contents, includes the matching Dart
CycloneDX SBOM, source/license references, release manifest and release notes,
and prepares a draft prerelease. It never automatically publishes it or
overwrites an existing release or tag. No publisher keys are used.

For each new candidate, increment the RC number and update the plan to
successful build/security runs from the same commit. The PR workflow must
be completed and its actual outcome disclosed. The draft is a review
container, not permission to publish a failed build or a stable release.
A failed visual regression requires inspection and approved baseline
updates, not a higher tolerance or a skipped test.

## Stable release gate

A stable release requires all CI jobs, including golden and integration
tests, to pass on the exact source commit, reviewed security changes,
protected main/tag policy, isolated platform identifiers, tested migration,
real device and RTC interoperability checks, independent security review,
production code signing and notarization where applicable, and independently
verified build provenance. Never promote the debug-signed APK or unsigned
iOS app to a stable release. A separate main-only web provenance workflow
already exists; this draft assembly does not attest historical build
artifacts or claim reproducibility. A SHA-256 file is not a signature.
Native signing requires securely configured publisher credentials and
protected release environments. These settings are maintainer actions.

Stable versions must be built and verified anew under the production
signing pipeline, rather than relabeling a candidate. Keep assets immutable
after publication; issue a new version for corrections. Verify downloaded
files against SHA256SUMS and review RELEASE.json for exact source and status.
Retain licensing/attribution, link the corresponding source, and include
known limitations and upgrade notes. Never mark a prerelease as latest.

The assembler checks each original artifact's exact SHA-256 before comparing its LICENSE to the exact source commit's license. Only CRLF-to-LF normalization is permitted in license comparison; any other content difference fails. The release includes the canonical source license and hashes the final payload again.

## Registration and authorization
The verified candidate payload for v2.11.6-rc.1 was assembled in run 46092187922, artifact 15241234274. All SHA-256 checks passed; the subsequent GitHub release creation returned HTTP 403. No release was created. Automatic registration is now opt-in via the repository variable `MATRIXCHAT_ENABLE_DRAFT_RELEASE=true`, after a maintainer confirms the Actions identity is actually authorized to create draft releases under repository and organization policies. The variable itself grants no access. Assembly remains read-only and succeeds independently.

An authorized maintainer can register the same validated package from a checkout of this branch using their existing GitHub CLI credentials. Download and extract the verified artifact into `release-dist`, then run:

```sh
python3 scripts/register_release.py release-dist
python3 scripts/register_release.py release-dist --create-draft
```

The script validates every expected file, hash, platform and source commit, checks the remote commit and rejects an existing release or tag. It creates a draft prerelease only. It never changes permissions, accepts credentials in command-line arguments, publishes a stable version, or overwrites release assets. If GitHub denies access, stop and contact the repository administrator. The maintainer may alternatively use the GitHub Releases UI to create the draft and attach the verified payload.

## Candidate installer and update channel
Future candidate plans may explicitly set `windows_installer: true`, adding an eighth binary to the seven-platform payload. Both assembler and registration verifier require its checksum and manifest entry. The RC.1 payload remains supported and unchanged. The application update notifier uses only the MatrixChat repository, rejects prerelease/draft, same, older and non-stable versions, and opens the official release page instead of trusting an arbitrary binary URL. It remains disabled by default; signing and migration are required before production updates.

## Published RC.1 integrity audit
The published prerelease `v2.11.6-rc.1` resolves to `7503752f99131b6eca5f38931674c3cc951eb8c6`. All 12 uploaded assets' SHA-256 digests matched hashes independently calculated from original assembly artifact 15241234274, including the checksum file itself. `release/verified-rc1.json` records that immutable audit baseline. The read-only published verification workflow checks tag, prerelease flag, remote hashes and independently downloads and hashes every published file. This is integrity verification, not publisher signing or device certification.

## Persistent Android preview signing
A separate opt-in workflow builds `com.msmsofts.matrixchat.preview` with a persistent owner-provisioned certificate. It never uses the ephemeral candidate ID or production upstream ID, never creates a key automatically, and never publishes to a store or Releases. The preview signing environment must be created and protected by the repository administrator (reviewer approval and branch restrictions where available); set repository variable `MATRIXCHAT_ENABLE_SIGNED_PREVIEW=true` only after review. In that environment configure secrets `MATRIXCHAT_PREVIEW_KEYSTORE_B64`, `MATRIXCHAT_PREVIEW_STORE_PASSWORD`, `MATRIXCHAT_PREVIEW_KEY_ALIAS`, `MATRIXCHAT_PREVIEW_KEY_PASSWORD`, and variable `MATRIXCHAT_PREVIEW_CERT_SHA256` with the known certificate SHA-256 fingerprint. Keep an offline encrypted backup of the keystore; never paste credentials into chat or commit them. The workflow fails closed on a missing key or certificate mismatch. Increment application build numbers for future signed upgrades. A signed preview remains non-production; Windows Authenticode, Apple signing/notarization and independent platform migration testing are still owner-dependent release gates.

## Owner-authorized automated draft registration
The previous GitHub Actions identity returned HTTP 403 even after 2FA was enabled. The registration job now requires the protected `matrixchat-release-registration` environment and a dedicated `MATRIXCHAT_RELEASE_TOKEN` environment secret explicitly provisioned by the repository owner, plus `MATRIXCHAT_ENABLE_DRAFT_RELEASE=true`. The default workflow token is read-only. Configure the environment with approval and branch protection where available, use an expiring credential restricted to this repository with only the permissions GitHub requires for creating release drafts/tags, and follow repository and organization policies. Do not send the credential in chat or commit it. The job fails if the secret is missing, never falls back to the denied identity, never overwrites an existing tag or release, and checks every uploaded draft asset against the validated payload. The workflow never publishes a draft automatically. Owner authorization and a successful new registration are still required to prove this path works.
