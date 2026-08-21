import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/subtask.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/subtask_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/project_service.dart';
import 'package:taskflow/services/task_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late TaskService service;
  late TaskRepository tasks;
  late SubtaskRepository subtasks;

  setUp(() async {
    db = await createTestDb();
    tasks = TaskRepository(db: db);
    subtasks = SubtaskRepository(db: db);
    service = TaskService(
      tasks: tasks,
      subtasks: subtasks,
      projects: ProjectService(
        projects: ProjectRepository(db: db),
        tasks: tasks,
      ),
    );
  });

  tearDown(() => db.close());

  test('create persists subtasks against the new task', () async {
    final saved = await service.create(
      Task(title: 'Plan sprint'),
      subtasks: [
        Subtask(title: 'Write backlog'),
        Subtask(title: 'Estimate'),
      ],
    );
    expect(saved.id, isNotNull);
    final list = await subtasks.getForTask(saved.id!);
    expect(list, hasLength(2));
    expect(list.first.title, 'Write backlog');
    expect(list.first.sortOrder, 0);
  });

  test('complete banks a running timer and sets completedAt', () async {
    final task = await service.create(Task(title: 'Deep work'));
    final running =
        await service.startTimer((await tasks.getById(task.id!))!);
    final completed = await service.complete(running);

    expect(completed.status, 'Completed');
    expect(completed.completedAt, isNotNull);
    expect(completed.isTimerRunning, isFalse);
    expect(completed.timeSpentSeconds, greaterThanOrEqualTo(0));

    final persisted = await tasks.getById(task.id!);
    expect(persisted!.status, 'Completed');
  });

  test('completing all subtasks auto-completes the task', () async {
    final task = await service.create(
      Task(title: 'Ship feature'),
      subtasks: [
        Subtask(title: 'Code'),
        Subtask(title: 'Test'),
      ],
    );
    final list = await subtasks.getForTask(task.id!);
    final updated = await service.toggleSubtask(task, list[0].id!);
    expect(updated.status, 'Pending');

    final updated2 = await service.toggleSubtask(updated, list[1].id!);
    expect(updated2.status, 'Completed');
    expect(updated2.completedAt, isNotNull);

    // Un-checking a subtask reopens a completed task.
    final reopened = await service.toggleSubtask(updated2, list[0].id!);
    expect(reopened.status, 'In Progress');
    expect(reopened.completedAt, isNull);
  });

  test('completing a recurring weekly task spawns the next instance',
      () async {
    final task = await service.create(Task(
      title: 'Standup',
      scheduledDate: DateTime(2026, 8, 10), // Monday
      recurrenceRule: 'FREQ=WEEKLY;BYDAY=MO',
    ));

    // Simulate completion on a Monday.
    await service.complete(task);

    final all = await tasks.getAll();
    expect(all, hasLength(2));
    final spawned = all.firstWhere((t) => t.id != task.id);
    expect(spawned.parentTaskId, task.id);
    expect(spawned.status, 'Pending');
    expect(spawned.scheduledDate!.weekday, DateTime.monday);
  });

  test('trash + restore round-trips a task', () async {
    final task = await service.create(Task(title: 'Temporary'));
    await service.trashTask(task);
    expect(await tasks.getAll(), isEmpty);

    final trashed = await tasks.getById(task.id!);
    expect(trashed!.isDeleted, isTrue);

    await service.restoreTask(trashed);
    expect(await tasks.getAll(), hasLength(1));
  });
}
