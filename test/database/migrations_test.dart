import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/migrations.dart';
import 'package:taskflow/database/schema.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('migration_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('upgrading a v1 database adds the project_statuses table', () async {
    final path = '${tempDir.path}${Platform.pathSeparator}test.db';

    // Create a database at version 1 (pre-project_statuses).
    final v1 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE projects (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'Pending'
              )
            ''');
            await db.execute('''
              CREATE TABLE routines (
                id                    INTEGER PRIMARY KEY AUTOINCREMENT,
                title                 TEXT NOT NULL,
                scheduled_time        TEXT NOT NULL,
                days_of_week          TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
                color                 TEXT NOT NULL DEFAULT 'primary',
                streak                INTEGER NOT NULL DEFAULT 0,
                is_completed_today    INTEGER NOT NULL DEFAULT 0,
                last_completed_date   TEXT,
                notification_enabled  INTEGER NOT NULL DEFAULT 1,
                created_at            TEXT NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE focus_sessions (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                task_id          INTEGER,
                started_at       TEXT NOT NULL,
                ended_at         TEXT,
                duration_seconds INTEGER NOT NULL DEFAULT 0,
                session_type     TEXT NOT NULL DEFAULT 'pomodoro',
                created_at       TEXT NOT NULL
              )
            ''');
          },
        ));
    await v1.insert('projects', {'title': 'Existing project'});
    await v1.close();

    // Reopen at the current version — the upgrade path must run.
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: AppSchema.version,
          onUpgrade: Migrations.onUpgrade,
        ));

    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'project_statuses'");
    expect(tables, hasLength(1));

    // v3 added the routines.description column.
    final routineCols =
        await db.rawQuery('PRAGMA table_info(routines)');
    expect(
      routineCols.map((c) => c['name']),
      contains('description'),
    );

    // v4 added the focus_sessions.paused_at column.
    final focusCols =
        await db.rawQuery('PRAGMA table_info(focus_sessions)');
    expect(
      focusCols.map((c) => c['name']),
      contains('paused_at'),
    );

    // The v1 data survives and the new table is usable.
    final projects = await db.query('projects');
    expect(projects, hasLength(1));
    await db.insert('project_statuses', {
      'project_id': 1,
      'name': 'Blocked',
      'color': 'rose',
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    final rows = await db.query('project_statuses');
    expect(rows.single['name'], 'Blocked');

    await db.close();
  });
}
