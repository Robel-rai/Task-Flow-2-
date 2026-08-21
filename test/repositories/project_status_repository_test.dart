import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/project.dart';
import 'package:taskflow/models/project_status.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/project_status_repository.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late ProjectRepository projects;
  late ProjectStatusRepository statuses;

  setUp(() async {
    db = await createTestDb();
    projects = ProjectRepository(db: db);
    statuses = ProjectStatusRepository(db: db);
  });

  tearDown(() => db.close());

  test('inserts and lists statuses in sort order per project', () async {
    final p1 = await projects.insert(Project(title: 'A'));
    final p2 = await projects.insert(Project(title: 'B'));

    for (final (name, order) in [
      ('Review', 2),
      ('Todo', 0),
      ('Blocked', 1),
    ]) {
      await statuses.insert(ProjectStatus(
          projectId: p1, name: name, sortOrder: order));
    }
    await statuses
        .insert(ProjectStatus(projectId: p2, name: 'Other', sortOrder: 0));

    final p1List = await statuses.getForProject(p1);
    expect(p1List.map((s) => s.name), ['Todo', 'Blocked', 'Review']);
    expect(p1List.every((s) => s.projectId == p1), isTrue);

    final p2List = await statuses.getForProject(p2);
    expect(p2List.map((s) => s.name), ['Other']);
  });

  test('updates name and color', () async {
    final projectId = await projects.insert(Project(title: 'A'));
    final id = await statuses.insert(ProjectStatus(
        projectId: projectId, name: 'Doing', color: 'blue'));

    await statuses.update(
        (await statuses.getById(id))!.copyWith(name: 'In progress', color: 'amber'));

    final updated = await statuses.getById(id);
    expect(updated!.name, 'In progress');
    expect(updated.color, 'amber');
  });

  test('delete and deleteForProject remove rows', () async {
    final projectId = await projects.insert(Project(title: 'A'));
    final id1 = await statuses
        .insert(ProjectStatus(projectId: projectId, name: 'One'));
    await statuses
        .insert(ProjectStatus(projectId: projectId, name: 'Two'));

    await statuses.delete(id1);
    expect((await statuses.getForProject(projectId)).map((s) => s.name),
        ['Two']);

    await statuses.deleteForProject(projectId);
    expect(await statuses.getForProject(projectId), isEmpty);

    // Deleting a project removes its statuses too (explicit cleanup).
    final p2 = await projects.insert(Project(title: 'B'));
    await statuses.insert(ProjectStatus(projectId: p2, name: 'X'));
    await projects.delete(p2);
    await statuses.deleteForProject(p2);
    expect(await statuses.getForProject(p2), isEmpty);
  });

  test('rejects empty and over-long names', () async {
    final projectId = await projects.insert(Project(title: 'A'));
    expect(
      () => statuses.insert(
          ProjectStatus(projectId: projectId, name: '  ')),
      throwsArgumentError,
    );
    expect(
      () => statuses.insert(
          ProjectStatus(
              projectId: projectId,
              name: 'This name is way too long for a column')),
      throwsArgumentError,
    );
  });
}
