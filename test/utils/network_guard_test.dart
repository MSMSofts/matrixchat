// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/network_guard.dart';
import 'package:fluffychat/security/security_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('HTTPS endpoints accepted; cleartext and URL credentials rejected', () {
    expect(SecurityPolicy.permitsUri(Uri.parse('https://matrix.org')), isTrue);
    expect(SecurityPolicy.permitsUri(Uri.parse('http://matrix.org')), isFalse);
    expect(SecurityPolicy.permitsUri(Uri.parse('https://user:pass@matrix.org')), isFalse);
    expect(SecurityPolicy.permitsUri(Uri.parse('file:///tmp/test')), isFalse);
  });

  test('local test override is restricted', () {
    expect(SecurityPolicy.permitsUri(Uri.parse('http://127.0.0.1:8008'), allowLocalTestHttp: true), isTrue);
    expect(SecurityPolicy.permitsUri(Uri.parse('http://example.org'), allowLocalTestHttp: true), isFalse);
  });

  test('cleartext HTTP is blocked before dispatch', () async {
    final guard = NetworkGuard(
      MockClient((_) async => throw StateError('unexpected dispatch')),
      requireEncryptedTimeline: () => false,
    );
    addTearDown(guard.close);
    await expectLater(guard.get(Uri.parse('http://matrix.org')), throwsA(isA<http.ClientException>()));
  });

  test('SDK requests do not follow redirects automatically', () async {
    final guard = NetworkGuard(
      MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response('', 302, headers: {'location': 'http://example.org'});
      }),
      requireEncryptedTimeline: () => false,
    );
    addTearDown(guard.close);
    expect((await guard.get(Uri.parse('https://matrix.org'))).statusCode, 302);
  });

  test('strict policy blocks plaintext timeline message and permits ciphertext', () async {
    final guard = NetworkGuard(
      MockClient((_) async => http.Response('{}', 200)),
      requireEncryptedTimeline: () => true,
    );
    addTearDown(guard.close);
    final base = 'https://matrix.org/_matrix/client/v3/rooms/!room:matrix.org/send';
    await expectLater(guard.put(Uri.parse('$base/m.room.message/1')), throwsA(isA<http.ClientException>()));
    expect((await guard.put(Uri.parse('$base/m.room.encrypted/1'))).statusCode, 200);
  });

  test('strict policy does not block state events or GET requests', () {
    expect(SecurityPolicy.isPlaintextTimelineSend('PUT', Uri.parse('https://matrix.org/_matrix/client/v3/rooms/!r:matrix.org/state/m.room.name')), isFalse);
    expect(SecurityPolicy.isPlaintextTimelineSend('GET', Uri.parse('https://matrix.org/_matrix/client/v3/rooms/!r:matrix.org/send/m.room.message/1')), isFalse);
  });
}
