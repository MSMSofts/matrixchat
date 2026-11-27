<!--
SPDX-FileCopyrightText: 2026 MatrixChat contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixChat multi-platform test candidates

The MatrixChat Platform Candidates workflow is triggered by changes to its
workflow or this document on security-hardening. It first runs focused
security tests and static analysis on that exact commit, then builds all
platforms independently. No production credentials, automatic releases,
store publishing or deployment are used.

| Target | Artifact |
| --- | --- |
| Android ARMv7, ARM64, x64 | Universal release-mode APK, debug signed with an ephemeral runner key, separate com.msmsofts.matrixchat.candidate package |
| Windows x64 | Portable ZIP of release executable and supporting files |
| Linux x64 / ARM64 | Separate release bundle tarballs |
| Web | Release tarball with hardened Nginx configuration |
| macOS | Ad-hoc-signed release app ZIP, not notarized |
| iOS | Unsigned device app ZIP; not an installable IPA |

Artifacts include the source commit, license and SHA-256 checksums. Download
from the Actions run, not the upstream release page. Retention is 14 days.

These are non-production candidates. Use disposable accounts and isolated
test devices or profiles. Android's runner-local debug signing key changes
between builds; uninstalling a test app may erase its local data. Windows
portable packaging does not isolate application data. Inherited package IDs,
deep-link schemes, service URLs, icons and desktop binary names have not all
been migrated. Do not install over an existing FluffyChat or use production
credentials. The iOS and macOS builds require publisher signing and actual
device testing before distribution. The iOS transport policy now rejects
arbitrary cleartext loads; login and media interoperability must be tested.

No candidate is approved until platform build results, installation, login,
encrypted messaging, attachments, migration/recovery and RTC tests are
reviewed. Production signing, a complete brand/identifier migration and
independent security review are separate release gates.
