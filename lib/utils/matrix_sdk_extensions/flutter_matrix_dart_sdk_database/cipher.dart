// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/protected_storage.dart';
import 'package:fluffychat/security/security_policy.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:synchronized/synchronized.dart';

const _passwordStorageKey = 'database_password';
final _keyLock = Lock();

/// Never erase a key or downgrade to plaintext after a storage error.
Future<String> getDatabaseCipher({
  required Future<bool> Function() hasExistingData,
}) => _keyLock.synchronized(() async {
  final storage = ProtectedStorage.shared;
  try {
    return await SecurityPolicy.resolveStorageKey(
      read: () => storage.read(key: _passwordStorageKey, iOptions: ProtectedStorage.sharedIos),
      readLegacy: () async {
        if (!PlatformInfos.isIOS) return null;
        return ProtectedStorage.local.read(key: _passwordStorageKey);
      },
      write: (value) => storage.write(
        key: _passwordStorageKey,
        value: value,
        iOptions: ProtectedStorage.sharedIos,
      ),
      hasExistingData: hasExistingData,
    );
  } catch (_) {
    throw const SecurityStorageException();
  }
});
