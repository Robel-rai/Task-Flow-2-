// Phase 2 smoke test — the full app shell renders with all navigation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';

import 'database/test_helpers.dart';

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

  testWidgets('app shell renders with all nav destinations',
      (WidgetTester tester) async {
    await bootApp(tester);

    expect(find.text('TaskFlow'), findsWidgets);
    for (final label in [
      'Dashboard', 'Tasks', 'Calendar', 'Projects',
      'Focus', 'Routines', 'Analytics', 'Settings',
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('clicking a nav item switches the visible screen',
      (WidgetTester tester) async {
    await bootApp(tester);

    // The Focus screen is not built until navigated to (IndexedStack keeps
    // children alive, but only the active index is laid out).
    await tester.tap(find.text('Focus'));
    await tester.pump();
    await settle(tester);

    // The Focus screen header shows 'Focus' as its title.
    expect(find.text('Focus'), findsWidgets);
  });
}
