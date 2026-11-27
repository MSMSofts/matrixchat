# MatrixChat security hardening — R1

Status: implementation candidate, not independently audited. Do not ship or merge until tests and migration checks pass.

## Implemented in this change
- Native database startup requires a persisted key and SQLCipher availability; wrong keys, missing keys, and unencrypted legacy databases fail closed. No automatic deletion or plaintext conversion.
- Existing legacy database locations are opened in place; conflicting database copies require operator review.
- Existing permissive or invalid key-sharing settings resolve to verified-only. This is the SDK key-sharing policy, not proof of all outbound session key flows; verify those separately.
- Private message notifications default on; regular message previews can be explicitly re-enabled. Incoming call presentation and other platform notification paths need separate review.
- Reduced Matrix SDK logging, generic startup errors, removal of automatic/raw upstream error-reporting URLs, new-install privacy defaults.
- Unit tests for key resolution and trust policies.

## Compatibility and recovery
Back up encrypted databases and recovery keys before testing. Never clear application data to resolve a secure-startup error. Existing native plaintext databases are deliberately not auto-migrated. Design an authenticated, transactional export/import migration with integrity verification and recovery before upgrading such accounts. Existing explicit privacy preferences other than key sharing may remain. Web storage remains the upstream implementation; it is not covered by the native SQLCipher guarantee. Background isolates and simultaneous processes need concurrency tests, including first-launch key creation and keychain availability. Older notifications may remain visible.

## Release gates
1. Run dart format, flutter analyze, unit tests and the upstream integration tests with the pinned Flutter/Rust toolchain.
2. On each native platform test first launch, multi-account startup, wrong/missing keys, keychain errors, legacy location, SQLCipher absence, crash/restart, and upgrade with a copy of existing encrypted data. Verify the database and key are unchanged on failure.
3. Test verified/unverified devices, cross-signing, key requests, outgoing session-key distribution, membership change, recovery and interoperability with independent Matrix clients.
4. Test notifications, call UI, existing notification history, lock screen and foreground/background transitions on actual devices.
5. Scan dependencies and build artifacts, inspect logs and temporary files for secrets; test signed release packaging. No production security certification is implied.

## Remaining work
- Enforce E2EE send policy across all send paths; explicit trust/identity change handling, rotation policy and recovery testing.
- Secure media cache and hardware-backed wrapping keys, app-lock lifecycle, backup policies and screen protection.
- Network Guard including redirects, delegated homeservers, SSO, WebRTC and native plugins; independently verify RTC media E2EE.
- Web storage threat model, secure hosting, CSP and service worker update policy.
- Signed release process, dependency/secret scanning, SBOM, reproducible builds and independent penetration testing.
- Security Center and privacy controls; MLS, post-quantum and key transparency only when interoperable standards and SDK support are established.

Preserve compatibility with Matrix and upstream license notices. Do not introduce custom cryptographic protocols.
