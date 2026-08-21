import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/project_status.dart';

/// Data access for the `project_statuses` table (custom kanban columns).
class ProjectStatusRepository {
  ProjectStatusRepository({Database? db}) : _db = db;

  /// Maximum allowed length for a status name.
  static const int maxNameLength = 24;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<ProjectStatus>> getForProject(int projectId) async {
    final db = await _database;
    final results = await db.query('project_statuses',
        where: 'project_id = ?',
        whereArgs: [projectId],
        orderBy: 'sort_order ASC, id ASC');
    return results.map((m) => ProjectStatus.fromMap(m)).toList();
  }

  Future<ProjectStatus?> getById(int id) async {
    final db = await _database;
    final results = await db.query('project_statuses',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return ProjectStatus.fromMap(results.first);
  }

  Future<int> insert(ProjectStatus status) async {
    _validate(status);
    final db = await _database;
    return db.insert('project_statuses', status.toMap());
  }

  Future<int> update(ProjectStatus status) async {
    _validate(status);
    final db = await _database;
    return db.update('project_statuses', status.toMap(),
        where: 'id = ?', whereArgs: [status.id]);
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('project_statuses', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes every custom status of a project (used by "reset to defaults"
  /// and when replacing the whole column list).
  Future<void> deleteForProject(int projectId) async {
    final db = await _database;
    await db
        .delete('project_statuses', where: 'project_id = ?', whereArgs: [projectId]);
  }

  /// Defensive guard so the DB never holds an over-long or empty name,
  /// regardless of the caller. UI-level checks live in the editor dialog.
  void _validate(ProjectStatus status) {
    final name = status.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Status name must not be empty');
    }
    if (name.length > maxNameLength) {
      throw ArgumentError(
          'Status name must be $maxNameLength characters or fewer');
    }
  }
}
