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
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'user_name': 'Test User'});
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

  testWidgets('create a task from the dialog and see it in the grid',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    await tester.tap(find.text('New Task'));
    await tester.pump(const Duration(milliseconds: 300));

    final titleField = find
        .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
        .first;
    await tester.enterText(titleField, 'Buy groceries');

    await tester.tap(find.text('Create Task'));
    await settle(tester);

    expect(find.text('Buy groceries'), findsOneWidget);
    expect(find.text('No tasks found'), findsNothing);
  });

  testWidgets('completing a task via the card checkbox', (tester) async {
    // Seed a task directly (real async — needs runAsync in the fake zone).
    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Seed task',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    expect(find.text('Seed task'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await settle(tester);

    // The card's unchecked radio is gone once the task is completed
    // (the sidebar's active-nav check icon is expected and unrelated).
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });
}
