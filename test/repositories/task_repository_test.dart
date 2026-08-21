import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/category_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late TaskRepository repo;
  late int generalId;

  setUp(() async {
    db = await createTestDb();
    repo = TaskRepository(db: db);
    generalId = (await CategoryRepository(db: db).getByName('General'))!.id!;
  });

  tearDown(() => db.close());

  test('insert and fetch by id round-trips all fields', () async {
    final task = Task(
      title: 'Write report',
      description: 'Q3 summary',
      categoryId: generalId,
      priority: 'High',
      status: 'Pending',
      scheduledDate: DateTime(2026, 8, 14),
      scheduledTime: '09:30',
      dueDate: DateTime(2026, 8, 20),
    );
    final id = await repo.insert(task);
    final fetched = await repo.getById(id);

    expect(fetched, isNotNull);
    expect(fetched!.title, 'Write report');
    expect(fetched.priority, 'High');
    expect(fetched.scheduledDate, DateTime(2026, 8, 14));
    expect(fetched.scheduledTime, '09:30');
    expect(fetched.categoryId, generalId);
    expect(fetched.isDeleted, isFalse);
  });

  test('stacked filters: search + status + category + date range', () async {
    final workId = (await CategoryRepository(db: db).getByName('Work'))!.id!;

    await repo.insert(Task(title: 'Alpha task', categoryId: workId,
        status: 'Pending', scheduledDate: DateTime(2026, 8, 10)));
    await repo.insert(Task(title: 'Beta task', categoryId: generalId,
        status: 'Completed', scheduledDate: DateTime(2026, 8, 11)));
    await repo.insert(Task(title: 'Gamma', categoryId: workId,
        status: 'Pending', scheduledDate: DateTime(2026, 9, 1)));

    final results = await repo.getAll(
      searchQuery: 'task',
      categoryId: workId,
      statusFilter: 'Pending',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    expect(results.map((t) => t.title), ['Alpha task']);
  });

  test('soft delete moves task out of the list; restore brings it back',
      () async {
    final id = await repo.insert(Task(title: 'Doomed'));
    expect(await repo.getById(id), isNotNull);

    await repo.trash(id);
    expect(await repo.getAll(), isEmpty);
    expect((await repo.getById(id))!.isDeleted, isTrue);

    await repo.restore(id);
    expect(await repo.getAll(), hasLength(1));
  });

  test('updateSortOrder persists day-view ordering', () async {
    final a = await repo.insert(Task(title: 'A'));
    final b = await repo.insert(Task(title: 'B'));
    final c = await repo.insert(Task(title: 'C'));

    await repo.updateSortOrder([c, a, b]);
    final ordered = await repo.getAll(sortBy: 'sort_order');
    expect(ordered.map((t) => t.id), [c, a, b]);
  });

  test('analytics: completionCountsForWeek groups by day in one query',
      () async {
    final end = DateTime(2026, 8, 14);
    // Complete 2 tasks on 08-10 and 1 on 08-14.
    await repo.insert(Task(title: 't1', status: 'Completed',
        completedAt: DateTime(2026, 8, 10, 9)));
    await repo.insert(Task(title: 't2', status: 'Completed',
        completedAt: DateTime(2026, 8, 10, 18)));
    await repo.insert(Task(title: 't3', status: 'Completed',
        completedAt: DateTime(2026, 8, 14, 12)));

    final counts = await repo.completionCountsForWeek(end);
    expect(counts, hasLength(7));
    expect(counts[2], 2); // 08-10 is end-4 -> index 2
    expect(counts[6], 1); // 08-14 -> index 6
    expect(counts[0], 0);
  });

  test('categoryDistribution counts tasks by category name', () async {
    await repo.insert(Task(title: 'x', categoryId: generalId));
    await repo.insert(Task(title: 'y', categoryId: generalId));
    final dist = await repo.categoryDistribution();
    expect(dist['General'], 2);
  });
}
