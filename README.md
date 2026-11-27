<!--
SPDX-FileCopyrightText: 2019-Present Christian Kußowski
SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# MatrixChat

**An independent, open-source Matrix client focused on security, privacy, performance, and advanced cross-platform communication.**

MatrixChat is a Flutter-based messaging client built on the open [Matrix protocol](https://matrix.org/). Its goal is to advance the client experience while maintaining compatibility with the Matrix ecosystem and supporting user choice of homeserver.

MatrixChat is an independent development initiative based on [FluffyChat](https://github.com/krille-chan/fluffychat). It is not a new messaging protocol or a Matrix homeserver.

## Project goals

- Strengthen end-to-end encryption workflows, device trust, and key management.
- Improve local data protection and privacy-preserving defaults.
- Reduce unnecessary external service dependencies while retaining Matrix interoperability.
- Improve responsiveness, reliability, accessibility, and resource efficiency.
- Extend communication and customization capabilities across supported platforms.
- Maintain transparent, auditable open-source development.

## Existing capabilities

The inherited codebase includes:

- Private messaging, group chats, public rooms, and Matrix Spaces.
- End-to-end encryption, encrypted key backups, cross-signing, and device verification.
- Voice and video calls using Matrix RTC.
- Voice messages, file and media sharing, location sharing, and notifications.
- Room discovery, moderation, custom stickers, and reactions.
- Multiple languages, including Persian.
- Configuration through mobile device management (MDM) on Android and iOS, and web configuration.

These capabilities are present in the inherited source. Platform-specific behavior and security properties require validation in MatrixChat builds.

## Platforms

| Mobile | Desktop | Browser |
| --- | --- | --- |
| Android, iOS | Windows, Linux, macOS | Web |

## Security and development roadmap

| Area | Planned improvements |
| --- | --- |
| Encryption and identity | Review device trust, key sharing, recovery, and session security |
| Local storage | Fail-closed encryption, safe database recovery, and protected media caches |
| Network privacy | Review external endpoints, notification privacy, and secure transport |
| Application security | Harden permissions, untrusted content handling, and sensitive logging |
| Performance | Profile synchronization, startup, memory, and battery consumption |
| Release integrity | Dependency auditing, automated tests, reproducible builds, and signed releases |

These are development objectives, not claims of completed security hardening or independent security certification.

## Getting started

Install [Flutter](https://flutter.dev/) using the version specified in [`.fvmrc`](.fvmrc), and install [Rust](https://www.rust-lang.org/tools/install) and the platform-specific build prerequisites.

```bash
git clone https://github.com/MSMSofts/matrixchat.git
cd matrixchat
flutter pub get
flutter run
```

### Web

Run the preparation script before building the web client. The script requires a compatible shell and its command-line dependencies.

```bash
./scripts/prepare-web.sh
flutter build web
```

### Configuration

See [config.sample.json](config.sample.json) for available settings. For web deployments, serve a `config.json` alongside the application with only the settings you want to override. Android MDM settings are documented in [app_restrictions.xml](android/app/src/main/res/xml/app_restrictions.xml).

### Testing

```bash
flutter analyze
flutter test
```

Integration tests require Docker and preparation of the test environment:

```bash
./scripts/prepare_integration_test.sh
flutter test integration_test/mobile_test.dart
```

## Project status

MatrixChat is under development. The inherited application identifiers, branding, service endpoints, and release workflows are not yet fully migrated. The repository does not currently establish that all planned hardening measures have been implemented or that production builds have passed security audits.

## Contributing and security

- [MatrixChat repository](https://github.com/MSMSofts/matrixchat)
- [Issue tracker](https://github.com/MSMSofts/matrixchat/issues)
- [Contribution guidelines](CONTRIBUTING.md) (inherited from upstream)
- [Security policy](SECURITY.md) (currently inherited from upstream)

Please report potential security vulnerabilities privately rather than posting sensitive details in public issues.

## Upstream attribution

MatrixChat builds on the work of Christian Kußowski and the FluffyChat contributors. The original project and its community remain credited for the inherited source, designs, translations, and testing.

- [FluffyChat source](https://github.com/krille-chan/fluffychat)
- [FluffyChat website](https://fluffychat.im)
- [Upstream translations](https://hosted.weblate.org/projects/fluffychat/)
- [Upstream community](https://matrix.to/#/#fluffy-space:matrix.org)
- [Upstream updates](https://troet.cafe/@krille)
- [Support upstream on Liberapay](https://de.liberapay.com/KrilleChritzelius) or [Ko-fi](https://ko-fi.com/krille)

Special thanks to [Fabiyamada](https://github.com/fabiyamada) for the original FluffyChat logo and banner, all translators and testers, the Matrix Foundation for the [SAS emoji translations](https://github.com/matrix-org/matrix-spec/blob/main/data-definitions/sas-emoji.json) (Apache-2.0), MTRNord, Sorunome, and Advocatux.

## License

The inherited codebase is licensed under the GNU Affero General Public License, version 3 or later (AGPL-3.0-or-later). See [LICENSE](LICENSE) and [LICENSES](LICENSES) for applicable notices and component licenses.

Existing copyright and license notices are retained.
