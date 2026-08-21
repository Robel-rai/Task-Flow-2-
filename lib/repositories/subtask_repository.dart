import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/subtask.dart';

/// Data access for the `subtasks` table.
class SubtaskRepository {
  SubtaskRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<Subtask>> getForTask(int taskId) async {
    final db = await _database;
    final results = await db.query('subtasks',
        where: 'task_id = ?',
        whereArgs: [taskId],
        orderBy: 'sort_order ASC, id ASC');
    return results.map((m) => Subtask.fromMap(m)).toList();
  }

  /// All subtasks belonging to [taskIds], grouped by task id (one query,
  /// no N+1 — used by the CSV exporter).
  Future<Map<int, List<Subtask>>> getForTasks(List<int> taskIds) async {
    if (taskIds.isEmpty) return {};
    final db = await _database;
    final placeholders = List.filled(taskIds.length, '?').join(',');
    final results = await db.query(
      'subtasks',
      where: 'task_id IN ($placeholders)',
      whereArgs: taskIds,
      orderBy: 'task_id ASC, sort_order ASC, id ASC',
    );
    final grouped = <int, List<Subtask>>{};
    for (final map in results) {
      final subtask = Subtask.fromMap(map);
      grouped.putIfAbsent(subtask.taskId!, () => []).add(subtask);
    }
    return grouped;
  }

  Future<Subtask?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('subtasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Subtask.fromMap(results.first);
  }

  Future<int> insert(Subtask subtask) async {
    final db = await _database;
    return db.insert('subtasks', subtask.toMap());
  }

  Future<int> update(Subtask subtask) async {
    final db = await _database;
    return db.update('subtasks', subtask.toMap(),
        where: 'id = ?', whereArgs: [subtask.id]);
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('subtasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes all subtasks of a task (used when reconciling a task's list).
  Future<int> deleteForTask(int taskId) async {
    final db = await _database;
    return db.delete('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
  }

  Future<bool> allCompleted(int taskId) async {
    final subtasks = await getForTask(taskId);
    return subtasks.isNotEmpty && subtasks.every((s) => s.isCompleted);
  }
}
