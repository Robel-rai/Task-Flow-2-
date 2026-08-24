import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'migrations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schema.dart';

/// Lazy singleton database handle.
///
/// The database lives in the application support directory in BOTH debug
/// and release modes. Unlike v1 (which wrote next to the executable), this
/// works under MSIX and Program Files installs where the install folder
/// is read-only.
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

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'taskflow.db');

    return databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppSchema.version,
        onCreate: Migrations.onCreate,
        onUpgrade: Migrations.onUpgrade,
      ),
    );
  }

  /// Closes the database and clears the cached handle.
  /// Used by restore to reinitialize after replacing the DB file.
  static Future<void> resetHandle() async {
    await _db?.close();
    _db = null;
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

  /// Removes known ghost/test data that may have been imported from
  /// a legacy database. Runs once on startup.
  /// Uses LIKE with LOWER() for case-insensitive matching.
  static Future<void> cleanupGhostData() async {
    final db = await database;
    const ghostTaskPatterns = ['%test sample%', '%task sample%', '%anima%', '%ghost task%'];
    const ghostProjectPatterns = ['%website redesign%'];
    await db.transaction((txn) async {
      for (final pattern in ghostTaskPatterns) {
        final rows = await txn.query('tasks',
            where: 'LOWER(title) LIKE ?', whereArgs: [pattern]);
        for (final row in rows) {
          final id = row['id'] as int;
          await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [id]);
          await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
          await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
        }
      }
      for (final pattern in ghostProjectPatterns) {
        final rows = await txn.query('projects',
            where: 'LOWER(title) LIKE ?', whereArgs: [pattern]);
        for (final row in rows) {
          final id = row['id'] as int;
          await txn.delete('project_statuses', where: 'project_id = ?', whereArgs: [id]);
          await txn.delete('projects', where: 'id = ?', whereArgs: [id]);
        }
      }
    });

    // Clear user_name from SharedPreferences so the app re-enters onboarding.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
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
