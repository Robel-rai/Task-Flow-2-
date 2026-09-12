import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/core/app_navigator.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/project.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';

import '../database/test_helpers.dart';

void main() {
  late Database testDb;
  late TaskRepository taskRepo;
  late ProjectRepository projectRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'user_name': 'Test User'});
    testDb = await createTestDb();
    AppDatabase.setDatabaseForTesting(testDb);
    taskRepo = TaskRepository(db: testDb);
    projectRepo = ProjectRepository(db: testDb);
    AppNavigator.instance.reset();
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

  /// Opens the global search panel, types [query], and waits for results.
  Future<void> openAndSearch(WidgetTester tester, String query) async {
    await tester.tap(find.byKey(const Key('sidebar_search_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find.byKey(const Key('global_search_field')), query);
    await tester.pump(const Duration(milliseconds: 300)); // debounce
    await settle(tester);
  }

  testWidgets('sidebar search jumps to a task editor from the Calendar page',
      (tester) async {
    await tester.runAsync(() async {
      await taskRepo.insert(
          Task(title: 'Mobile App Design', priority: 'High'));
    });
    await bootApp(tester);

    // Navigate away from the dashboard first.
    await tester.tap(find.text('Calendar').first);
    await tester.pump();

    await openAndSearch(tester, 'Mobile');

    await tester.tap(find.descendant(
      of: find.byKey(const Key('global_search_panel')),
      matching: find.text('Mobile App Design'),
    ));
    await settle(tester);

    // The panel closed and we're on the Tasks page with the editor open.
    expect(find.byKey(const Key('global_search_panel')), findsNothing);
    expect(find.text('Edit Task'), findsOneWidget);
    expect(find.text('Mobile App Design'), findsWidgets);
  });

  testWidgets('sidebar search opens a project kanban from the Projects page',
      (tester) async {
    await tester.runAsync(() async {
      await projectRepo.insert(Project(title: 'Launch Plan', color: 'blue'));
    });
    await bootApp(tester);

    await tester.tap(find.text('Projects').first);
    await tester.pump();

    await openAndSearch(tester, 'Launch');

    await tester.tap(find.descendant(
      of: find.byKey(const Key('global_search_panel')),
      matching: find.text('Launch Plan'),
    ));
    await settle(tester);

    expect(find.byKey(const Key('global_search_panel')), findsNothing);
    expect(find.text('Drag tasks between columns to update status'),
        findsOneWidget);
    expect(find.text('Launch Plan'), findsWidgets);
  });
}
