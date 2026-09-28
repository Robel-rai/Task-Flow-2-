import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/core/event_bus.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/widgets/task_card.dart';

import '../database/test_helpers.dart';

/// Regression test for: "after creating a task with subtasks, the card's
/// subtask dropdown shows nothing until the app is restarted."
///
/// The card cached its subtask list forever and never refetched after a
/// dialog save; these tests pin the fix (event-bus invalidation + task-id
/// keyed elements).
void main() {
  late Database testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_complete': true, 'user_name': 'Test User'});
    testDb = await createTestDb();
    AppDatabase.setDatabaseForTesting(testDb);
  });

  tearDown(() async {
    await testDb.close();
    AppDatabase.closeForTesting();
  });

  /// Pumps repeatedly inside runAsync so real async (sqflite isolates)
  /// completes and the fake-async zone sees the continuations.
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
      // The splash page uses Future.delayed(2s) in initState which runs
      // inside runAsync, so it uses the real clock. Wait 3 real seconds.
      await Future<void>.delayed(const Duration(seconds: 3));
      await tester.pump();
    });
    await settle(tester);
  }

  testWidgets(
      'subtasks saved via the dialog are visible in the card dropdown '
      'without restarting', (tester) async {
    late int taskId;
    await tester.runAsync(() async {
      taskId = await testDb.insert('tasks', {
        'title': 'Fresh task',
        'priority': 'Medium',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await settle(tester);
    expect(find.text('Fresh task'), findsOneWidget);

    // Simulate the task dialog save path: write the subtask rows to the
    // database, then emit the same events the save flow emits, without
    // rebuilding the app (i.e. no restart).
    await tester.runAsync(() async {
      for (var i = 1; i <= 2; i++) {
        await testDb.insert('subtasks', {
          'task_id': taskId,
          'title': 'Fresh subtask $i',
          'is_completed': 0,
          'sort_order': i,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    // Expanding now must load the freshly saved subtasks: the card starts
    // with no cache, so it fetches straight from the DB.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('0/2 done'), findsOneWidget);
    expect(find.text('Fresh subtask 1'), findsOneWidget);
    expect(find.text('Fresh subtask 2'), findsOneWidget);

    // Now expand-collapse-expand while subtasks change underneath, as if
    // the user edited them in the dialog between expansions. The stale
    // cache would have kept showing the old list.
    await tester.runAsync(() async {
      await testDb.insert('subtasks', {
        'task_id': taskId,
        'title': 'Fresh subtask 3',
        'is_completed': 0,
        'sort_order': 3,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    // This is the event createTask/updateTask emit after a dialog save.
    EventBus.instance.emit(AppEvent.taskUpdated);
    await settle(tester);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    expect(find.text('0/3 done'), findsOneWidget);
    expect(find.text('Fresh subtask 3'), findsOneWidget);
  });

  testWidgets(
      'card state is not reused across different tasks after a refresh',
      (tester) async {
    await tester.runAsync(() async {
      final idA = await testDb.insert('tasks', {
        'title': 'Task A',
        'priority': 'Medium',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      await testDb.insert('tasks', {
        'title': 'Task B',
        'priority': 'Medium',
        'status': 'Pending',
        'created_at':
            DateTime.now().add(const Duration(minutes: 1)).toIso8601String(),
      });
      await testDb.insert('subtasks', {
        'task_id': idA,
        'title': 'Only on A',
        'is_completed': 0,
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Task B has none on purpose.
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await settle(tester);
    expect(find.text('Task A'), findsOneWidget);
    expect(find.text('Task B'), findsOneWidget);

    // Expand Task A's card (by identity, not list position) and confirm
    // its subtask shows.
    final cardA = find.ancestor(
        of: find.text('Task A'), matching: find.byType(TaskCard));
    await tester.tap(find
        .descendant(of: cardA, matching: find.byIcon(Icons.keyboard_arrow_down)));
    await settle(tester);
    expect(find.text('Only on A'), findsOneWidget);

    // Task B's card is a different element (keyed by id) and must show
    // its own empty list, not Task A's cached subtasks.
    final cardB = find.ancestor(
        of: find.text('Task B'), matching: find.byType(TaskCard));
    await tester.tap(find
        .descendant(of: cardB, matching: find.byIcon(Icons.keyboard_arrow_down)));
    await settle(tester);
    expect(find.text('No subtasks'), findsOneWidget);
    expect(find.text('Only on A'), findsOneWidget);
  });
}
