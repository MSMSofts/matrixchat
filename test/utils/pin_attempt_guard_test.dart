// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/pin_attempt_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('failed PIN attempt is retained across guard instances', () async {
    String? stored;
    var time = DateTime.utc(2026, 1, 1);
    PinAttemptGuard create() => PinAttemptGuard(
      read: () async => stored,
      write: (value) async {
        stored = value;
      },
      now: () => time,
    );
    expect(await create().verify(() => false), isFalse);
    var compared = false;
    final second = create();
    expect(
      await second.verify(() {
        compared = true;
        return true;
      }),
      isFalse,
    );
    expect(compared, isFalse);
    expect(second.retryAfterSeconds, 5);
    time = time.add(const Duration(seconds: 5));
    expect(await second.verify(() => true), isTrue);
    expect(await create().verify(() => true), isTrue);
  });

  test('secure storage write failure cannot authorize PIN', () async {
    final guard = PinAttemptGuard(
      read: () async => null,
      write: (_) async => throw StateError('unavailable'),
    );
    expect(await guard.verify(() => true), isFalse);
  });

  test('corrupt counter does not authorize PIN', () async {
    final guard = PinAttemptGuard(
      read: () async => 'invalid',
      write: (_) async {},
    );
    expect(await guard.verify(() => true), isFalse);
  });

  test('biometric success resets persistent throttling', () async {
    String? stored;
    final guard = PinAttemptGuard(
      read: () async => stored,
      write: (value) async {
        stored = value;
      },
    );
    expect(await guard.verify(() => false), isFalse);
    await guard.resetAfterBiometric();
    expect(await guard.verify(() => true), isTrue);
  });

  test('silent storage write failure cannot authorize PIN', () async {
    final guard = PinAttemptGuard(
      read: () async => null,
      write: (_) async {},
    );
    expect(await guard.verify(() => true), isFalse);
  });
}
