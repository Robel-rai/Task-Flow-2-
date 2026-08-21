import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'migrations.dart';
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
