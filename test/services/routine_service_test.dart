import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/routine.dart';
import 'package:taskflow/repositories/routine_repository.dart';
import 'package:taskflow/services/routine_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late RoutineRepository repo;
  late RoutineService service;

  setUp(() async {
    db = await createTestDb();
    repo = RoutineRepository(db: db);
    service = RoutineService(routines: repo);
  });

  tearDown(() => db.close());

  test('completed yesterday keeps the streak, clears today', () async {
    final now = DateTime(2026, 8, 14, 12);
    final routine = Routine(
      title: 'Exercise',
      scheduledTime: '07:00',
      streak: 5,
      isCompletedToday: true,
      lastCompletedDate: DateTime(2026, 8, 13, 8),
    );
    final id = await repo.insert(routine);
    // Services operate on persisted routines (id must be set).
    final persisted = (await repo.getById(id))!;

    final updated = await service.resetForToday(persisted, now);
    expect(updated.isCompletedToday, isFalse);
    expect(updated.streak, 5);
    expect((await repo.getById(id))!.isCompletedToday, isFalse);
  });

  test('missed a full day resets the streak to zero', () async {
    final now = DateTime(2026, 8, 14, 12);
    final routine = Routine(
      title: 'Read',
      scheduledTime: '21:00',
      streak: 3,
      isCompletedToday: true,
      lastCompletedDate: DateTime(2026, 8, 12, 21),
    );

    final id = await repo.insert(routine);
    final persisted = (await repo.getById(id))!;

    final updated = await service.resetForToday(persisted, now);
    expect(updated.streak, 0);
    expect(updated.isCompletedToday, isFalse);
  });

  test('not completed today and missed yesterday drops the streak', () async {
    final now = DateTime(2026, 8, 14, 12);
    final routine = Routine(
      title: 'Meditate',
      scheduledTime: '06:00',
      streak: 9,
      isCompletedToday: false,
      lastCompletedDate: DateTime(2026, 8, 12, 6),
    );

    final id = await repo.insert(routine);
    final persisted = (await repo.getById(id))!;

    final updated = await service.resetForToday(persisted, now);
    expect(updated.streak, 0);
  });

  test('no change when completed today', () async {
    final now = DateTime(2026, 8, 14, 12);
    final routine = Routine(
      title: 'Journal',
      scheduledTime: '22:00',
      streak: 2,
      isCompletedToday: true,
      lastCompletedDate: DateTime(2026, 8, 14, 8),
    );

    final updated = await service.resetForToday(routine, now);
    expect(identical(updated, routine), isTrue);
  });

  test('toggleCompletion increments then decrements the streak', () async {
    final routine = Routine(title: 'Walk', scheduledTime: '12:00', streak: 1);
    final id = await repo.insert(routine);

    final checked = await service.toggleCompletion(routine);
    expect(checked.isCompletedToday, isTrue);
    expect(checked.streak, 2);

    final unchecked = await service.toggleCompletion(checked);
    expect(unchecked.isCompletedToday, isFalse);
    expect(unchecked.streak, 1);

    final persisted = await repo.getById(id);
    expect(persisted!.isCompletedToday, isFalse);
    expect(persisted.streak, 1);
  });
}
