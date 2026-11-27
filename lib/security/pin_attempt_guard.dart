// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:synchronized/synchronized.dart';

/// Best-effort restart-resistant throttling, not hardware anti-hammering.
class PinAttemptGuard {
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  final DateTime Function() now;
  final _lock = Lock();

  PinAttemptGuard({
    required this.read,
    required this.write,
    this.now = DateTime.now,
  });

  int retryAfterSeconds = 0;

  Future<void> _persist(int failures, int blockedUntil) async {
    final value = jsonEncode({
      'failures': failures,
      'blockedUntil': blockedUntil,
    });
    await write(value);
    if (await read() != value) {
      throw StateError('PIN attempt state was not persisted.');
    }
  }

  Future<bool> verify(bool Function() checkPin) =>
      _lock.synchronized(() async {
        retryAfterSeconds = 5;
        try {
          final stored = await read();
          var failures = 0;
          var blockedUntil = 0;
          if (stored != null) {
            final decoded = jsonDecode(stored);
            if (decoded is! Map<String, dynamic>) return false;
            final count = decoded['failures'];
            final until = decoded['blockedUntil'];
            if (count is! int ||
                count < 0 ||
                count > 7 ||
                until is! int ||
                until < 0) {
              return false;
            }
            failures = count;
            blockedUntil = until;
          }
          final time = now().millisecondsSinceEpoch;
          if (blockedUntil > time) {
            retryAfterSeconds = ((blockedUntil - time + 999) ~/ 1000)
                .clamp(1, 300);
            return false;
          }

          // Persist an attempt before comparing the PIN.
          final nextFailures = (failures + 1).clamp(1, 7);
          retryAfterSeconds = (5 * (1 << (nextFailures - 1))).clamp(5, 300);
          await _persist(nextFailures, time + retryAfterSeconds * 1000);
          if (!checkPin()) return false;
          await _persist(0, 0);
          retryAfterSeconds = 0;
          return true;
        } catch (_) {
          return false;
        }
      });

  Future<void> resetAfterBiometric() => _lock.synchronized(() async {
    await _persist(0, 0);
    retryAfterSeconds = 0;
  });
}
