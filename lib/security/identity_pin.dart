// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/security/protected_storage.dart';
import 'package:synchronized/synchronized.dart';

enum IdentityPinResult { matched, firstPin, changed, unavailable }

/// A local continuity check, not a global key-transparency service.
class IdentityPin {
  final Future<String?> Function(String) read;
  final Future<void> Function(String, String) write;
  final _lock = Lock();

  IdentityPin({required this.read, required this.write});

  static const _storage = ProtectedStorage.local;
  static final instance = IdentityPin(
    read: (key) => _storage.read(key: key),
    write: (key, value) => _storage.write(key: key, value: value),
  );

  static String storageKey(String account, String userId) =>
      'matrixchat.identity.v1.${base64UrlEncode(utf8.encode(jsonEncode([account, userId])))}';

  Future<IdentityPinResult> check({
    required String account,
    required String userId,
    required String publicKey,
    required bool verified,
  }) => _lock.synchronized(() async {
    if (!verified || publicKey.isEmpty) return IdentityPinResult.unavailable;
    try {
      final key = storageKey(account, userId);
      final existing = await read(key);
      if (existing != null) {
        return existing == publicKey
            ? IdentityPinResult.matched
            : IdentityPinResult.changed;
      }
      await write(key, publicKey);
      return await read(key) == publicKey
          ? IdentityPinResult.firstPin
          : IdentityPinResult.unavailable;
    } catch (_) {
      return IdentityPinResult.unavailable;
    }
  });

  /// Call only after a fresh interactive verification and explicit consent.
  Future<bool> replaceAfterVerification({
    required String account,
    required String userId,
    required String publicKey,
    required bool verified,
  }) => _lock.synchronized(() async {
    if (!verified || publicKey.isEmpty) return false;
    try {
      final key = storageKey(account, userId);
      await write(key, publicKey);
      return await read(key) == publicKey;
    } catch (_) {
      return false;
    }
  });
}
