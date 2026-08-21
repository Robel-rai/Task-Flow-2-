import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/providers/tasks_provider.dart';
import 'package:taskflow/widgets/sidebar.dart';

import '../database/test_helpers.dart';

void main() {
  late Database testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    testDb = await createTestDb();
    AppDatabase.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    await testDb.close();
    AppDatabase.closeForTesting();
  });

  Future<void> settle(WidgetTester tester,
      {int cycles = 20, Duration step = const Duration(milliseconds: 50)}) async {
    for (var i = 0; i < cycles; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(step);
        await tester.pump(step);
      });
    }
  }

  Future<void> bootApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(const TaskFlowApp());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
    // Target the sidebar item: the Focus page header also contains "Focus",
    // and AppNavigator keeps its last index across tests in this file.
    await tester.tap(find.descendant(
      of: find.byType(Sidebar),
      matching: find.text('Focus'),
    ));
    await settle(tester);
  }

  testWidgets('focus timer starts, pauses, resumes, stops and logs the session',
      (tester) async {
    // Seed a task to attach the session to.
    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Deep Work',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);

    // Idle state.
    expect(find.text('Focus Timer'), findsOneWidget);
    expect(find.text('Start Session'), findsOneWidget);

    // Attach the seeded task.
    await tester.tap(find.text('No task (unfocused)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Deep Work').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Start.
    await tester.tap(find.text('Start Session'));
    await settle(tester);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    // The session row + auto-started task timer persist.
    var sessions = (await tester.runAsync(() => testDb
        .query('focus_sessions')))!;
    expect(sessions, hasLength(1));
    expect(sessions.single['task_id'], isNotNull);
    expect(sessions.single['ended_at'], isNull);
    var taskRows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Deep Work'")))!;
    expect(taskRows.single['timer_started_at'], isNotNull);

    // Pause → frozen; Resume → running again.
    await tester.tap(find.text('Pause'));
    await settle(tester);
    expect(find.text('Resume'), findsOneWidget);
    sessions = (await tester.runAsync(
        () => testDb.query('focus_sessions')))!;
    expect(sessions.single['paused_at'], isNotNull);

    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(find.text('Pause'), findsOneWidget);

    // Stop → session ends, task timer banks its time.
    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(find.text('Start Session'), findsOneWidget);
    sessions = (await tester.runAsync(
        () => testDb.query('focus_sessions')))!;
    expect(sessions.single['ended_at'], isNotNull);
    taskRows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Deep Work'")))!;
    expect(taskRows.single['timer_started_at'], isNull);

    // The session log shows the finished session.
    expect(find.text("Today's Focus"), findsOneWidget);
    expect(find.text('Deep Work'), findsWidgets);
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets(
      'deleting the attached task resets the attach dropdown instead of crashing',
      (tester) async {
    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Deep Work',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);

    // Attach the seeded task.
    await tester.tap(find.text('No task (unfocused)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Deep Work').last);
    await tester.pump(const Duration(milliseconds: 300));

    // Delete the task out from under the selection, then refresh the list
    // (equivalent to a Tasks-page filter/delete while Focus stays alive).
    await tester.runAsync(() async {
      await testDb.delete('tasks', where: "title = 'Deep Work'");
      final ctx = tester.element(find.text('Focus Timer'));
      await ctx.read<TasksProvider>().refresh();
    });
    await tester.pump(const Duration(milliseconds: 300));

    // No assertion thrown; the dropdown fell back to "No task".
    expect(find.text('No task (unfocused)'), findsOneWidget);
    expect(find.text('Deep Work'), findsNothing);
  });

  testWidgets('clear all sessions asks for confirmation and empties the log',
      (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      await testDb.insert('focus_sessions', {
        'task_id': null,
        'started_at': now,
        'ended_at': now, // completed session: fixed 5-minute duration
        'duration_seconds': 300,
        'session_type': 'pomodoro',
        'created_at': now,
      });
    });

    await bootApp(tester);

    // The seeded session (5 minutes) shows in the log.
    expect(find.text('05:00'), findsWidgets);

    // Cancel keeps the sessions.
    await tester.tap(find.byTooltip('Clear all focus sessions'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Clear all focus sessions?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('05:00'), findsWidgets);

    // Confirm wipes the table and the log reflects the empty state.
    await tester.tap(find.byTooltip('Clear all focus sessions'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Clear all'));
    await settle(tester);

    final rows =
        (await tester.runAsync(() => testDb.query('focus_sessions')))!;
    expect(rows, isEmpty);
    expect(find.textContaining('No focus sessions yet today'), findsOneWidget);
  });
}
