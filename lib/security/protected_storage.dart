// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Shared options for security-critical secrets. The plugin's default Android
/// resetOnError is true: a failed operation may otherwise erase stored values.
/// Keep the existing namespace and algorithm migration compatibility.
abstract final class ProtectedStorage {
  static const android = AndroidOptions(
    resetOnError: false,
    migrateWithBackup: true,
  );

  static const local = FlutterSecureStorage(aOptions: android);

  // The app and its existing iOS notification extension share these keys.
  // Changing the access group or access requirements would require a tested
  // migration; do not silently create a new key in a different namespace.
  static const sharedIos = IOSOptions(
    groupId: 'group.im.fluffychat.app',
    accessibility: .first_unlock,
  );

  static const shared = FlutterSecureStorage(
    aOptions: android,
    iOptions: sharedIos,
  );
}
