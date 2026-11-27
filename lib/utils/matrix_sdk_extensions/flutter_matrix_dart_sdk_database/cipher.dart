// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/security_policy.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';

const _passwordStorageKey = 'database_password';
final _keyLock = Lock();

const iosOptions = IOSOptions(
  groupId: 'group.im.fluffychat.app',
  accessibility: .first_unlock,
);

/// Never erase a key or downgrade to plaintext after a storage error.
Future<String> getDatabaseCipher({
  required Future<bool> Function() hasExistingData,
}) => _keyLock.synchronized(() async {
  final storage = FlutterSecureStorage(iOptions: iosOptions);
  try {
    return await SecurityPolicy.resolveStorageKey(
      read: () => storage.read(key: _passwordStorageKey, iOptions: iosOptions),
      readLegacy: () async {
        if (!PlatformInfos.isIOS) return null;
        return const FlutterSecureStorage().read(key: _passwordStorageKey);
      },
      write: (value) => storage.write(
        key: _passwordStorageKey,
        value: value,
        iOptions: iosOptions,
      ),
      hasExistingData: hasExistingData,
    );
  } catch (_) {
    throw const SecurityStorageException();
  }
});
