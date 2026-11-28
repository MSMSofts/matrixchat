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

## Build recovery
The first run produced Windows x64, Linux x64, macOS and web artifacts. Android failed because a release build using --no-pub retained the integration_test plugin in generated Java; the candidate build now regenerates release registration and checks the lockfile. Linux ARM64 uses the exact .fvmrc Flutter tag from Git rather than a missing ARM64 prebuilt SDK archive. iOS retries transient Xcode SwiftPM resolution crashes and separately resolves packages. These are targeted build fixes, not verified successful outputs until the next run finishes.

## Independent Windows installer
The next candidate build adds an unsigned per-user Inno Setup installer alongside the portable ZIP. Its installer identity and fixed install directory are distinct from FluffyChat. It does not erase the existing upstream installation directory. The native executable name and several storage namespaces are preserved pending migration testing, so use a separate Windows user profile and disposable accounts. Set `windows_installer: true` in the next candidate assembly plan only after all seven platform jobs pass. The published RC.1 is not changed.
