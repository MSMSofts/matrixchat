// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/security_policy.dart';
import 'package:http/http.dart' as http;

/// Boundary for SDK HTTP requests. Does not cover browser navigation,
/// native plugins, WebRTC, or HTTP clients instantiated elsewhere.
class NetworkGuard extends http.BaseClient {
  final http.Client _inner;
  final bool allowLocalTestHttp;
  final bool allowSafeRedirects;
  final bool Function() requireEncryptedTimeline;

  NetworkGuard(
    this._inner, {
    required this.requireEncryptedTimeline,
    this.allowLocalTestHttp = false,
    this.allowSafeRedirects = true,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!SecurityPolicy.permitsUri(
      request.url,
      allowLocalTestHttp: allowLocalTestHttp,
    )) {
      throw http.ClientException('MatrixChat blocked an insecure endpoint.');
    }
    if (requireEncryptedTimeline() &&
        SecurityPolicy.isPlaintextTimelineSend(request.method, request.url)) {
      throw http.ClientException(
        'MatrixChat blocked a plaintext timeline event.',
      );
    }
    // Never delegate redirect handling to a transport. Only native, bodyless
    // GET/HEAD requests may follow a bounded, independently validated chain.
    final follow =
        allowSafeRedirects &&
        request.followRedirects &&
        (request.method == 'GET' || request.method == 'HEAD') &&
        request.contentLength == 0;
    request.followRedirects = false;
    var response = await _inner.send(request);
    if (!follow) return response;

    var current = request.url;
    var headers = Map<String, String>.of(request.headers);
    final media = _isMediaRead(current);
    final visited = <Uri>{current};
    for (var hop = 0; hop < 3; hop++) {
      if (!const {301, 302, 303, 307, 308}.contains(response.statusCode)) {
        return response;
      }
      final location = response.headers['location'];
      if (location == null || location.isEmpty) return response;
      Uri target;
      try {
        target = current.resolve(location);
      } on FormatException {
        return response;
      }
      if (!SecurityPolicy.permitsUri(target) ||
          target.hasFragment ||
          !visited.add(target)) {
        return response;
      }

      if (target.origin != current.origin) {
        if (!media || target.queryParameters.containsKey('access_token')) {
          return response;
        }
        // Matrix authenticated media may redirect to signed object-storage
        // URLs. Never forward cookies, authorization, custom headers,
        // referrers or other origin credentials to the CDN.
        headers = {
          for (final entry in headers.entries)
            if (const {'accept', 'range'}.contains(entry.key.toLowerCase()))
              entry.key: entry.value,
        };
      }
      await response.stream.listen(null).cancel();
      final next = http.Request(request.method, target)
        ..headers.addAll(headers)
        ..followRedirects = false;
      current = target;
      response = await _inner.send(next);
    }
    return response;
  }

  static bool _isMediaRead(Uri uri) {
    final path = uri.pathSegments;
    if (path.length < 5 || path[0] != '_matrix') return false;
    if (path[1] == 'client') {
      return path.length >= 6 &&
          path[3] == 'media' &&
          const {'download', 'thumbnail'}.contains(path[4]);
    }
    return path[1] == 'media' &&
        const {'download', 'thumbnail'}.contains(path[3]);
  }

  @override
  void close() => _inner.close();
}
