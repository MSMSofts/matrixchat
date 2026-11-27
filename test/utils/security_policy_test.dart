// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/security_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

void main() {
  test('account names cannot escape the local database directory', () {
    for (final name in ['', '.', '..', '../other', '/absolute', r'..\other']) {
      expect(SecurityPolicy.isSafeClientName(name), isFalse);
    }
    expect(SecurityPolicy.isSafeClientName('MatrixChat'), isTrue);
  });

  test('permissive and unknown key-sharing policies fail closed', () {
    for (final value in ['all', 'crossVerifiedIfEnabled', '', 'invalid']) {
      expect(SecurityPolicy.keySharing(value), ShareKeysWith.verifiedOnly);
    }
    expect(
      SecurityPolicy.keySharing('directlyVerifiedOnly'),
      ShareKeysWith.verifiedOnly,
    );
  });

  test('existing key is returned without generating or writing', () async {
    expect(
      await SecurityPolicy.resolveStorageKey(
        read: () async => 'existing',
        readLegacy: () async => throw StateError('unexpected legacy read'),
        write: (_) async => throw StateError('unexpected write'),
        hasExistingData: () async => true,
      ),
      'existing',
    );
  });

  test(
    'missing key with existing database never writes a replacement',
    () async {
      await expectLater(
        SecurityPolicy.resolveStorageKey(
          read: () async => null,
          readLegacy: () async => null,
          write: (_) async => fail('must not write'),
          hasExistingData: () async => true,
        ),
        throwsA(isA<SecurityStorageException>()),
      );
    },
  );

  test('storage read failure never generates a replacement', () async {
    await expectLater(
      SecurityPolicy.resolveStorageKey(
        read: () async => throw StateError('unavailable'),
        readLegacy: () async => null,
        write: (_) async => fail('must not write'),
        hasExistingData: () async => false,
      ),
      throwsStateError,
    );
  });

  test('new key must be read back unchanged', () async {
    String? stored;
    expect(
      await SecurityPolicy.resolveStorageKey(
        read: () async => stored,
        readLegacy: () async => null,
        write: (key) async {
          stored = key;
        },
        hasExistingData: () async => false,
        generate: () => 'new-test-key',
      ),
      'new-test-key',
    );
  });

  test('failed key readback is rejected', () async {
    await expectLater(
      SecurityPolicy.resolveStorageKey(
        read: () async => null,
        readLegacy: () async => null,
        write: (_) async {},
        hasExistingData: () async => false,
        generate: () => 'test',
      ),
      throwsA(isA<SecurityStorageException>()),
    );
  });

  test('legacy key is migrated only after successful readback', () async {
    String? stored;
    expect(
      await SecurityPolicy.resolveStorageKey(
        read: () async => stored,
        readLegacy: () async => 'legacy',
        write: (key) async {
          stored = key;
        },
        hasExistingData: () async => true,
      ),
      'legacy',
    );
  });
}
