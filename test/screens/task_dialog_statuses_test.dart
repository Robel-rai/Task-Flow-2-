import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';

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

  Future<void> bootApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(const TaskFlowApp());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
  }

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

  testWidgets(
      'task dialog offers the selected project\'s custom statuses',
      (tester) async {
    // Seed a project with custom columns and one with defaults only.
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      final customId = await testDb.insert('projects', {
        'title': 'Custom Proj',
        'description': '',
        'color': 'primary',
        'status': 'Pending',
        'created_at': now,
      });
      await testDb.insert('projects', {
        'title': 'Plain Proj',
        'description': '',
        'color': 'primary',
        'status': 'Pending',
        'created_at': now,
      });
      for (final (name, order) in [('Todo', 0), ('Blocked', 1), ('Done', 2)]) {
        await testDb.insert('project_statuses', {
          'project_id': customId,
          'name': name,
          'color': 'blue',
          'sort_order': order,
          'created_at': now,
        });
      }
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await tester.tap(find.text('New Task'));
    await tester.pump(const Duration(milliseconds: 300));

    // Defaults until a project is chosen.
    expect(find.text('Pending'), findsOneWidget);

    // Pick the project with custom columns.
    await tester.tap(find.text('No project'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Custom Proj'));
    await settle(tester);

    // The Status dropdown snapped to the first custom status and offers
    // the rest.
    expect(find.text('Todo'), findsOneWidget);
    await tester.tap(find.text('Todo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Blocked'));
    await tester.pump(const Duration(milliseconds: 300));

    // Switch to the project with defaults — status falls back to Pending.
    await tester.tap(find.text('Custom Proj'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Plain Proj'));
    await settle(tester);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets(
      'editing a task with a custom status opens without crashing',
      (tester) async {
    // Seed a project with custom columns and a task assigned to one of
    // them. Statuses load asynchronously, so this exercises the first
    // build of the dialog before the project's columns arrive.
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      final projectId = await testDb.insert('projects', {
        'title': 'Docs',
        'description': '',
        'color': 'primary',
        'status': 'Pending',
        'created_at': now,
      });
      for (final (name, order) in [
        ('Todo', 0),
        ('In Progress', 1),
        ('Under Review', 2),
        ('Done', 3),
      ]) {
        await testDb.insert('project_statuses', {
          'project_id': projectId,
          'name': name,
          'color': 'blue',
          'sort_order': order,
          'created_at': now,
        });
      }
      await testDb.insert('tasks', {
        'title': 'Review me',
        'project_id': projectId,
        'status': 'Under Review',
        'created_at': now,
      });
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    // Clicking the task opens its editor — must not throw the
    // DropdownButton value assertion. The dropdown shows the custom status.
    await tester.tap(find.text('Review me'));
    await tester.pump(const Duration(milliseconds: 300));
    // Let the project's statuses (and subtasks) load fully.
    await settle(tester);

    expect(
      find.descendant(
          of: find.byType(Dialog), matching: find.text('Under Review')),
      findsOneWidget,
    );
  });
}
