// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fluffychat/security/draft_vault.dart';
import 'package:fluffychat/security/media_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('native SQLCipher protects vault data and rejects wrong keys', () async {
    final directory = await Directory.systemTemp.createTemp(
      'matrixchat-vault-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'vault.sqlite');
    final factory = createDatabaseFactoryFfi();
    const key = 'matrixchat-test-key-not-a-secret';
    const sentinel = 'matrixchat-private-draft-sentinel-29438';
    final mediaUri = Uri.parse('cache://file/test');

    Future<Database> open(String password) => factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 1,
        onConfigure: (db) async {
          final version = await db.rawQuery('PRAGMA cipher_version');
          expect(version, isNotEmpty, reason: 'SQLCipher must be available');
          final helper = SQfLiteEncryptionHelper(
            factory: factory,
            path: path,
            cipher: password,
          );
          await helper.applyPragmaKey(db, ensureIncrementalAutoVacuum: true);
          await db.rawQuery('SELECT count(*) FROM sqlite_master');
        },
      ),
    );

    var database = await open(key);
    try {
      final drafts = DraftVault(database);
      await drafts.initialize();
      await drafts.write('room', sentinel);
      final media = MediaVault(database, cacheEnabled: () => false);
      await media.initialize();
      await media.store(mediaUri, Uint8List.fromList(utf8.encode(sentinel)), 1);
    } finally {
      await database.close();
    }

    final original = await File(path).readAsBytes();
    expect(latin1.decode(original), isNot(contains(sentinel)));
    expect(
      latin1.decode(original.take(16).toList()),
      isNot('SQLite format 3\u0000'),
    );

    await expectLater(open('wrong-test-key'), throwsA(anything));
    expect(await File(path).exists(), isTrue);
    expect(await File(path).readAsBytes(), original);

    database = await open(key);
    try {
      expect(await DraftVault(database).read('room'), sentinel);
      final media = MediaVault(database, cacheEnabled: () => false);
      expect(utf8.decode((await media.get(mediaUri))!), sentinel);
    } finally {
      await database.close();
    }
  });
}
