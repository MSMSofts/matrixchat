// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:io';

import 'package:fluffychat/security/security_policy.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:universal_html/html.dart' as html;

import 'cipher.dart';

Future<DatabaseApi> flutterMatrixSdkDatabaseBuilder(String clientName) async {
  try {
    return await _constructDatabase(clientName);
  } catch (_) {
    // Preserve the database and key. Never retry with a fresh database.
    throw const SecurityStorageException();
  }
}

Future<Directory?> getFileStorageLocation() async {
  try {
    late final Directory temporaryDirectory;
    if (PlatformInfos.isIOS) {
      final containerPath = await PathProviderFoundation().getContainerPath(
        appGroupIdentifier: 'group.im.fluffychat.app',
      );
      temporaryDirectory = Directory(containerPath!);
    } else if (PlatformInfos.isLinux) {
      temporaryDirectory = await getApplicationCacheDirectory();
    } else {
      temporaryDirectory = await getTemporaryDirectory();
    }
    return await Directory(
      join(temporaryDirectory.path, 'fluffychat_download_cache'),
    ).create(recursive: true);
  } on MissingPlatformDirectoryException catch (_) {
    Logs().w(
      'No temporary directory for file cache available on this platform.',
    );
  }
  return null;
}

Future<MatrixSdkDatabase> _constructDatabase(String clientName) async {
  if (kIsWeb) {
    html.window.navigator.storage?.persist();
    return await MatrixSdkDatabase.init(clientName);
  }

  final factory = createDatabaseFactoryFfi();
  databaseFactory = factory;

  final path = await _resolveDatabasePath(clientName);
  final cipher = await getDatabaseCipher(
    hasExistingData: () async {
      if (await File(path).exists()) return true;
      // The key is shared by accounts.
      final directory = Directory(dirname(path));
      if (!await directory.exists()) return false;
      return directory.list().any(
        (entry) => entry is File && entry.path.endsWith('.sqlite'),
      );
    },
  );
  final fileStorageLocation = await getFileStorageLocation();
  final helper = SQfLiteEncryptionHelper(
    factory: factory,
    path: path,
    cipher: cipher,
  );

  // No automatic plaintext conversion or destructive recovery.
  final database = await factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await helper.applyPragmaKey(db, ensureIncrementalAutoVacuum: true);
        final cipherVersion = await db.rawQuery('PRAGMA cipher_version');
        if (cipherVersion.isEmpty ||
            cipherVersion.first.values.every(
              (value) => value == null || value.toString().isEmpty,
            )) {
          throw const SecurityStorageException();
        }
        await db.rawQuery('SELECT count(*) FROM sqlite_master');
      },
    ),
  );

  final secureStorage = FlutterSecureStorage(iOptions: iosOptions);

  return await MatrixSdkDatabase.init(
    clientName,
    database: database,
    maxFileSize: 1000 * 1000 * 10,
    fileStorageLocation: fileStorageLocation?.uri,
    deleteFilesAfterDuration: const Duration(days: 30),
    secureStorage: (
      read: (key) => secureStorage.read(key: key),
      write: (key, value) => secureStorage.write(key: key, value: value),
      delete: (key) => secureStorage.delete(key: key),
    ),
  );
}

Future<String> _getDatabaseDirectory() async {
  if (PlatformInfos.isIOS) {
    final containerPath = await PathProviderFoundation().getContainerPath(
      appGroupIdentifier: 'group.im.fluffychat.app',
    );
    if (containerPath == null) {
      Logs().w('No container path found for iOS app!');
      return (await getLibraryDirectory()).path;
    }
    return containerPath;
  }
  if (PlatformInfos.isMacOS) {
    return (await getLibraryDirectory()).path;
  }
  return (await getApplicationSupportDirectory()).path;
}

Future<String> _getDatabasePath(String clientName) async {
  final databaseDirectory = await _getDatabaseDirectory();

  return join(databaseDirectory, '$clientName.sqlite');
}

Future<String> _resolveDatabasePath(String clientName) async {
  final current = await _getDatabasePath(clientName);
  final oldDirectory = PlatformInfos.isDesktop
      ? (await getApplicationSupportDirectory()).path
      : PlatformInfos.isIOS
      ? (await getLibraryDirectory()).path
      : await getDatabasesPath();
  final legacy = join(oldDirectory, '$clientName.sqlite');
  if (legacy == current || !await File(legacy).exists()) return current;
  // Open the legacy location in place. Never overwrite or delete either copy.
  if (await File(current).exists()) throw const SecurityStorageException();
  return legacy;
}
