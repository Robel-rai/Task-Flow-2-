import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/task.dart';

/// Data access for the `tasks` table.
///
/// Every repository accepts an optional [Database] so tests can inject an
/// in-memory database; production code uses the shared [AppDatabase] handle.
class TaskRepository {
  TaskRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  static const _sortableColumns = {
    'title',
    'priority',
    'status',
    'created_at',
    'scheduled_date',
    'due_date',
    'sort_order',
  };

  /// Fetch tasks with optional stacked filters.
  ///
  /// [includeUnscheduled] also returns tasks with no scheduled date.
  Future<List<Task>> getAll({
    String? searchQuery,
    int? categoryId,
    int? projectId,
    String? statusFilter,
    String? priorityFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool includeUnscheduled = false,
    String? sortBy,
    bool ascending = true,
    bool includeDeleted = false,
    int? limit,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object?>[];

    if (!includeDeleted) {
      where.add('deleted_at IS NULL');
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(title LIKE ? OR description LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (projectId != null) {
      where.add('project_id = ?');
      args.add(projectId);
    }
    if (statusFilter != null && statusFilter.isNotEmpty) {
      where.add('status = ?');
      args.add(statusFilter);
    }
    if (priorityFilter != null && priorityFilter.isNotEmpty) {
      where.add('priority = ?');
      args.add(priorityFilter);
    }
    if (startDate != null && endDate != null) {
      if (includeUnscheduled) {
        where.add('(scheduled_date IS NULL OR '
            '(scheduled_date >= ? AND scheduled_date <= ?))');
      } else {
        where.add('scheduled_date >= ? AND scheduled_date <= ?');
      }
      args.add(_dateString(startDate));
      args.add(_dateString(endDate));
    } else if (startDate != null) {
      where.add('scheduled_date = ?');
      args.add(_dateString(startDate));
    } else if (endDate != null) {
      where.add('scheduled_date <= ?');
      args.add(_dateString(endDate));
    }

    String? orderBy;
    if (sortBy != null && _sortableColumns.contains(sortBy)) {
      final dir = ascending ? 'ASC' : 'DESC';
      // Priority sorts by logical order (High > Medium > Low), not alphabet.
      if (sortBy == 'priority') {
        orderBy =
            "CASE priority WHEN 'High' THEN 1 WHEN 'Medium' THEN 2 ELSE 3 END $dir";
      } else {
        orderBy = '$sortBy $dir';
      }
    } else {
      orderBy = 'created_at DESC';
    }

    final results = await db.query(
      'tasks',
      where: where.isNotEmpty ? where.join(' AND ') : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: orderBy,
      limit: limit,
    );
    return results.map((m) => Task.fromMap(m)).toList();
  }

  Future<Task?> getById(int id) async {
    final db = await _database;
    final results =
        await db.query('tasks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Task.fromMap(results.first);
  }

  /// Title/description search for the dashboard quick-search
  /// (active tasks only, newest first).
  Future<List<Task>> search(String query, {int limit = 8}) {
    return getAll(searchQuery: query, limit: limit);
  }

  Future<int> insert(Task task) async {
    final db = await _database;
    return db.insert('tasks', task.toMap());
  }

  Future<int> update(Task task) async {
    final db = await _database;
    final map = task.toMap()..['updated_at'] = DateTime.now().toIso8601String();
    return db.update('tasks', map, where: 'id = ?', whereArgs: [task.id]);
  }

  /// Permanent deletion (used by trash "delete forever").
  Future<int> delete(int id) async {
    final db = await _database;
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Soft delete: sets deleted_at so the task moves to the trash.
  Future<int> trash(int id) async {
    final db = await _database;
    return db.update('tasks', {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> restore(int id) async {
    final db = await _database;
    return db.update('tasks', {'deleted_at': null},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Returns all soft-deleted (trashed) tasks, newest first.
  Future<List<Task>> getTrashed() async {
    return getAll(includeDeleted: true, sortBy: 'created_at', ascending: false);
  }

  /// Permanently deletes every trashed task in one transaction.
  Future<void> emptyTrash() async {
    final db = await _database;
    await db.delete('tasks', where: 'deleted_at IS NOT NULL');
  }

  Future<List<Task>> getForDate(DateTime date) async {
    return getAll(
      startDate: date,
      endDate: date,
      sortBy: 'sort_order',
    );
  }

  Future<List<Task>> getInRange(DateTime start, DateTime end) async {
    return getAll(startDate: start, endDate: end);
  }

  Future<List<Task>> getForProject(int projectId) async {
    return getAll(projectId: projectId);
  }

  /// Update sort order for a batch of task ids (day-view reordering).
  Future<void> updateSortOrder(List<int> orderedIds) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('tasks', {'sort_order': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }

  // ─── Analytics queries (batched, no N+1) ───

  Future<int> countAll() async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM tasks WHERE deleted_at IS NULL');
    return (r.first['cnt'] as int?) ?? 0;
  }

  Future<int> countByStatus(String status) async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM tasks WHERE deleted_at IS NULL AND status = ?',
        [status]);
    return (r.first['cnt'] as int?) ?? 0;
  }

  Future<int> countCompletedOn(DateTime date) async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM tasks WHERE deleted_at IS NULL '
        'AND status = \'Completed\' AND completed_at LIKE ?',
        ['${_dateString(date)}%']);
    return (r.first['cnt'] as int?) ?? 0;
  }

  Future<int> totalTimeSpentSeconds() async {
    final db = await _database;
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(time_spent_seconds), 0) AS total '
        'FROM tasks WHERE deleted_at IS NULL');
    return (r.first['total'] as int?) ?? 0;
  }

  /// Category -> task count, ordered by count descending.
  Future<Map<String, int>> categoryDistribution() async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT c.name AS category, COUNT(t.id) AS cnt '
        'FROM tasks t LEFT JOIN categories c ON c.id = t.category_id '
        'WHERE t.deleted_at IS NULL '
        'GROUP BY c.name ORDER BY cnt DESC');
    final map = <String, int>{};
    for (final row in rows) {
      map[row['category'] as String? ?? 'General'] = (row['cnt'] as int?) ?? 0;
    }
    return map;
  }

  /// Completed-task counts for the 7 days ending [end] (inclusive),
  /// indexed 0=end-6 … 6=end. Single grouped query, no N+1.
  Future<Map<int, int>> completionCountsForWeek(DateTime end) async {
    final start = end.subtract(const Duration(days: 6));
    final byDay = await completionCountsForRange(start, end);
    final counts = <int, int>{};
    for (var i = 0; i < 7; i++) {
      counts[i] = byDay[_dateString(start.add(Duration(days: i)))] ?? 0;
    }
    return counts;
  }

  /// Completed-task counts per day for [start]..[end] (inclusive),
  /// keyed by `yyyy-MM-dd`. Single grouped query, no N+1.
  Future<Map<String, int>> completionCountsForRange(
      DateTime start, DateTime end) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT substr(completed_at, 1, 10) AS day, COUNT(*) AS cnt '
        'FROM tasks '
        'WHERE deleted_at IS NULL AND status = \'Completed\' '
        'AND completed_at >= ? AND completed_at < ? '
        'GROUP BY day',
        ['${_dateString(start)}T00:00:00', '${_dateString(end)}T23:59:59']);
    final byDay = <String, int>{};
    for (final row in rows) {
      byDay[row['day'] as String] = (row['cnt'] as int?) ?? 0;
    }
    return byDay;
  }

