import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/subtask.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/category_repository.dart';
import 'package:taskflow/repositories/subtask_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/reporting_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late TaskRepository tasks;
  late ReportingService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    db = await createTestDb();
    tasks = TaskRepository(db: db);
    service = ReportingService(
      tasks: tasks,
      categories: CategoryRepository(db: db),
      subtasks: SubtaskRepository(db: db),
    );
  });

  tearDown(() => db.close());

  test('export → import round-trip preserves tasks', () async {
    final categories = await db.query('categories');
    final workId =
        (categories.firstWhere((c) => c['name'] == 'Work'))['id'] as int;

    await tasks.insert(Task(
      title: 'Ship v2',
      description: 'Release the app',
      categoryId: workId,
      priority: 'High',
      status: 'In Progress',
      scheduledDate: DateTime(2026, 8, 20),
      scheduledTime: '09:30',
      timeSpentSeconds: 3600,
    ));
    await tasks.insert(Task(
      title: 'Review PR',
      status: 'Completed',
      completedAt: DateTime(2026, 8, 18, 15),
    ));

    final csv = await service.exportTasksCsv();
    expect(csv, contains('Ship v2'));
    expect(csv, contains('Review PR'));

    // Wipe and re-import.
    await db.delete('tasks');
    final inserted = await service.importTasksCsv(csv);
    expect(inserted, 2);

    final imported = await tasks.getAll();
    expect(imported, hasLength(2));

    final ship = imported.firstWhere((t) => t.title == 'Ship v2');
    expect(ship.description, 'Release the app');
    expect(ship.categoryId, workId); // resolved by category name
    expect(ship.priority, 'High');
    expect(ship.status, 'In Progress');
    expect(ship.scheduledDate, DateTime(2026, 8, 20));
    expect(ship.scheduledTime, '09:30');
    expect(ship.timeSpentSeconds, 3600);

    final review = imported.firstWhere((t) => t.title == 'Review PR');
    expect(review.status, 'Completed');
    expect(review.completedAt, DateTime(2026, 8, 18, 15));
  });

  test('import resolves category names and tolerates unknown ones', () async {
    final inserted = await service.importTasksCsv(
        'title,category,priority,status\n'
        'Work task,Work,High,Pending\n'
        'Ghost task,Nonexistent,,Completed\n');
    expect(inserted, 2);

    final imported = await tasks.getAll();
    final work = imported.firstWhere((t) => t.title == 'Work task');
    expect(work.categoryId, isNotNull);
    final ghost = imported.firstWhere((t) => t.title == 'Ghost task');
    expect(ghost.categoryId, isNull);
    expect(ghost.priority, 'Medium'); // invalid priority → default
  });

  test('import ignores blank rows and returns 0 for empty input', () async {
    expect(await service.importTasksCsv(''), 0);
    expect(await service.importTasksCsv('title,status\n\n\n'), 0);
    expect(await service.importTasksCsv('title,status\n,,\n,,,,\n'), 0);
  });

  test('export → import preserves subtasks, their order, and states',
      () async {
    final categories = await db.query('categories');
    final workId =
        (categories.firstWhere((c) => c['name'] == 'Work'))['id'] as int;

    final taskId = await tasks.insert(Task(
      title: 'Launch',
      categoryId: workId,
      status: 'In Progress',
    ));
    final subtaskRepo = SubtaskRepository(db: db);
    await subtaskRepo.insert(Subtask(
        taskId: taskId, title: 'Write email', sortOrder: 0, isCompleted: true));
    await subtaskRepo.insert(Subtask(
        taskId: taskId, title: 'Record demo', sortOrder: 1));
    await subtaskRepo.insert(
        Subtask(taskId: taskId, title: 'Notify team', sortOrder: 2));

    final csv = await service.exportTasksCsv();
    expect(csv, contains('Write email | Record demo | Notify team'));
    expect(csv, contains('1|0|0'));

    await db.delete('tasks');
    final inserted = await service.importTasksCsv(csv);
    expect(inserted, 1);

    final imported = await tasks.getAll();
    final subtasks = await subtaskRepo.getForTask(imported.single.id!);
    expect(subtasks, hasLength(3));
    expect(subtasks.map((s) => s.title).toList(),
        ['Write email', 'Record demo', 'Notify team']);
    expect(subtasks[0].isCompleted, isTrue);
    expect(subtasks[1].isCompleted, isFalse);
  });

  test('the sample_tasks.csv file imports cleanly with all subtasks',
      () async {
    final file = File('sample_tasks.csv');
    expect(file.existsSync(), isTrue,
        reason: 'sample_tasks.csv should sit at the project root');
    final csv = file.readAsStringSync();

    final inserted = await service.importTasksCsv(csv);
    expect(inserted, 12);

    final imported = await tasks.getAll();
    expect(imported, hasLength(12));
    final completed = imported.where((t) => t.status == 'Completed').toList();
    final high = imported.where((t) => t.priority == 'High').toList();
    expect(completed, hasLength(3));
    expect(high, hasLength(5));

    final subtaskRepo = SubtaskRepository(db: db);
    final subtasks =
        await subtaskRepo.getForTasks([for (final t in imported) t.id!]);
    final all = [for (final list in subtasks.values) ...list];
    expect(all, hasLength(34)); // sum of all subtask rows in the sample
    // The completed task's subtasks are all marked done.
    final read = imported.firstWhere((t) => t.title == 'Read Deep Work');
    expect(subtasks[read.id]!.every((s) => s.isCompleted), isTrue);
  });

  test('analytics and weekly report CSV have header + value rows', () async {
    final csv = await service
        .exportAnalyticsCsv({'productivity_score': 72, 'streak': 5});
    final lines = csv.split('\r\n');
    expect(lines.first, 'productivity_score,streak');
    expect(lines[1], '72,5');
  });
}
