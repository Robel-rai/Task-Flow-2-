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
  }

  Finder inSidebar(String label) =>
      find.descendant(of: find.byType(Sidebar), matching: find.text(label));

  Future<void> openNavOrderPage(WidgetTester tester) async {
    await tester.tap(inSidebar('Settings'));
    await settle(tester);
    await tester.tap(find.text('Sidebar order'));
    await settle(tester);
    expect(find.text('Reset to default'), findsOneWidget);
  }

  testWidgets('reordering in the sidebar order page moves the sidebar item '
      'and persists', (tester) async {
    await bootApp(tester);
    await openNavOrderPage(tester);

    // Default order: Dashboard first, Tasks before Calendar.
    expect(inSidebar('Dashboard').evaluate(), isNotEmpty);
    final beforeTasks = tester.getTopLeft(inSidebar('Tasks')).dy;
    final beforeCalendar = tester.getTopLeft(inSidebar('Calendar')).dy;
    expect(beforeTasks, lessThan(beforeCalendar));

    // Drag the Tasks row (second drag handle) down one row.
    await tester.drag(find.byIcon(Icons.drag_indicator).at(1),
        const Offset(0, 120));
    await settle(tester);

    // The sidebar order changed live: Calendar now sits above Tasks.
    final afterTasks = tester.getTopLeft(inSidebar('Tasks')).dy;
    final afterCalendar = tester.getTopLeft(inSidebar('Calendar')).dy;
    expect(afterTasks, greaterThan(afterCalendar));

    // Persisted: Tasks moved below both Dashboard and Calendar, and the
    // list still contains every page exactly once.
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('navOrder')!;
    expect(stored, hasLength(8));
    expect(stored.toSet(),
        {'dashboard', 'tasks', 'calendar', 'projects', 'focus',
         'routines', 'analytics', 'settings'});
    expect(stored.indexOf('tasks'), greaterThan(stored.indexOf('dashboard')));
    expect(stored.indexOf('tasks'), greaterThan(stored.indexOf('calendar')));

    // Navigation still works from the moved item.
    await tester.tap(inSidebar('Tasks'));
    await settle(tester);
    expect(find.text('New Task'), findsOneWidget);
  });

  testWidgets('reset to default restores the built-in order', (tester) async {
    await bootApp(tester);
    await openNavOrderPage(tester);

    // Move Dashboard down one row first.
    await tester.drag(find.byIcon(Icons.drag_indicator).first,
        const Offset(0, 120));
    await settle(tester);

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('navOrder')!.first, 'tasks');

    await tester.tap(find.text('Reset to default'));
    await settle(tester);

    prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('navOrder'),
        ['dashboard', 'tasks', 'calendar', 'projects', 'focus',
         'routines', 'analytics', 'settings']);

    // The sidebar is back to the default order.
    final dashboardY = tester.getTopLeft(inSidebar('Dashboard')).dy;
    final tasksY = tester.getTopLeft(inSidebar('Tasks')).dy;
    expect(dashboardY, lessThan(tasksY));
  });
}
