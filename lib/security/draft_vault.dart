// SPDX-FileCopyrightText: 2026 MatrixChat contributors
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uses the account's existing keyed native database. Never opens a new DB.
class DraftVault {
  static const table = 'matrixchat_drafts_v1';
  final Database database;

  DraftVault(this.database);

  Future<void> initialize() => database.execute(
    'CREATE TABLE IF NOT EXISTS $table ('
    'room_id TEXT PRIMARY KEY NOT NULL, content TEXT NOT NULL)',
  );

  Future<String?> read(String roomId) async {
    final rows = await database.query(
      table,
      columns: ['content'],
      where: 'room_id = ?',
      whereArgs: [roomId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['content'] as String;
  }

  Future<void> write(String roomId, String content) async {
    if (content.isEmpty) {
      await database.delete(table, where: 'room_id = ?', whereArgs: [roomId]);
      return;
    }
    await database.insert(table, {
      'room_id': roomId,
      'content': content,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// A delayed send completion must not erase a newer draft.
  Future<void> deleteIfMatches(String roomId, String content) async {
    await database.delete(
      table,
      where: 'room_id = ? AND content = ?',
      whereArgs: [roomId, content],
    );
  }

  Future<void> clear() async {
    await database.delete(table);
  }
}
