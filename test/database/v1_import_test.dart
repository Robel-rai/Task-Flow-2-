import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/v1_importer.dart';
import 'package:taskflow/repositories/subtask_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';

import 'test_helpers.dart';

void main() {
  late Database v2db;
  late Directory tempDir;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    v2db = await createTestDb();
    tempDir = await Directory.systemTemp.createTemp('v1_import_test');
  });

  tearDown(() async {
    await v2db.close();
    await tempDir.delete(recursive: true);
  });

  /// Creates a v1-format database with the same schema v1 used (v4).
  Future<String> createV1Db({
    int tasks = 0,
    int projects = 0,
    int routines = 0,
  }) async {
    final path = '${tempDir.path}${Platform.pathSeparator}task_recorder_pro.db';
    final v1 = await databaseFactoryFfi.openDatabase(path);
    await v1.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        category TEXT DEFAULT 'General',
        priority TEXT DEFAULT 'Medium',
        status TEXT DEFAULT 'Pending',
        scheduled_date TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        time_spent_seconds INTEGER DEFAULT 0,
        timer_started_at TEXT,
        subtasks TEXT DEFAULT '[]',
        project_id INTEGER DEFAULT NULL
      )
    ''');
    await v1.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        scheduled_time TEXT NOT NULL,
        streak INTEGER DEFAULT 0,
        is_completed_today INTEGER DEFAULT 0,
        last_completed_date TEXT
      )
    ''');
    await v1.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        color TEXT DEFAULT 'primary',
        status TEXT DEFAULT 'Pending',
        created_at TEXT NOT NULL
      )
    ''');

    for (var i = 0; i < projects; i++) {
      await v1.insert('projects', {
        'title': 'Project $i',
        'description': 'desc $i',
        'color': 'blue',
        'status': 'Pending',
        'created_at': '2026-08-01T09:00:00.000',
      });
    }
    for (var i = 0; i < tasks; i++) {
      await v1.insert('tasks', {
        'title': 'Task $i',
        'description': 'desc $i',
        'category': i.isEven ? 'General' : 'CustomCat',
        'priority': 'High',
        'status': i == 0 ? 'Completed' : 'Pending',
        'scheduled_date': '2026-08-14T10:30:00.000',
        'created_at': '2026-08-10T09:00:00.000',
        'completed_at': i == 0 ? '2026-08-14T11:00:00.000' : null,
        'time_spent_seconds': 120,
        'subtasks': jsonEncode([
          {'title': 'Sub A', 'isCompleted': true},
          {'title': 'Sub B', 'isCompleted': false},
        ]),
        'project_id': i == 0 ? 1 : null,
      });
    }
    for (var i = 0; i < routines; i++) {
      await v1.insert('routines', {
        'title': 'Routine $i',
        'scheduled_time': '07:30',
        'streak': 3,
        'is_completed_today': 1,
        'last_completed_date': '2026-08-13T07:30:00.000',
      });
    }
    await v1.close();
    return path;
  }

  test('imports projects, tasks, subtasks, routines with mappings', () async {
    final path = await createV1Db(tasks: 2, projects: 1, routines: 2);
    final result = await V1Importer().importFromPath(path, target: v2db);

    expect(result.didImport, isTrue);
    expect(result.tasksImported, 2);
    expect(result.projectsImported, 1);
    expect(result.routinesImported, 2);
    expect(result.subtasksImported, 4); // 2 tasks x 2 subtasks

    // Project id preserved so task.project_id stays valid.
    final taskRepo = TaskRepository(db: v2db);
    final importedTasks = await taskRepo.getAll();
    expect(importedTasks, hasLength(2));

    final first = importedTasks.firstWhere((t) => t.title == 'Task 0');
    expect(first.projectId, 1);
    expect(first.scheduledDate, DateTime(2026, 8, 14));
    expect(first.scheduledTime, '10:30');
    expect(first.status, 'Completed');
    expect(first.timeSpentSeconds, 120);

    // Category strings become category rows.
    final subRepo = SubtaskRepository(db: v2db);
    final subs = await subRepo.getForTask(first.id!);
    expect(subs, hasLength(2));
    expect(subs[0].title, 'Sub A');
    expect(subs[0].isCompleted, isTrue);
    expect(subs[1].sortOrder, 1);

    final custom = await v2db.query('categories', where: 'name = ?',
        whereArgs: ['CustomCat']);
    expect(custom, hasLength(1));

    final routines = await v2db.query('routines');
    expect(routines, hasLength(2));
    expect(routines.first['days_of_week'], '1,2,3,4,5,6,7');
    expect(routines.first['streak'], 3);
  });

  test('returns foundV1Db=false when the source file is missing', () async {
    final result = await V1Importer().importFromPath(
        '${tempDir.path}${Platform.pathSeparator}nope.db',
        target: v2db);
    expect(result.foundV1Db, isFalse);
  });

  test('handles malformed subtask JSON gracefully', () async {
    final path = '${tempDir.path}${Platform.pathSeparator}bad.db';
    final v1 = await databaseFactoryFfi.openDatabase(path);
    await v1.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        category TEXT DEFAULT 'General',
        priority TEXT DEFAULT 'Medium',
        status TEXT DEFAULT 'Pending',
        scheduled_date TEXT,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        time_spent_seconds INTEGER DEFAULT 0,
        timer_started_at TEXT,
        subtasks TEXT DEFAULT '[]',
        project_id INTEGER DEFAULT NULL
      )
    ''');
    await v1.insert('tasks', {
      'title': 'Broken',
      'created_at': '2026-08-10T09:00:00.000',
      'subtasks': '{not json',
    });
    await v1.close();

    final result = await V1Importer().importFromPath(path, target: v2db);
    expect(result.didImport, isTrue);
    expect(result.tasksImported, 1);
    expect(result.subtasksImported, 0);
  });
}
