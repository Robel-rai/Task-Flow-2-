import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_database.dart';

/// Result of a v1 import attempt.
class V1ImportResult {
  const V1ImportResult({
    required this.foundV1Db,
    this.projectsImported = 0,
    this.tasksImported = 0,
    this.subtasksImported = 0,
    this.routinesImported = 0,
    this.categoriesCreated = 0,
    this.sourcePath,
    this.error,
  });

  final bool foundV1Db;
  final int projectsImported;
  final int tasksImported;
  final int subtasksImported;
  final int routinesImported;
  final int categoriesCreated;
  final String? sourcePath;
  final String? error;

  bool get didImport => foundV1Db && error == null;
}

/// One-time importer from the v1 `task_recorder_pro.db` into `taskflow.db`.
///
/// The legacy file is opened read-only and never modified. Runs at most
/// once per install (guarded by a SharedPreferences flag).
class V1Importer {
  V1Importer({SharedPreferences? prefs}) : _prefs = prefs;

  static const importFlagKey = 'v1_data_imported';

  final SharedPreferences? _prefs;

  /// Locates the legacy database, imports it, and marks the migration done.
  /// Safe to call every launch — the flag prevents double import.
  Future<V1ImportResult> run() async {
    final path = await _locateLegacyDb();
    if (path == null) {
      // No legacy data; still mark as handled so we don't re-check each launch.
      await _markImported();
      return const V1ImportResult(foundV1Db: false);
    }
    final result = await importFromPath(path);
    if (result.error == null) {
      await _markImported();
    }
    return result;
  }

  /// Core import logic, testable against an explicit source path and
  /// target database.
  @visibleForTesting
  Future<V1ImportResult> importFromPath(
    String v1DbPath, {
    Database? target,
  }) async {
    final sourceFile = File(v1DbPath);
    if (!await sourceFile.exists()) {
      return V1ImportResult(foundV1Db: false);
    }

    final targetDb = target ?? await AppDatabase.database;
    late Database v1;
    try {
      v1 = await databaseFactoryFfi.openDatabase(
        v1DbPath,
        options: OpenDatabaseOptions(readOnly: true),
      );
    } catch (e) {
      return V1ImportResult(foundV1Db: true, error: e.toString());
    }

    try {
      final tables = await v1
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final names = tables.map((r) => r['name']).toSet();
      if (!names.contains('tasks')) {
        return const V1ImportResult(foundV1Db: true, error: 'no tasks table');
      }

      var projects = 0, tasks = 0, subtasks = 0, routines = 0, cats = 0;

      await targetDb.transaction((txn) async {
        final categoryIds = <String, int>{};
        final now = DateTime.now().toIso8601String();

        // Ensure the default General category exists.
        final generalRows = await txn.query('categories',
            where: 'name = ?', whereArgs: ['General'], limit: 1);
        if (generalRows.isEmpty) {
          categoryIds['General'] = await txn.insert('categories', {
            'name': 'General',
            'color': 'primary',
            'sort_order': 0,
            'created_at': now,
          });
        } else {
          categoryIds['General'] = generalRows.first['id'] as int;
        }

        // Projects (ids preserved so task.project_id stays valid).
        // Guard each table — a partial v1 DB may lack some of them.
        final projectRows =
            names.contains('projects') ? await v1.query('projects') : [];
        for (final row in projectRows) {
          await txn.insert('projects', {
            'id': row['id'],
            'title': row['title'],
            'description': row['description'] ?? '',
            'color': row['color'] ?? 'primary',
            'status': row['status'] ?? 'Pending',
            'created_at': row['created_at'] ?? now,
          });
          projects++;
        }

        // Tasks.
        final taskRows = await v1.query('tasks');
        for (final row in taskRows) {
          final categoryName = (row['category'] as String?) ?? 'General';
          var categoryId = categoryIds[categoryName];
          if (categoryId == null) {
            categoryId = await txn.insert('categories', {
              'name': categoryName,
              'color': 'primary',
              'sort_order': 0,
              'created_at': now,
            });
            categoryIds[categoryName] = categoryId;
            cats++;
          }

          // v1 stored scheduled_date as a full ISO string; v2 splits it.
          String? datePart;
          String? timePart;
          final sched = row['scheduled_date'];
          if (sched != null) {
            final iso = sched.toString();
            final parts = iso.split('T');
            datePart = parts[0];
            if (parts.length > 1 && parts[1].length >= 5) {
              timePart = parts[1].substring(0, 5);
            }
          }

          final taskId = await txn.insert('tasks', {
            'id': row['id'],
            'title': row['title'],
            'description': row['description'] ?? '',
            'category_id': categoryId,
            'project_id': row['project_id'],
            'priority': row['priority'] ?? 'Medium',
            'status': row['status'] ?? 'Pending',
            'scheduled_date': datePart,
            'scheduled_time': timePart,
            'created_at': row['created_at'] ?? now,
            'completed_at': row['completed_at'],
            'time_spent_seconds': row['time_spent_seconds'] ?? 0,
            'timer_started_at': row['timer_started_at'],
            'sort_order': 0,
          });
          tasks++;

          // v1 stored subtasks as a JSON blob; v2 normalizes them.
          final subtaskList = _parseSubtasksJson(row['subtasks']);
          for (var i = 0; i < subtaskList.length; i++) {
            final s = subtaskList[i];
            await txn.insert('subtasks', {
              'task_id': taskId,
              'title': s['title'] ?? '',
              'is_completed': (s['isCompleted'] == true) ? 1 : 0,
              'sort_order': i,
              'created_at': now,
            });
            subtasks++;
          }
        }

        // Routines (v1 was always daily).
        final routineRows =
            names.contains('routines') ? await v1.query('routines') : [];
        for (final row in routineRows) {
          await txn.insert('routines', {
            'id': row['id'],
            'title': row['title'],
            'scheduled_time': row['scheduled_time'] ?? '08:00',
            'days_of_week': '1,2,3,4,5,6,7',
            'color': 'primary',
            'streak': row['streak'] ?? 0,
            'is_completed_today': row['is_completed_today'] ?? 0,
            'last_completed_date': row['last_completed_date'],
            'notification_enabled': 1,
            'created_at': now,
          });
          routines++;
        }
      });

      return V1ImportResult(
        foundV1Db: true,
        projectsImported: projects,
        tasksImported: tasks,
        subtasksImported: subtasks,
        routinesImported: routines,
        categoriesCreated: cats,
        sourcePath: v1DbPath,
      );
    } catch (e) {
      return V1ImportResult(foundV1Db: true, error: e.toString());
    } finally {
      await v1.close();
    }
  }

  Future<void> _markImported() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(importFlagKey, true);
  }

  static List<Map<String, dynamic>> _parseSubtasksJson(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Candidate legacy DB locations, checked in order:
  /// Documents (v1 debug) and next to the exe (v1 release).
  Future<String?> _locateLegacyDb() async {
    final candidates = <String>[];
    try {
      final docs = await getApplicationDocumentsDirectory();
      candidates.add(p.join(docs.path, 'task_recorder_pro.db'));
    } catch (_) {}
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      candidates.add(p.join(exeDir, 'data', 'task_recorder_pro.db'));
    } catch (_) {}
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }
}
