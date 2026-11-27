// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:fluffychat/security/security_policy.dart';

abstract final class RtcSecurity {
  static bool permitsFocus(Uri uri) =>
      SecurityPolicy.permitsUri(uri) &&
      !uri.hasQuery &&
      !uri.hasFragment;

  static bool permitsMediaEndpoint(Uri uri) =>
      (uri.scheme == 'wss' || uri.scheme == 'https') &&
      SecurityPolicy.permitsUri(uri.replace(scheme: 'https')) &&
      !uri.hasFragment;

  static bool matchesOlmSender({
    required Map<String, dynamic>? encryptedContent,
    required String? deviceCurveKey,
  }) =>
      deviceCurveKey != null &&
      deviceCurveKey.isNotEmpty &&
      encryptedContent?['algorithm'] == 'm.olm.v1.curve25519-aes-sha2' &&
      encryptedContent?['sender_key'] == deviceCurveKey;

  static Uint8List? decodeCallKey(String key, int index) {
    if (index < 0 || index > 255 || key.length > 64) return null;
    try {
      final bytes = base64Decode(key);
      if (bytes.length == 16 || bytes.length == 32) return bytes;
    } catch (_) {
      // Invalid input is rejected without logging key material.
    }
    return null;
  }
}
