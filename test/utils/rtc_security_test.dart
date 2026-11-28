// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:fluffychat/security/rtc_security.dart';
import 'package:fluffychat/utils/matrix_live_kit_calls/call_keys_event_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';

void main() {
  test('RTC focus and media endpoints require secure transport', () {
    expect(RtcSecurity.permitsFocus(Uri.parse('https://rtc.example')), isTrue);
    expect(RtcSecurity.permitsFocus(Uri.parse('http://rtc.example')), isFalse);
    expect(
      RtcSecurity.permitsFocus(Uri.parse('https://u@rtc.example')),
      isFalse,
    );
    expect(
      RtcSecurity.permitsMediaEndpoint(Uri.parse('wss://rtc.example')),
      isTrue,
    );
    expect(
      RtcSecurity.permitsMediaEndpoint(Uri.parse('ws://rtc.example')),
      isFalse,
    );
  });

  test('Olm sender must match the claimed device key', () {
    final encrypted = <String, dynamic>{
      'algorithm': 'm.olm.v1.curve25519-aes-sha2',
      'sender_key': 'device-key',
    };
    expect(
      RtcSecurity.matchesOlmSender(
        encryptedContent: encrypted,
        deviceCurveKey: 'device-key',
      ),
      isTrue,
    );
    expect(
      RtcSecurity.matchesOlmSender(
        encryptedContent: encrypted,
        deviceCurveKey: 'other',
      ),
      isFalse,
    );
    expect(
      RtcSecurity.matchesOlmSender(
        encryptedContent: null,
        deviceCurveKey: 'device-key',
      ),
      isFalse,
    );
    final wrapped = CallKeysEvent.fromToDeviceEvent(
      ToDeviceEvent(
        sender: '@a:example.org',
        type: CallKeysEventContent.eventType,
        content: {},
        encryptedContent: encrypted,
      ),
    );
    expect(wrapped.encryptedContent, encrypted);
  });

  test('invalid RTC key encodings, lengths and indexes are rejected', () {
    final key = base64Encode(List<int>.filled(16, 1));
    expect(RtcSecurity.decodeCallKey(key, 0), isNotNull);
    expect(RtcSecurity.decodeCallKey(key, 255), isNotNull);
    expect(RtcSecurity.decodeCallKey(key, -1), isNull);
    expect(RtcSecurity.decodeCallKey(key, 256), isNull);
    expect(RtcSecurity.decodeCallKey('invalid!', 0), isNull);
    expect(RtcSecurity.decodeCallKey(base64Encode([1]), 0), isNull);
  });
}
