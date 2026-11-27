// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:typed_data';

import 'package:fluffychat/security/media_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late MediaVault vault;
  var enabled = false;
  final pending = Uri.parse('cache://file/transaction');
  final remote = Uri.parse('mxc://example.org/media');
  final bytes = Uint8List.fromList([1, 2, 3]);

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    enabled = false;
    vault = MediaVault(database, cacheEnabled: () => enabled);
    await vault.initialize();
  });

  tearDown(() => database.close());

  test('pending uploads remain available when ordinary cache is off', () async {
    await vault.store(pending, bytes, 100);
    await vault.store(remote, bytes, 100);
    expect(await vault.get(pending), bytes);
    expect(await vault.get(remote), isNull);
  });

  test('normal cache requires opt-in on reads and writes', () async {
    enabled = true;
    await vault.store(remote, bytes, 100);
    expect(await vault.get(remote), bytes);
    enabled = false;
    expect(await vault.get(remote), isNull);
    expect(await vault.delete(remote), isTrue);
    enabled = true;
    expect(await vault.get(remote), isNull);
  });

  test('cache key is data, not a filesystem path or SQL fragment', () async {
    final uri = Uri.parse('cache://file/..%2F..%2Fsecret%27');
    await vault.store(uri, bytes, 100);
    expect(await vault.get(uri), bytes);
    expect(await vault.get(pending), isNull);
  });

  test('pruning and explicit clear remove expired or selected entries', () async {
    enabled = true;
    await vault.store(pending, bytes, 10);
    await vault.store(remote, bytes, 20);
    await vault.prune(15);
    expect(await vault.get(pending), isNull);
    expect(await vault.get(remote), bytes);
    await vault.clear();
    expect(await vault.get(remote), isNull);
  });

  test('oversized ordinary media is not cached', () async {
    enabled = true;
    await vault.store(
      remote,
      Uint8List(MediaVault.maxCachedFileBytes + 1),
      100,
    );
    expect(await vault.get(remote), isNull);
  });
}
