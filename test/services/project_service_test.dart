import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/project.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/project_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late ProjectRepository projects;
  late TaskRepository tasks;
  late ProjectService service;

  setUp(() async {
    db = await createTestDb();
    projects = ProjectRepository(db: db);
    tasks = TaskRepository(db: db);
    service = ProjectService(projects: projects, tasks: tasks);
  });

  tearDown(() => db.close());

  test('project auto-completes when every task is done', () async {
    final projectId = await projects.insert(Project(title: 'Launch site'));
    await tasks.insert(Task(title: 'Design', projectId: projectId));
    await tasks.insert(Task(title: 'Build', projectId: projectId));

    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Pending');

    // Complete all tasks and re-evaluate.
    final all = await tasks.getForProject(projectId);
    for (final t in all) {
      await tasks.update(t.copyWith(
          status: 'Completed', completedAt: DateTime.now()));
    }
    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Completed');
  });

  test('project reopens when a task is un-completed', () async {
    final projectId = await projects.insert(Project(title: 'Docs', status: 'Completed'));
    await tasks.insert(Task(
        title: 'Old task',
        projectId: projectId,
        status: 'Completed',
        completedAt: DateTime.now()));
    await tasks.insert(Task(
        title: 'Reopened',
        projectId: projectId,
        status: 'Completed',
        completedAt: DateTime.now()));

    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Completed');

    // Reopen one task.
    final reopened = (await tasks.getForProject(projectId))
        .firstWhere((t) => t.title == 'Reopened');
    await tasks.update(
        reopened.copyWith(status: 'Pending', clearCompletedAt: true));
    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Pending');
  });

  test('project becomes In Progress while a task is in progress', () async {
    final projectId = await projects.insert(Project(title: 'Build'));
    final t1 = await tasks.insert(Task(title: 'Design', projectId: projectId));
    await tasks.insert(Task(title: 'Code', projectId: projectId));

    // Nothing in progress yet.
    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Pending');

    // One task moves to In Progress -> project follows.
    await tasks.update(
        (await tasks.getById(t1))!.copyWith(status: 'In Progress'));
    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'In Progress');

    // Task moves back to Pending -> project returns to Pending.
    await tasks.update(
        (await tasks.getById(t1))!.copyWith(status: 'Pending'));
    await service.evaluate(projectId);
    expect((await projects.getById(projectId))!.status, 'Pending');
  });

  test('moveTaskStatus transitions and stamps completion', () async {
    final task = Task(title: 'Kanban card');
    final taskId = await tasks.insert(task);

    final moved = await service.moveTaskStatus(taskId, 'In Progress');
    expect(moved!.status, 'In Progress');

    final done = await service.moveTaskStatus(taskId, 'Completed');
    expect(done!.status, 'Completed');
    expect(done.completedAt, isNotNull);

    final pending = await service.moveTaskStatus(taskId, 'Pending');
    expect(pending!.status, 'Pending');
    expect(pending.completedAt, isNull);
  });

  test('progress returns (completed, total)', () async {
    final projectId = await projects.insert(Project(title: 'P'));
    await tasks.insert(Task(title: 'a', projectId: projectId, status: 'Completed'));
    await tasks.insert(Task(title: 'b', projectId: projectId, status: 'Pending'));

    final (done, total) = await service.progress(projectId);
    expect(done, 1);
    expect(total, 2);
    expect(service.completionRate(done, total), 50.0);
  });
}
