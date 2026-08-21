import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/project.dart';

/// Data access for the `projects` table.
class ProjectRepository {
  ProjectRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<List<Project>> getAll({bool includeDeleted = false}) async {
    final db = await _database;
    final results = await db.query(
      'projects',
      where: includeDeleted ? null : 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return results.map((m) => Project.fromMap(m)).toList();
  }

  Future<Project?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('projects', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Project.fromMap(results.first);
  }

  /// Title/description search for the dashboard quick-search
  /// (active projects only, alphabetical).
  Future<List<Project>> search(String query, {int limit = 8}) async {
    final db = await _database;
    final results = await db.query(
      'projects',
      where: 'deleted_at IS NULL AND (title LIKE ? OR description LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'title ASC',
      limit: limit,
    );
    return results.map((m) => Project.fromMap(m)).toList();
  }

  Future<int> insert(Project project) async {
    final db = await _database;
    return db.insert('projects', project.toMap());
  }

  Future<int> update(Project project) async {
    final db = await _database;
    final map =
        project.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    return db.update('projects', map, where: 'id = ?', whereArgs: [project.id]);
  }

  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  /// Soft delete; tasks keep their project_id nulled via FK SET NULL.
  Future<int> trash(int id) async {
    final db = await _database;
    return db.update('projects', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> restore(int id) async {
    final db = await _database;
    return db.update('projects', {'deleted_at': null},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Progress for one project: (completed, total).
  Future<(int, int)> progress(int projectId) async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS total, '
        'SUM(CASE WHEN status = \'Completed\' THEN 1 ELSE 0 END) AS done '
        'FROM tasks WHERE project_id = ? AND deleted_at IS NULL',
        [projectId]);
    final row = r.first;
    return (
      (row['done'] as int?) ?? 0,
      (row['total'] as int?) ?? 0,
    );
  }
}
