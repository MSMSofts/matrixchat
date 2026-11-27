// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/network_guard.dart';
import 'package:fluffychat/security/security_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class RecordingClient extends http.BaseClient {
  int requests = 0;
  bool? followedRedirects;
  int statusCode;

  RecordingClient({this.statusCode = 200});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    followedRedirects = request.followRedirects;
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream.value(<int>[]),
      statusCode,
      headers: {'location': 'http://example.org'},
    );
  }
}

class RedirectClient extends http.BaseClient {
  final List<Uri> urls = [];
  final List<Map<String, String>> headers = [];
  final List<String> locations;

  RedirectClient(this.locations);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    headers.add(Map.of(request.headers));
    expect(request.followRedirects, isFalse);
    await request.finalize().drain<void>();
    final index = urls.length - 1;
    return http.StreamedResponse(
      Stream.value(<int>[]),
      index < locations.length ? 302 : 200,
      headers: {
        if (index < locations.length) 'location': locations[index],
      },
    );
  }
}

void main() {
  test('same-origin HTTPS media redirect preserves authorization', () async {
    final inner = RedirectClient(['/new-media']);
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    final result = await guard.get(
      Uri.parse('https://matrix.org/_matrix/client/v1/media/download/a/b'),
      headers: {'authorization': 'Bearer test-token'},
    );
    expect(result.statusCode, 200);
    expect(inner.headers.last['authorization'], 'Bearer test-token');
  });

  test('cross-origin media redirect strips credentials', () async {
    final inner = RedirectClient(['https://cdn.example/object?signature=test']);
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    final result = await guard.get(
      Uri.parse('https://matrix.org/_matrix/client/v1/media/download/a/b'),
      headers: {
        'authorization': 'Bearer test-token',
        'cookie': 'secret',
        'x-private': 'secret',
        'range': 'bytes=0-9',
      },
    );
    expect(result.statusCode, 200);
    expect(inner.headers.last, {'range': 'bytes=0-9'});
  });

  test('non-media cross-origin redirects are not dispatched', () async {
    final inner = RedirectClient(['https://other.example/path']);
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    expect(
      (await guard.get(Uri.parse('https://matrix.org/_matrix/client/v3/sync')))
          .statusCode,
      302,
    );
    expect(inner.urls.length, 1);
  });

  test('redirect loops are stopped', () async {
    final inner = RedirectClient(['/start']);
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    expect(
      (await guard.get(Uri.parse('https://matrix.org/start'))).statusCode,
      302,
    );
    expect(inner.urls.length, 1);
  });

  test('HTTPS accepted; cleartext and URL credentials rejected', () {
    expect(SecurityPolicy.permitsUri(Uri.parse('https://matrix.org')), isTrue);
    expect(SecurityPolicy.permitsUri(Uri.parse('http://matrix.org')), isFalse);
    expect(
      SecurityPolicy.permitsUri(Uri.parse('https://user:pass@matrix.org')),
      isFalse,
    );
    expect(SecurityPolicy.permitsUri(Uri.parse('file:///tmp/test')), isFalse);
  });

  test('local test override is restricted', () {
    expect(
      SecurityPolicy.permitsUri(
        Uri.parse('http://127.0.0.1:8008'),
        allowLocalTestHttp: true,
      ),
      isTrue,
    );
    expect(
      SecurityPolicy.permitsUri(
        Uri.parse('http://example.org'),
        allowLocalTestHttp: true,
      ),
      isFalse,
    );
  });

  test('cleartext HTTP is blocked before dispatch', () async {
    final inner = RecordingClient();
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    await expectLater(
      guard.get(Uri.parse('http://matrix.org')),
      throwsA(isA<http.ClientException>()),
    );
    expect(inner.requests, 0);
  });

  test('SDK requests do not follow redirects automatically', () async {
    final inner = RecordingClient(statusCode: 302);
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => false);
    addTearDown(guard.close);
    final response = await guard.get(Uri.parse('https://matrix.org'));
    expect(response.statusCode, 302);
    expect(inner.followedRedirects, isFalse);
    expect(inner.requests, 1);
  });

  test('strict policy blocks plaintext and permits encrypted events', () async {
    final inner = RecordingClient();
    final guard = NetworkGuard(inner, requireEncryptedTimeline: () => true);
    addTearDown(guard.close);
    const base =
        'https://matrix.org/_matrix/client/v3/rooms/!room:matrix.org/send';
    await expectLater(
      guard.put(Uri.parse('$base/m.room.message/1')),
      throwsA(isA<http.ClientException>()),
    );
    expect(inner.requests, 0);
    expect(
      (await guard.put(Uri.parse('$base/m.room.encrypted/1'))).statusCode,
      200,
    );
    expect(inner.requests, 1);
  });

  test('strict policy does not block state events or GET requests', () {
    expect(
      SecurityPolicy.isPlaintextTimelineSend(
        'PUT',
        Uri.parse(
          'https://matrix.org/_matrix/client/v3/rooms/!r:matrix.org/state/m.room.name',
        ),
      ),
      isFalse,
    );
    expect(
      SecurityPolicy.isPlaintextTimelineSend(
        'GET',
        Uri.parse(
          'https://matrix.org/_matrix/client/v3/rooms/!r:matrix.org/send/m.room.message/1',
        ),
      ),
      isFalse,
    );
  });
}
