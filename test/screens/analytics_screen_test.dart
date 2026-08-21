import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
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
    // Target the sidebar item — the Analytics page header also has the word.
    await tester.tap(find.descendant(
      of: find.byType(Sidebar),
      matching: find.text('Analytics'),
    ));
    await settle(tester);
  }

  testWidgets('analytics screen shows stat cards, charts, and report',
      (tester) async {
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      await testDb.insert('tasks', {
        'title': 'Done task',
        'status': 'Completed',
        'completed_at': now,
        'created_at': now,
      });
      await testDb.insert('tasks', {
        'title': 'Pending task',
        'status': 'Pending',
        'created_at': now,
      });
      await testDb.insert('focus_sessions', {
        'task_id': null,
        'started_at': now,
        'ended_at': now,
        'duration_seconds': 1800,
        'session_type': 'pomodoro',
        'created_at': now,
      });
    });

    await bootApp(tester);

    expect(find.text('Productivity Score'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
    expect(find.text('Best Streak'), findsOneWidget);
    expect(find.text('Completion Rate'), findsOneWidget);
    expect(find.text('Focus Time'), findsOneWidget);
    expect(find.text('Top Categories'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Task Overview'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    // One completion today → current and best streak both "1 day".
    expect(find.text('1 day'), findsNWidgets(2));
  });

  testWidgets('analytics screen handles empty data without crashing',
      (tester) async {
    await bootApp(tester);

    // Empty state shows the empty analytics component instead.
    expect(find.text('No analytics yet'), findsOneWidget);
  });
}
