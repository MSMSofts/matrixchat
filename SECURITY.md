<!--
SPDX-FileCopyrightText: 2019-Present Christian Kußowski
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixChat security policy

MatrixChat is an independent development of a Matrix client derived from FluffyChat. The security-hardening branch is a development candidate, not an independently audited or production-certified release.

## Reporting vulnerabilities

Do not publish exploitable details, access tokens, encryption keys, private messages, or personal data in a public issue.

Use the [MatrixChat Security tab](https://github.com/MSMSofts/matrixchat/security) and its private vulnerability reporting option if enabled. If private reporting is unavailable, contact the maintainer through an established private channel before sharing technical details. No response-time or bounty promise is made.

Provide the affected commit or release, platform, security setting, minimal reproduction using synthetic accounts, impact, and redacted evidence. Only test systems and accounts you are authorized to test.

For vulnerabilities in the inherited upstream project, see [FluffyChat's security policy](https://github.com/krille-chan/fluffychat/security). Protocol or SDK vulnerabilities may also need coordinated disclosure to the appropriate Matrix implementation maintainers.

## Release verification

See [security verification gates](docs/security-verification.md) and [implementation notes](docs/security-hardening.md). Passing CI or the local security status panel does not replace independent security review.
