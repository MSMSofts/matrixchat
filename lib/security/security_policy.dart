// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:math';

import 'package:matrix/matrix.dart';

class SecurityStorageException implements Exception {
  const SecurityStorageException();

  @override
  String toString() =>
      'Secure storage unavailable. Existing data was preserved.';
}

abstract final class SecurityPolicy {
  static const allowedKeySharing = {
    ShareKeysWith.verifiedOnly,
    ShareKeysWith.crossVerified,
  };

  static ShareKeysWith keySharing(
    String stored, {
    bool requireVerified = false,
  }) {
    if (requireVerified) return ShareKeysWith.verifiedOnly;
    for (final policy in allowedKeySharing) {
      if (policy.name == stored) return policy;
    }
    return ShareKeysWith.verifiedOnly;
  }

  static bool isSafeClientName(String name) =>
      name.isNotEmpty &&
      name != '.' &&
      name != '..' &&
      !name.contains(RegExp(r'[/\\\x00]'));

  /// Production traffic must use TLS. The explicit test override is limited
  /// to local emulator/test addresses and must never be enabled in release.
  static bool permitsUri(Uri uri, {bool allowLocalTestHttp = false}) {
    if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.scheme == 'https') return true;
    return allowLocalTestHttp &&
        uri.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(uri.host);
  }

  /// Strict mode accepts only the encrypted event type on timeline send APIs.
  /// Unknown event types cannot bypass a plaintext blacklist. State events
  /// use a different endpoint and are not covered by this check.
  static bool isPlaintextTimelineSend(String method, Uri uri) {
    if (method != 'PUT' && method != 'POST') return false;
    final path = uri.pathSegments;
    for (var i = 0; i + 6 < path.length; i++) {
      if (path[i] == '_matrix' &&
          path[i + 1] == 'client' &&
          path[i + 3] == 'rooms' &&
          path[i + 5] == 'send') {
        return path[i + 6] != EventTypes.Encrypted;
      }
    }
    return false;
  }

  static String generateStorageKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final encoded = base64UrlEncode(bytes);
    bytes.fillRange(0, bytes.length, 0);
    return encoded;
  }

  /// Refuse to replace a missing key for existing data.
  static Future<String> resolveStorageKey({
    required Future<String?> Function() read,
    required Future<String?> Function() readLegacy,
    required Future<void> Function(String) write,
    required Future<bool> Function() hasExistingData,
    String Function() generate = generateStorageKey,
  }) async {
    final current = await read();
    if (current != null) {
      if (current.isEmpty) throw const SecurityStorageException();
      return current;
    }
    final legacy = await readLegacy();
    if (legacy != null && legacy.isEmpty) {
      throw const SecurityStorageException();
    }
    if (legacy == null && await hasExistingData()) {
      throw const SecurityStorageException();
    }
    final key = legacy ?? generate();
    if (key.isEmpty) throw const SecurityStorageException();
    await write(key);
    if (await read() != key) throw const SecurityStorageException();
    return key;
  }
}
