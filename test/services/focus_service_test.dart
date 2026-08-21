import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/focus_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/focus_session_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/focus_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late FocusSessionRepository sessions;
  late TaskRepository tasks;
  late FocusService service;
  late DateTime fakeNow;

  setUp(() async {
    db = await createTestDb();
    sessions = FocusSessionRepository(db: db);
    tasks = TaskRepository(db: db);
    fakeNow = DateTime(2026, 8, 14, 9, 0);
    service = FocusService(
      sessions: sessions,
      tasks: tasks,
      now: () => fakeNow,
    );
  });

  tearDown(() => db.close());

  test('starting a session persists it and auto-starts the task timer',
      () async {
    final taskId = await tasks.insert(Task(title: 'Deep work'));

    final session = await service.start(taskId: taskId);
    expect(session.id, isNotNull);
    expect(session.isRunning, isTrue);
    expect(session.startedAt, fakeNow);

    final task = await tasks.getById(taskId);
    expect(task!.isTimerRunning, isTrue);
    expect(task.status, 'In Progress');
  });

  test('stopping a session banks duration and stops the task timer', () async {
    final taskId = await tasks.insert(Task(title: 'Focus'));
    final session = await service.start(taskId: taskId);

    fakeNow = fakeNow.add(const Duration(seconds: 300)); // +5 minutes
    final stopped = await service.stop(session);

    expect(stopped.endedAt, fakeNow);
    expect(stopped.durationSeconds, 300);

    final task = await tasks.getById(taskId);
    expect(task!.isTimerRunning, isFalse);
    expect(task.timeSpentSeconds, 300);
  });

  test('unfocused session (no task) still records duration', () async {
    final session = await service.start();
    fakeNow = fakeNow.add(const Duration(minutes: 1));
    final stopped = await service.stop(session);
    expect(stopped.durationSeconds, 60);
  });

  test('pause freezes time and resume continues from the frozen point',
      () async {
    final session = await service.start();

    // 5 minutes in, pause.
    fakeNow = fakeNow.add(const Duration(minutes: 5));
    final paused = await service.pause(session);
    expect(paused.isPaused, isTrue);
    expect(paused.durationSeconds, 300);

    // Time passes while paused; the frozen duration must not grow.
    fakeNow = fakeNow.add(const Duration(minutes: 30));
    expect(paused.currentDurationSeconds, 300);

    // Resume, then run another 5 minutes and stop: the full accumulated
    // duration (300 frozen + 300 new) is recorded.
    final resumed = await service.resume(paused);
    expect(resumed.isPaused, isFalse);
    expect(resumed.durationSeconds, 300);
    fakeNow = fakeNow.add(const Duration(minutes: 5));
    final stopped = await service.stop(resumed);
    expect(stopped.endedAt, fakeNow);
    expect(stopped.durationSeconds, 600);
  });

  test('stopping while paused banks the frozen duration, not wall clock',
      () async {
    final taskId = await tasks.insert(Task(title: 'Paused focus'));
    final session = await service.start(taskId: taskId);

    fakeNow = fakeNow.add(const Duration(minutes: 3));
    final paused = await service.pause(session);

    // Wall clock moves 1 hour while paused — the task timer is banked
    // only for the frozen 3 minutes when stopped.
    fakeNow = fakeNow.add(const Duration(hours: 1));
    final stopped = await service.stop(paused);

    expect(stopped.durationSeconds, 180);
    final task = await tasks.getById(taskId);
    expect(task!.timeSpentSeconds, 180);
    expect(task.isTimerRunning, isFalse);
  });

  test('break threshold helpers', () {
    expect(FocusService.breakThresholdSeconds, 7200);
    final done = FocusSession(
        startedAt: DateTime(2026, 8, 14, 8),
        endedAt: DateTime(2026, 8, 14, 10, 5), // 2h 5m
        durationSeconds: 7500);
    expect(FocusService.breakThresholdMet(done), isTrue);

    final short = FocusSession(
        startedAt: DateTime(2026, 8, 14, 8),
        endedAt: DateTime(2026, 8, 14, 8, 30),
        durationSeconds: 1800);
    expect(FocusService.breakThresholdMet(short), isFalse);
  });
}
