import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'migrations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schema.dart';

/// Lazy singleton database handle.
///
/// Database location by build mode:
/// - **Release / installed builds** store `taskflow.db` in a `DB` folder
///   next to the running executable (portable-style data that lives with
///   the app). If that location is not writable (e.g. a Program Files
///   install), it falls back to the per-user application-support
///   directory. On the first writable launch, an existing legacy database
///   from the old application-support location is migrated over.
/// - **Debug builds** use the application-support directory with a
///   distinct `taskflow_dev.db` filename, so dev/test builds can never
///   touch production data.
class AppDatabase {
  AppDatabase._();

  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await _resolveDatabaseDirectory();
    final fileName = kDebugMode ? 'taskflow_dev.db' : 'taskflow.db';
    final dbPath = p.join(dir, fileName);

    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppSchema.version,
        onCreate: Migrations.onCreate,
        onUpgrade: Migrations.onUpgrade,
      ),
    );
  }

  /// Resolves the directory that should hold the database file (see the
  /// class doc for the per-mode rules).
  static Future<String> _resolveDatabaseDirectory() async {
    final supportDir = (await getApplicationSupportDirectory()).path;
    if (kDebugMode) return supportDir;

    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final dbDir = p.join(exeDir, 'DB');
      final dir = Directory(dbDir);
      await dir.create(recursive: true);
      // Prove the location is really writable — an existing read-only
      // folder would pass [create] and fail only later, on first write.
      final probe = File(p.join(dbDir, '.write_probe'));
      await probe.writeAsString('ok');
      await probe.delete();
      await _migrateLegacyDatabase(supportDir, dbDir);
      return dbDir;
    } catch (_) {
      // Install dir not writable (Program Files without elevation) —
      // keep the pre-2.x application-support behavior.
      return supportDir;
    }
  }

  /// One-time migration of a legacy database from the old
  /// application-support location into the new `DB` folder next to the
  /// executable. Copies via a temp file and only when the target does not
  /// exist yet, so a database already living in `DB` is never overwritten.
  static Future<void> _migrateLegacyDatabase(
      String legacyDir, String newDir) async {
    try {
      final legacyFile = File(p.join(legacyDir, 'taskflow.db'));
      final targetFile = File(p.join(newDir, 'taskflow.db'));
      if (!legacyFile.existsSync() || targetFile.existsSync()) return;
      final tmp = File(p.join(newDir, 'taskflow.db.migrating'));
      await legacyFile.copy(tmp.path);
      await tmp.rename(targetFile.path);
      // Carry over any WAL sidecar files so a hot journal is not lost.
      for (final suffix in const ['-wal', '-shm']) {
        final side = File(p.join(legacyDir, 'taskflow.db$suffix'));
        if (side.existsSync()) {
          await side.copy(p.join(newDir, 'taskflow.db$suffix'));
        }
      }
    } catch (_) {
      // Best effort: on failure the app simply starts with an empty
      // database in the new location; the legacy file stays untouched.
    }
  }

  /// Closes the database and clears the cached handle (used by tests).
  @visibleForTesting
  static Future<void> closeForTesting() async {
    await _db?.close();
    _db = null;
  }

  /// Overrides the shared handle (used by widget tests to inject an
  /// in-memory database).
  @visibleForTesting
  static void setDatabaseForTesting(Database db) {
    _db = db;
  }

  /// SharedPreferences flag marking the one-time ghost-data cleanup done.
  static const ghostDataCleanedFlag = 'ghost_data_cleaned';

  /// Dev/test placeholder titles that may have been imported from a legacy
  /// v1 database. Matched exactly (case-insensitive) — never as substring
  /// patterns, so user tasks like "Fix the animation bug" are never touched.
  /// Mirrors V1Importer._skipTitles.
  static const _ghostTaskTitles = {
    'test sample 1',
    'test sample 2',
    'task sample 1',
    'task sample 2',
    'anima',
    'ghost task',
  };

  /// Project titles that should never survive from a legacy v1 database.
  /// Mirrors V1Importer._skipProjectTitles.
  static const _ghostProjectTitles = {
    'website redesign',
  };

  /// Removes dev/test placeholder rows that may have been imported from
  /// a legacy v1 database.
  ///
  /// Runs **at most once per install** (guarded by [ghostDataCleanedFlag])
  /// and matches titles **exactly** (case-insensitive), so legitimate user
  /// data containing those words (e.g. a project called "Website redesign
  /// v2") can never be swept away. The v1 importer also skips these titles
  /// at import time; this is a belt-and-braces pass for databases imported
  /// before that guard existed.
  static Future<void> cleanupGhostData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(ghostDataCleanedFlag) ?? false) return;

    final db = await database;
    final ghostTasks = _ghostTaskTitles.toList();
    final ghostProjects = _ghostProjectTitles.toList();
    final taskPlaceholders = List.filled(ghostTasks.length, '?').join(',');
    final projectPlaceholders =
        List.filled(ghostProjects.length, '?').join(',');

    await db.transaction((txn) async {
      final taskRows = await txn.query('tasks',
          where: 'LOWER(title) IN ($taskPlaceholders)',
          whereArgs: ghostTasks);
      for (final row in taskRows) {
        final id = row['id'] as int;
        await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [id]);
        await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
        await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
      final projectRows = await txn.query('projects',
          where: 'LOWER(title) IN ($projectPlaceholders)',
          whereArgs: ghostProjects);
      for (final row in projectRows) {
        final id = row['id'] as int;
        await txn.delete('project_statuses',
            where: 'project_id = ?', whereArgs: [id]);
        await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
      }
    });

    await prefs.setBool(ghostDataCleanedFlag, true);

    // One-time migration: clear stale user_name so the user can re-enter it.
    // After this runs once, the flag prevents repeated clearing.
    if (!(prefs.getBool('user_name_cleared') ?? false)) {
      await prefs.remove('user_name');
      await prefs.setBool('user_name_cleared', true);
    }
  }

  /// Wipes all user data rows (tasks, subtasks, routines, projects,
  /// focus sessions, tags). Categories are app-level config and survive.
  static Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('subtasks');
      await txn.delete('routines');
      await txn.delete('projects');
      await txn.delete('project_statuses');
      await txn.delete('focus_sessions');
      await txn.delete('task_tags');
      await txn.delete('tags');
    });
  }
}
