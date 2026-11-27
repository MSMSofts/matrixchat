// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/identity_pin.dart';
import 'package:fluffychat/security/room_crypto_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only supported room crypto with enabled SDK is accepted', () {
    const megolm = 'm.megolm.v1.aes-sha2';
    expect(
      RoomCryptoPolicy.canEncrypt(
        algorithm: megolm,
        encryptionEnabled: true,
      ),
      isTrue,
    );
    for (final algorithm in [null, '', 'm.unknown', megolm]) {
      expect(
        RoomCryptoPolicy.canEncrypt(
          algorithm: algorithm,
          encryptionEnabled: false,
        ),
        isFalse,
      );
    }
    expect(
      RoomCryptoPolicy.canEncrypt(
        algorithm: 'm.unknown',
        encryptionEnabled: true,
      ),
      isFalse,
    );
  });

  test('verified identities are pinned and changes are rejected', () async {
    final values = <String, String>{};
    final pin = IdentityPin(
      read: (key) async => values[key],
      write: (key, value) async {
        values[key] = value;
      },
    );
    Future<IdentityPinResult> check(String key) => pin.check(
      account: 'account',
      userId: '@contact:example.org',
      publicKey: key,
      verified: true,
    );
    expect(await check('first'), IdentityPinResult.firstPin);
    expect(await check('first'), IdentityPinResult.matched);
    expect(await check('second'), IdentityPinResult.changed);
    expect(await check('first'), IdentityPinResult.matched);
  });

  test('unverified identity and failed storage cannot create trust', () async {
    final pin = IdentityPin(
      read: (_) async => throw StateError('unavailable'),
      write: (_, _) async => fail('unexpected write'),
    );
    for (final verified in [true, false]) {
      expect(
        await pin.check(
          account: 'account',
          userId: 'contact',
          publicKey: 'key',
          verified: verified,
        ),
        IdentityPinResult.unavailable,
      );
    }
  });

  test('account and identity keys have distinct storage namespaces', () {
    expect(
      IdentityPin.storageKey('a:b', 'c'),
      isNot(IdentityPin.storageKey('a', 'b:c')),
    );
  });

  test('strict rotation uses standard Matrix state fields', () {
    final normal = RoomCryptoPolicy.encryptionContent(strict: false);
    final strict = RoomCryptoPolicy.encryptionContent(strict: true);
    expect(strict['algorithm'], normal['algorithm']);
    expect(strict['rotation_period_ms'], 3600000);
    expect(strict['rotation_period_msgs'], 20);
  });
}
