import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';

import 'test_helpers.dart';

void main() {
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await createTestDb();
    AppDatabase.setDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
    AppDatabase.closeForTesting();
  });

  Future<int> insertTask(String title) async {
    return db.insert('tasks', {
      'title': title,
      'priority': 'Medium',
      'status': 'Pending',
      'time_spent_seconds': 0,
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertProject(String title) async {
    return db.insert('projects', {
      'title': title,
      'description': '',
      'color': 'primary',
      'status': 'Pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> taskCount() async =>
      (await db.rawQuery('SELECT COUNT(*) AS c FROM tasks')).first['c'] as int;
  Future<int> projectCount() async =>
      (await db.rawQuery('SELECT COUNT(*) AS c FROM projects')).first['c']
          as int;

  test('deletes exact ghost task and project titles on first run', () async {
    await insertTask('ghost task');
    await insertTask('Test Sample 1'); // case-insensitive
    await insertProject('website redesign');

    await AppDatabase.cleanupGhostData();

    expect(await taskCount(), 0);
    expect(await projectCount(), 0);
  });

  test('never touches legitimate titles that merely contain the words',
      () async {
    await insertTask('Fix the animation bug');
    await insertTask('my test sample for the API');
    await insertTask('ghost taskbuster'); // substring, not exact
    await insertProject('Website redesign v2');
    await insertProject('Redesign the website');

    await AppDatabase.cleanupGhostData();

    expect(await taskCount(), 3);
    expect(await projectCount(), 2);
  });

  test('runs at most once — the flag prevents repeat sweeps', () async {
    // First run: a ghost task exists and is removed.
    await insertTask('ghost task');
    await AppDatabase.cleanupGhostData();
    expect(await taskCount(), 0);

    // Flag is now set.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppDatabase.ghostDataCleanedFlag), isTrue);

    // After the first run a "ghost-looking" task appears again (e.g. the
    // user really created one). The second run must NOT delete it.
    final id = await insertTask('ghost task');
    await AppDatabase.cleanupGhostData();
    final row = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    expect(row, hasLength(1));
  });

  test('subtasks and task_tags of ghost tasks are cleaned up too', () async {
    final taskId = await insertTask('task sample 2');
    await db.insert('subtasks', {
      'task_id': taskId,
      'title': 'sub',
      'is_completed': 0,
      'sort_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('tags', {'name': 't', 'color': 'primary'});
    final tag = await db.query('tags', limit: 1);
    await db.insert('task_tags', {'task_id': taskId, 'tag_id': tag.first['id']});

    await AppDatabase.cleanupGhostData();

    expect(
        (await db.rawQuery('SELECT COUNT(*) AS c FROM subtasks'))
            .first['c'] as int,
        0);
    expect(
        (await db.rawQuery('SELECT COUNT(*) AS c FROM task_tags'))
            .first['c'] as int,
        0);
  });
}
