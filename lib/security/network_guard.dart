// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/security_policy.dart';
import 'package:http/http.dart' as http;

/// Boundary for SDK HTTP requests. Does not cover browser navigation,
/// native plugins, WebRTC, or HTTP clients instantiated elsewhere.
class NetworkGuard extends http.BaseClient {
  final http.Client _inner;
  final bool allowLocalTestHttp;
  final bool Function() requireEncryptedTimeline;

  NetworkGuard(
    this._inner, {
    required this.requireEncryptedTimeline,
    this.allowLocalTestHttp = false,
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
    // Never let an HTTP implementation silently redirect a request carrying
    // credentials to another origin or to HTTP. Explicit SDK requests are
    // checked again at this boundary.
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
