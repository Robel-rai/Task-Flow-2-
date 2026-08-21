import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/category.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/category_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late CategoryRepository repo;

  setUp(() async {
    db = await createTestDb();
    repo = CategoryRepository(db: db);
  });

  tearDown(() => db.close());

  test('fresh database is seeded with default categories', () async {
    final all = await repo.getAll();
    expect(all.map((c) => c.name),
        containsAll(['General', 'Work', 'Study', 'Health']));
  });

  test('insert + getByName round-trip', () async {
    final id = await repo.insert(Category(name: 'Chores', color: 'amber'));
    final fetched = await repo.getByName('Chores');
    expect(fetched, isNotNull);
    expect(fetched!.id, id);
    expect(fetched.color, 'amber');
  });

  test('deleting a category re-parents its tasks to General', () async {
    final chores = await repo.insert(Category(name: 'Chores'));
    final taskRepo = TaskRepository(db: db);
    final taskId = await taskRepo.insert(Task(title: 'Clean', categoryId: chores));
    final generalId = (await repo.getByName('General'))!.id!;
    expect(generalId, isNot(chores));

    await repo.delete(chores);
    final task = await taskRepo.getById(taskId);
    expect(task!.categoryId, generalId);
  });

  test('ensureGeneral is idempotent', () async {
    final first = await repo.ensureGeneral();
    final second = await repo.ensureGeneral();
    expect(first, second);
  });

  test('accepts a name of exactly 12 characters', () async {
    final id = await repo.insert(Category(name: '123456789012'));
    final fetched = await repo.getById(id);
    expect(fetched!.name, '123456789012');
  });

  test('rejects a name longer than 12 characters on insert', () {
    expect(() => repo.insert(Category(name: '1234567890123')),
        throwsArgumentError);
  });

  test('rejects a name longer than 12 characters on update', () async {
    final id = await repo.insert(Category(name: 'Chores'));
    expect(
        () => repo.update(Category(
            id: id, name: '1234567890123', color: 'amber')),
        throwsArgumentError);
  });
}
