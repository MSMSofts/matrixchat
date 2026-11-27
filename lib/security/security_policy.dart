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

  static ShareKeysWith keySharing(String stored) {
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

  /// Detect plaintext message-like timeline events sent through the client
  /// API. State events and encrypted events are intentionally not blocked.
  static bool isPlaintextTimelineSend(String method, Uri uri) {
    if (method != 'PUT' && method != 'POST') return false;
    final path = uri.pathSegments;
    if (path.length < 7 ||
        path[0] != '_matrix' ||
        path[1] != 'client' ||
        path[3] != 'rooms' ||
        path[5] != 'send') {
      return false;
    }
    final type = path[6];
    return const {
      'm.room.message',
      'm.sticker',
      'm.poll.start',
      'm.poll.response',
      'm.poll.end',
      'org.matrix.msc3381.poll.start',
      'org.matrix.msc3381.poll.response',
      'org.matrix.msc3381.poll.end',
      'm.reaction',
    }.contains(type);
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
