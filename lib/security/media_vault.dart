// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uses the account's already-open SQLCipher database. This class does not
/// create keys or open a second unencrypted connection.
class MediaVault {
  static const table = 'matrixchat_media_vault_v1';
  static const maxCachedFileBytes = 10 * 1000 * 1000;
  static const maxCachedBytes = 128 * 1000 * 1000;

  final Database database;
  final bool Function() cacheEnabled;

  MediaVault(this.database, {required this.cacheEnabled});

  static bool isPending(Uri uri) =>
      uri.scheme == 'cache' && (uri.host == 'file' || uri.host == 'thumbnail');

  Future<void> initialize() async {
    await database.execute(
      'CREATE TABLE IF NOT EXISTS $table ('
      'uri TEXT PRIMARY KEY NOT NULL, '
      'content BLOB NOT NULL, '
      'saved_at INTEGER NOT NULL, '
      'pending INTEGER NOT NULL CHECK (pending IN (0,1)))',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS matrixchat_media_vault_age '
      'ON $table (pending, saved_at)',
    );
  }

  Future<void> store(Uri uri, Uint8List bytes, int time) async {
    final pending = isPending(uri);
    if (!pending &&
        (!cacheEnabled() || bytes.lengthInBytes > maxCachedFileBytes)) {
      return;
    }
    await database.transaction((txn) async {
      await txn.insert(table, {
        'uri': uri.toString(),
        'content': bytes,
        'saved_at': time > 0 ? time : DateTime.now().millisecondsSinceEpoch,
        'pending': pending ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // Ordinary cache has a total budget; pending uploads are excluded.
      if (pending) return;
      final rows = await txn.rawQuery(
        'SELECT uri, length(content) AS size FROM $table '
        'WHERE pending = 0 ORDER BY saved_at DESC, uri',
      );
      var size = 0;
      for (final row in rows) {
        size += row['size'] as int;
        if (size > maxCachedBytes) {
          await txn.delete(table, where: 'uri = ?', whereArgs: [row['uri']]);
        }
      }
    });
  }

  Future<Uint8List?> get(Uri uri) async {
    if (!isPending(uri) && !cacheEnabled()) return null;
    final rows = await database.query(
      table,
      columns: ['content'],
      where: 'uri = ?',
      whereArgs: [uri.toString()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['content'] as Uint8List;
  }

  Future<bool> delete(Uri uri) async =>
      await database.delete(
        table,
        where: 'uri = ?',
        whereArgs: [uri.toString()],
      ) >
      0;

  Future<void> prune(int cutoff) async {
    await database.delete(table, where: 'saved_at < ?', whereArgs: [cutoff]);
  }

  Future<void> clear() async {
    await database.delete(table);
  }
}

/// Preserves Matrix SDK's pending attachment workflow, but never delegates
/// media persistence to its plaintext filesystem implementation on native.
class VaultMatrixDatabase extends MatrixSdkDatabase {
  final MediaVault vault;

  VaultMatrixDatabase(
    super.name, {
    required Database database,
    required this.vault,
    required super.maxFileSize,
    required ({
      Future<String?> Function(String) read,
      Future<void> Function(String, String) write,
      Future<void> Function(String) delete,
    })
    secureStorage,
  }) : super.buildWithoutOpen(database: database, secureStorage: secureStorage);

  @override
  bool get supportsFileStoring => true;

  @override
  Future<void> open() async {
    await super.open();
    await vault.initialize();
  }

  @override
  Future<void> storeFile(Uri mxcUri, Uint8List bytes, int time) =>
      vault.store(mxcUri, bytes, time);

  @override
  Future<Uint8List?> getFile(Uri mxcUri) => vault.get(mxcUri);

  @override
  Future<bool> deleteFile(Uri mxcUri) => vault.delete(mxcUri);

  @override
  Future<void> deleteOldFiles(int savedAt) async {
    try {
      await vault.prune(savedAt);
    } catch (_) {
      // The SDK starts cleanup without awaiting it; avoid unhandled errors.
      Logs().w('Media vault cleanup failed.');
    }
  }

  @override
  Future<void> clear() async {
    await vault.clear();
    await super.clear();
  }
}
