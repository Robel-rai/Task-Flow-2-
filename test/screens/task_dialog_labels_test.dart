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
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
    await settle(tester);
  }

  testWidgets('task dialog shows Task Title and Description labels above fields',
      (tester) async {
    await bootApp(tester);

    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    await tester.tap(find.text('New Task'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Task Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);

    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));

    // Title label sits above the title field; Description above description.
    final titleLabelY = tester.getTopLeft(find.text('Task Title')).dy;
    final titleFieldY = tester.getTopLeft(fields.first).dy;
    expect(titleLabelY, lessThan(titleFieldY));

    final descLabelY = tester.getTopLeft(find.text('Description')).dy;
    final descFieldY = tester.getTopLeft(fields.at(1)).dy;
    expect(descLabelY, lessThan(descFieldY));
  });
}
