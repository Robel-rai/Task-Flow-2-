import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/focus_session.dart';

/// Data access for the `focus_sessions` table.
class FocusSessionRepository {
  FocusSessionRepository({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  Future<int> insert(FocusSession session) async {
    final db = await _database;
    return db.insert('focus_sessions', session.toMap());
  }

  Future<int> update(FocusSession session) async {
    final db = await _database;
    return db.update('focus_sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
  }

  /// Deletes every recorded focus session.
  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('focus_sessions');
  }

  Future<FocusSession?> getById(int id) async {
    final db = await _database;
    final results = await db
        .query('focus_sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return FocusSession.fromMap(results.first);
  }

  /// All sessions that started on [date] (local date).
  Future<List<FocusSession>> getForDate(DateTime date) async {
    final db = await _database;
    final day = date.toIso8601String().split('T').first;
    final results = await db.query('focus_sessions',
        where: 'started_at LIKE ?', whereArgs: ['$day%'], orderBy: 'started_at ASC');
    return results.map((m) => FocusSession.fromMap(m)).toList();
  }

  /// Sessions started within the inclusive [start]..[end] local-date range,
  /// or all sessions when either bound is null.
  Future<List<FocusSession>> getForRange(DateTime? start, DateTime? end) async {
    final db = await _database;
    if (start == null || end == null) {
      final results = await db.query('focus_sessions', orderBy: 'started_at ASC');
      return results.map((m) => FocusSession.fromMap(m)).toList();
    }
    final results = await db.query(
      'focus_sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [_dayPrefix(start), _dayPrefix(end.add(const Duration(days: 1)))],
      orderBy: 'started_at ASC',
    );
    return results.map((m) => FocusSession.fromMap(m)).toList();
  }

  Future<List<FocusSession>> getForTask(int taskId) async {
    final db = await _database;
    final results = await db.query('focus_sessions',
        where: 'task_id = ?', whereArgs: [taskId], orderBy: 'started_at ASC');
    return results.map((m) => FocusSession.fromMap(m)).toList();
  }

  /// Total focus seconds for all sessions (optionally on a single day).
  Future<int> totalSeconds({DateTime? date}) async {
    final db = await _database;
    if (date != null) {
      final day = date.toIso8601String().split('T').first;
      final r = await db.rawQuery(
          'SELECT COALESCE(SUM(duration_seconds), 0) AS total '
          'FROM focus_sessions WHERE started_at LIKE ?',
          ['$day%']);
      return (r.first['total'] as int?) ?? 0;
    }
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(duration_seconds), 0) AS total FROM focus_sessions');
    return (r.first['total'] as int?) ?? 0;
  }

  /// Total focus seconds for sessions within the inclusive [start]..[end]
  /// local-date range, or for all sessions when either bound is null.
  Future<int> totalSecondsForRange(DateTime? start, DateTime? end) async {
    final db = await _database;
    if (start == null || end == null) {
      final r = await db.rawQuery(
          'SELECT COALESCE(SUM(duration_seconds), 0) AS total FROM focus_sessions');
      return (r.first['total'] as int?) ?? 0;
    }
    final r = await db.rawQuery(
        'SELECT COALESCE(SUM(duration_seconds), 0) AS total '
        'FROM focus_sessions WHERE started_at >= ? AND started_at < ?',
        [_dayPrefix(start), _dayPrefix(end.add(const Duration(days: 1)))]);
    return (r.first['total'] as int?) ?? 0;
  }

  /// Total focus seconds per calendar day within [start]..[end]
  /// (inclusive), keyed by `yyyy-MM-dd`.
  Future<Map<String, int>> focusSecondsPerDay(
      DateTime start, DateTime end) async {
    final db = await _database;
    final rows = await db.rawQuery(
        'SELECT substr(started_at, 1, 10) AS day, '
        'COALESCE(SUM(duration_seconds), 0) AS total '
        'FROM focus_sessions WHERE started_at >= ? AND started_at < ? '
        'GROUP BY day',
        [_dayPrefix(start), _dayPrefix(end.add(const Duration(days: 1)))]);
    return {
      for (final r in rows) r['day'] as String: (r['total'] as int?) ?? 0,
    };
  }

  static String _dayPrefix(DateTime d) =>
      d.toIso8601String().split('T').first;
}
