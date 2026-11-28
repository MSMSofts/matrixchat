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
