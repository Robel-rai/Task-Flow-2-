import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/models/focus_session.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/focus_session_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/services/analytics_service.dart';

import '../database/test_helpers.dart';

void main() {
  late Database db;
  late TaskRepository tasks;
  late FocusSessionRepository sessions;
  late AnalyticsService service;

  setUp(() async {
    db = await createTestDb();
    tasks = TaskRepository(db: db);
    sessions = FocusSessionRepository(db: db);
    service = AnalyticsService(tasks: tasks, sessions: sessions);
  });

  tearDown(() => db.close());

  group('streak helpers', () {
    test('currentStreak counts consecutive days ending today', () {
      final today = DateTime(2026, 8, 18);
      expect(
        AnalyticsService.currentStreak({
          DateTime(2026, 8, 16),
          DateTime(2026, 8, 17),
          DateTime(2026, 8, 18),
        }, today: today),
        3,
      );
    });

    test('an empty today still counts the run ending yesterday', () {
      final today = DateTime(2026, 8, 18);
      expect(
        AnalyticsService.currentStreak({
          DateTime(2026, 8, 16),
          DateTime(2026, 8, 17),
        }, today: today),
        2,
      );
    });

    test('a gap breaks the current streak', () {
      final today = DateTime(2026, 8, 18);
      expect(
        AnalyticsService.currentStreak({
          DateTime(2026, 8, 15),
          DateTime(2026, 8, 17),
          DateTime(2026, 8, 18),
        }, today: today),
        2,
      );
    });

    test('maxStreak finds the longest historical run', () {
      expect(
        AnalyticsService.maxStreak({
          DateTime(2026, 8, 1),
          DateTime(2026, 8, 2),
          DateTime(2026, 8, 3),
          DateTime(2026, 8, 10),
          DateTime(2026, 8, 11),
        }),
        3,
      );
    });

    test('no completions means zero streaks', () {
      expect(AnalyticsService.currentStreak({}), 0);
      expect(AnalyticsService.maxStreak({}), 0);
    });
  });

  test('loadSummary aggregates completions, focus time, and categories',
      () async {
    final categories = await db.query('categories');
    final workId =
        (categories.firstWhere((c) => c['name'] == 'Work'))['id'] as int;
    final studyId =
        (categories.firstWhere((c) => c['name'] == 'Study'))['id'] as int;

    await tasks.insert(Task(
        title: 'Done A',
        categoryId: workId,
        status: 'Completed',
        completedAt: DateTime(2026, 8, 18, 9)));
    await tasks.insert(Task(
        title: 'Done B',
        categoryId: workId,
        status: 'Completed',
        completedAt: DateTime(2026, 8, 17, 9)));
    await tasks.insert(Task(
        title: 'Open C', categoryId: studyId, status: 'Pending'));

    await sessions.insert(FocusSession(
        startedAt: DateTime(2026, 8, 18, 10),
        endedAt: DateTime(2026, 8, 18, 11),
        durationSeconds: 3600));
    await sessions.insert(FocusSession(
        startedAt: DateTime(2026, 8, 16, 10),
        endedAt: DateTime(2026, 8, 16, 10, 30),
        durationSeconds: 1800));

    final summary = await service.loadSummary(now: DateTime(2026, 8, 18));

    expect(summary.completedThisWeek, 2);
    expect(summary.completedLastWeek, 0);
    expect(summary.currentStreak, 2); // Aug 17–18
    expect(summary.maxStreak, 2);
    expect(summary.completionRate, closeTo(66.67, 0.01));
    expect(summary.focusMinutesPerDay['2026-08-18'], 60);
    expect(summary.focusMinutesPerDay['2026-08-16'], 30);
    expect(summary.focusMinutesThisWeek, 90);

    final work =
        summary.categoryPerformance.firstWhere((p) => p.$1 == 'Work');
    expect(work.$2, 2);
    expect(work.$3, 2);
    final study =
        summary.categoryPerformance.firstWhere((p) => p.$1 == 'Study');
    expect(study.$2, 1);
    expect(study.$3, 0);

    // completion 66.67*0.5 + focus consistency (2 of 7 days = 28.57)*0.5.
    expect(summary.productivityScore, 48);
  });

  test('loadSummary with no data yields zeros and an empty chart', () async {
    final summary = await service.loadSummary(now: DateTime(2026, 8, 18));
    expect(summary.productivityScore, 0);
    expect(summary.currentStreak, 0);
    expect(summary.maxStreak, 0);
    expect(summary.completionRate, 0);
    expect(summary.completedThisWeek, 0);
    expect(summary.focusMinutesPerDay.values.every((v) => v == 0), isTrue);
    expect(summary.categoryPerformance, isEmpty);
  });
}
