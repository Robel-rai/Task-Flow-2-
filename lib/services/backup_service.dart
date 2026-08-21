import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../database/schema.dart';

/// Full-database JSON backup/restore.
///
/// Export writes every table (except internal SQLite bookkeeping) to a single
/// JSON object keyed by table name, plus metadata (`schemaVersion`, `exportedAt`).
///
/// Import reads that JSON and replays every row inside a single database
/// transaction, optionally **merging** (skip rows whose PK already exists)
/// or **replacing** (delete everything first).
class BackupService {
  BackupService({Database? db}) : _db = db;

  final Database? _db;

  Future<Database> get _database async => _db ?? await AppDatabase.database;

  // ─── Export ───

  /// Returns a JSON-encoded string of the entire database.
  Future<String> exportJson() async {
    final db = await _database;
    final tables = [
      'categories',
      'tags',
      'projects',
      'tasks',
      'subtasks',
      'project_statuses',
      'routines',
      'focus_sessions',
      'task_tags',
    ];

    final data = <String, dynamic>{
      'schemaVersion': AppSchema.version,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final table in tables) {
      data[table] = await db.query(table);
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // ─── Import ───

  /// Imports data from a JSON string.
  ///
  /// When [merge] is true, existing rows (matched by primary key) are kept
  /// and only new rows are inserted. When false, all target tables are
  /// cleared first (full replace).
  ///
  /// Returns a map of `{tableName: rowsImported}`.
  Future<Map<String, int>> importJson(
    String json, {
    bool merge = false,
  }) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }

    final db = await _database;
    final counts = <String, int>{};

    // Table order matters for FK constraints.
    const tableOrder = [
      'categories',
      'tags',
      'projects',
      'tasks',
      'subtasks',
      'project_statuses',
      'routines',
      'focus_sessions',
      'task_tags',
    ];

    await db.transaction((txn) async {
      if (!merge) {
        // Delete in reverse FK order.
        for (final table in tableOrder.reversed) {
          await txn.delete(table);
        }
      }

      for (final table in tableOrder) {
        final rows = data[table];
        if (rows is! List) continue;
        var count = 0;
        for (final row in rows) {
          if (row is! Map) continue;
          final map = Map<String, dynamic>.from(row);

          if (merge) {
            // Attempt insert; skip if PK conflict.
            try {
              await txn.insert(table, map);
              count++;
            } on DatabaseException {
              // Row already exists — skip (merge mode).
            }
          } else {
            await txn.insert(table, map);
            count++;
          }
        }
        counts[table] = count;
      }
    });

    return counts;
  }

  /// Preview: returns `{tableName: rowCount}` without modifying anything.
  Future<Map<String, int>> preview(String json) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }

    final counts = <String, int>{};
    for (final entry in data.entries) {
      if (entry.value is List) {
        counts[entry.key] = (entry.value as List).length;
      }
    }
    return counts;
  }
}
