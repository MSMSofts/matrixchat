// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/security/draft_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late DraftVault drafts;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    drafts = DraftVault(database);
    await drafts.initialize();
  });

  tearDown(() => database.close());

  test('drafts are isolated by room and round-trip Unicode', () async {
    await drafts.write('room1', 'پیام خصوصی');
    expect(await drafts.read('room1'), 'پیام خصوصی');
    expect(await drafts.read('room2'), isNull);
  });

  test('a stale send completion cannot delete changed draft text', () async {
    await drafts.write('room', 'first');
    await drafts.write('room', 'second');
    await drafts.deleteIfMatches('room', 'first');
    expect(await drafts.read('room'), 'second');
    await drafts.deleteIfMatches('room', 'second');
    expect(await drafts.read('room'), isNull);
  });

  test('empty drafts and account clear remove stored text', () async {
    await drafts.write('room1', 'secret');
    await drafts.write('room2', 'other');
    await drafts.write('room1', '');
    expect(await drafts.read('room1'), isNull);
    await drafts.clear();
    expect(await drafts.read('room2'), isNull);
  });
}