  /// Distinct calendar dates with at least one completed task, oldest first.
  Future<List<DateTime>> completedDates() async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT DISTINCT substr(completed_at, 1, 10) AS day '
        'FROM tasks WHERE deleted_at IS NULL AND status = \'Completed\' '
        'AND completed_at IS NOT NULL ORDER BY day ASC');
    return rows.map((r) => DateTime.parse(r['day'] as String)).toList();
  }

  /// Per-category (name, total tasks, completed tasks), largest first.
  Future<List<(String, int, int)>> categoryPerformance() async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT c.name AS category, COUNT(t.id) AS total, '
        'SUM(CASE WHEN t.status = \'Completed\' THEN 1 ELSE 0 END) AS done '
        'FROM tasks t LEFT JOIN categories c ON c.id = t.category_id '
        'WHERE t.deleted_at IS NULL '
        'GROUP BY c.name ORDER BY total DESC');
    return rows
        .map((r) => (
              r['category'] as String? ?? 'General',
              (r['total'] as int?) ?? 0,
              (r['done'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Count tasks whose due date is before today and are not completed.
  Future<int> countOverdue({DateTime? now}) async {
    final db = await _database;
    final today = _dateString(now ?? DateTime.now());
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM tasks '
        'WHERE deleted_at IS NULL AND status != \'Completed\' '
        'AND due_date IS NOT NULL AND due_date < ?',
        ['${today}T23:59:59']);
    return (r.first['cnt'] as int?) ?? 0;
  }

  /// Count tasks due within the next [days] days (inclusive of today).
  Future<int> countDueThisWeek({int days = 7, DateTime? now}) async {
    final db = await _database;
    final n = now ?? DateTime.now();
    final today = _dateString(n);
    final end = _dateString(n.add(Duration(days: days - 1)));
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM tasks '
        'WHERE deleted_at IS NULL AND status != \'Completed\' '
        'AND due_date IS NOT NULL '
        'AND due_date >= ? AND due_date <= ?',
        ['${today}T00:00:00', '${end}T23:59:59']);
    return (r.first['cnt'] as int?) ?? 0;
  }

  /// The single task with the most time spent (non-deleted).
  Future<Task?> mostTimeConsumingTask() async {
    final db = await _database;
    final rows = await db.query(
      'tasks',
      where: 'deleted_at IS NULL AND time_spent_seconds > 0',
      orderBy: 'time_spent_seconds DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  static String _dateString(DateTime d) =>
      d.toIso8601String().split('T').first;
}
