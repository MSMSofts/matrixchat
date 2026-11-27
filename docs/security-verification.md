<!--
SPDX-FileCopyrightText: 2026 MatrixChat contributors
SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixChat security verification and release gates

Status: required verification plan; not an audit report. Do not mark a gate passed without evidence for the exact release commit. Test only authorized infrastructure, synthetic identities and non-production credentials.

## Threat model

Protect message/file content, device identity, session tokens, recovery material, drafts, notification privacy, and integrity of release builds. Assume untrusted network, malformed events, untrusted room participants, potentially compromised homeserver, and opportunistic local access. A fully compromised device/browser, traffic analysis by the homeserver, denial of service and already disclosed historical keys cannot be eliminated by client code.

## Required evidence

| Area | Test cases | Evidence required |
| --- | --- | --- |
| Native data | Missing/wrong key, plugin read/write errors, old database and sidecars, plaintext legacy DB, rollback and abrupt shutdown | Original data preserved; correct key opens; inspect raw DB/WAL; no plaintext fallback |
| Hardware | Real Android StrongBox/TEE and software fallback, locked device, background push, reboot; iOS Keychain and recovery; Windows/macOS/Linux secure stores | Probe reports capability only; independently verify actual key protection and migration before claiming hardware-backed vault |
| Messages | Direct/group, unverified device, key reset, membership change, old queued events, reactions, attachments, edits, threads and custom events | Cross-client delivery and fail-closed policy with controlled servers |
| Identity | Own and peer device addition/revocation, master-key replacement, failed and canceled re-verification, multi-account changes | No unintended send/key sharing; independent identity confirmation |
| Network | Delegated homeservers, SSO/OIDC, HTTPS redirects, signed CDN URL, credential stripping, malformed URLs, proxy prefixes, TLS failure | Instrumented test server records no unintended token forwarding |
| RTC | MatrixChat and independent clients, keys before membership sync, participant leave/rejoin, device revocation, key rotation, SFU failure | Confirm actual frame E2EE; no silent downgrade; recovery and interoperability |
| Device privacy | PIN retries across reboot, biometric failure, notifications/lockscreen, app switcher, screenshots, temp audio/video/cache/export | Platform-specific screenshots/logs and sanitized file inspection |
| Web | HTTPS deployment, CSP diagnostics, SSO popup/fallback, WebAssembly, media and calls, IndexedDB/session restoration, browser update | Browser matrix with no secrets exposed; enforce restrictive CSP only after tests pass |
| Build chain | Secret scan, CVEs and dependency inventory, pinned assets, normalized build, signed provenance | Review findings; verify exact artifact hash and attestation |
| Independent review | Threat model, cryptographic trust paths, platform boundaries, dependency and code review | Independent report, tracked fixes and retest |

For every gate record commit SHA, platform/OS, client version, test data, expected and actual outcomes, date, and a redacted evidence reference. Do not use production chats, real recovery keys, or live user data. All unmet gates block a production security claim.

## Automation

Run the repository's dedicated security workflow and the full pull request workflow. Verify the results refer to the current head, not a canceled or previous commit. Before a production release review the final diff, require protected-branch review and successful CI, validate the manually built candidate and its provenance, and conduct device tests and independent review. Actual GitHub branch protection and private reporting settings are maintainer actions, not inferred from source files.

## Crypto agility: future adoption gate

The current client uses the locked Matrix SDK and Vodozemac with standard Olm/Megolm. Presence of an encryption state event is not proof of algorithm support. Never silently accept unknown algorithms or send plaintext as a fallback.

For MLS, key transparency or post-quantum key exchange/signatures, require an interoperable Matrix specification/MSC and audited SDK support, a threat model and migration plan, capability negotiation and downgrade tests, device/backup/recovery compatibility, test vectors and cross-client testing. Do not invent a private Matrix wire protocol or label a client post-quantum secure merely because a library is present. Preserve existing users' keys through reviewed, reversible migration.

References for reviewers: [Matrix specification](https://spec.matrix.org/), [OWASP MASVS](https://mas.owasp.org/), [IETF MLS RFC 9420](https://www.rfc-editor.org/rfc/rfc9420), [NIST post-quantum cryptography](https://csrc.nist.gov/projects/post-quantum-cryptography).

## Status

CI results must be reviewed on the current commit. Hardware-backed wrapping of existing keys, browser at-rest data protection, native code signing, independent cross-machine reproducibility, full SDK/native transport coverage and independent penetration testing remain open unless separately evidenced.
