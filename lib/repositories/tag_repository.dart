import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/tag.dart';

/// Data access for the `tags` and `task_tags` tables.
class TagRepository {
  TagRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<Tag>> getAll() async {
    final db = await _database;
    final results = await db.query('tags', orderBy: 'name ASC');
    return results.map((m) => Tag.fromMap(m)).toList();
  }

  Future<Tag?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('tags', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Tag.fromMap(results.first);
  }

  /// Name-prefix search for the global search bar (case-insensitive).
  Future<List<Tag>> searchByName(String query, {int limit = 6}) async {
    final db = await _database;
    final results = await db.query('tags',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'name ASC',
        limit: limit);
    return results.map((m) => Tag.fromMap(m)).toList();
  }

  /// Deletes a tag and every task-tag link pointing at it in one
  /// transaction. FK cascades are not enforced at runtime, so the
  /// `task_tags` rows are removed explicitly first.
  Future<void> deleteCompletely(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insert(Tag tag) async {
    final db = await _database;
    return db.insert('tags', tag.toMap());
  }

  Future<int> update(Tag tag) async {
    final db = await _database;
    return db.update('tags', tag.toMap(), where: 'id = ?', whereArgs: [tag.id]);
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tag>> getForTask(int taskId) async {
    final db = await _database;
    final results = await db.rawQuery(
        'SELECT t.* FROM tags t INNER JOIN task_tags tt ON tt.tag_id = t.id '
        'WHERE tt.task_id = ? ORDER BY t.name ASC',
        [taskId]);
    return results.map((m) => Tag.fromMap(m)).toList();
  }

  Future<List<int>> getTagIdsForTask(int taskId) async {
    final db = await _database;
    final results = await db.query('task_tags',
        where: 'task_id = ?', whereArgs: [taskId]);
    return results.map((r) => r['tag_id'] as int).toList();
  }

  Future<void> addToTask(int taskId, int tagId) async {
    final db = await _database;
    await db.insert('task_tags', {'task_id': taskId, 'tag_id': tagId});
  }

  Future<void> removeFromTask(int taskId, int tagId) async {
    final db = await _database;
    await db.delete('task_tags',
        where: 'task_id = ? AND tag_id = ?', whereArgs: [taskId, tagId]);
  }

  /// Returns task ids that have [tagId] assigned.
  Future<List<int>> getTaskIdsForTag(int tagId) async {
    final db = await _database;
    final results = await db.query('task_tags',
        columns: ['task_id'],
        where: 'tag_id = ?', whereArgs: [tagId]);
    return results.map((r) => r['task_id'] as int).toList();
  }

  /// Replaces a task's tag set with [tagIds] in one transaction.
  Future<void> setTagsForTask(int taskId, List<int> tagIds) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [taskId]);
      for (final tagId in tagIds) {
        await txn.insert('task_tags', {'task_id': taskId, 'tag_id': tagId});
      }
    });
  }
}
