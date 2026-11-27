// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';

enum SecurityPreset {
  compatible,
  encrypted,
  verified;

  bool get requiresEncryption => this != compatible;
  bool get requiresVerification => this == verified;

  /// Presets are explicit one-time settings bundles, not managed policy.
  Map<AppSettings<bool>, bool> get settings => {
    AppSettings.privateNotifications: true,
    AppSettings.persistPlaintextDrafts: false,
    AppSettings.persistEncryptedDrafts: !requiresVerification,
    AppSettings.persistMediaCache: false,
    AppSettings.sendTypingNotifications: false,
    AppSettings.sendPublicReadReceipts: false,
    AppSettings.checkForUpdates: false,
    AppSettings.renderHtml: this == compatible,
    AppSettings.requireEncryptedRooms: requiresEncryption,
    AppSettings.requireVerifiedIdentities: requiresVerification,
  };

  Future<void> apply() async {
    final store = AppSettings.store;
    for (final entry in settings.entries) {
      if (!await store.setBool(entry.key.key, entry.value) ||
          store.getBool(entry.key.key) != entry.value) {
        throw StateError('Security preset could not be saved.');
      }
    }
    if (!await store.setString(AppSettings.shareKeysWith.key, 'verifiedOnly') ||
        store.getString(AppSettings.shareKeysWith.key) != 'verifiedOnly') {
      throw StateError('Key sharing policy could not be saved.');
    }
  }
}
