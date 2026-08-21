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
    await tester.tap(find.text('Calendar'));
    await settle(tester);
  }

  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  testWidgets('month view shows task chips and view switching works',
      (tester) async {
    final now = DateTime.now();
    final dayA = dateOnly(DateTime(now.year, now.month, 5));
    final dayB = dateOnly(DateTime(now.year, now.month, 20));
    await tester.runAsync(() async {
      final ts = DateTime.now().toIso8601String();
      await testDb.insert('tasks', {
        'title': 'Month task A',
        'scheduled_date': dayA.toIso8601String().split('T').first,
        'created_at': ts,
      });
      await testDb.insert('tasks', {
        'title': 'Month task B',
        'scheduled_date': dayB.toIso8601String().split('T').first,
        'created_at': ts,
      });
    });

    await bootApp(tester);

    // Month view: both chips visible.
    expect(find.text('Month task A'), findsOneWidget);
    expect(find.text('Month task B'), findsOneWidget);

    // Clicking a day opens the day detail (Day view). Day numbers can
    // repeat in the leading/trailing adjacent-month cells, so take the
    // first match (this month's day 5).
    await tester.tap(find.text('${dayA.day}').first);
    await settle(tester);
    expect(find.text('Month task A'), findsOneWidget);
    expect(find.text('Add task on this day'), findsOneWidget);

    // Week view shows the same task in a day column.
    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('Month task A'), findsOneWidget);

    // Agenda view lists both.
    await tester.tap(find.text('Agenda'));
    await settle(tester);
    expect(find.text('Month task A'), findsOneWidget);
    expect(find.text('Month task B'), findsOneWidget);
  });

  testWidgets('dragging a task chip to another day persists scheduled_date',
      (tester) async {
    final today = dateOnly(DateTime.now());
    // Target day within the same week: tomorrow unless today is Saturday.
    final target = today.weekday == DateTime.saturday
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));

    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Drag me',
        'scheduled_date': today.toIso8601String().split('T').first,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);

    await tester.tap(find.text('Week'));
    await settle(tester);
    expect(find.text('Drag me'), findsOneWidget);

    // Long-press the chip and drop it on the neighboring day column.
    final gesture = await tester.startGesture(tester.getCenter(find.text('Drag me')));
    await tester.pump(const Duration(milliseconds: 700)); // exceed long-press
    await gesture.moveTo(tester.getCenter(find.text('${target.day}')));
    await tester.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await settle(tester);

    final rows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Drag me'")))!;
    expect(rows.single['scheduled_date'],
        target.toIso8601String().split('T').first);
  });

  testWidgets('day view drag-reorder persists sort_order', (tester) async {
    final today = dateOnly(DateTime.now());
    await tester.runAsync(() async {
      final ts = DateTime.now().toIso8601String();
      final day = today.toIso8601String().split('T').first;
      await testDb.insert('tasks', {
        'title': 'First task',
        'scheduled_date': day,
        'sort_order': 0,
        'created_at': ts,
      });
      await testDb.insert('tasks', {
        'title': 'Second task',
        'scheduled_date': day,
        'sort_order': 1,
        'created_at': ts,
      });
    });

    await bootApp(tester);

    await tester.tap(find.text('Day'));
    await settle(tester);
    expect(find.text('First task'), findsOneWidget);
    expect(find.text('Second task'), findsOneWidget);

    // Drag the first row down past the second.
    await tester.drag(find.byIcon(Icons.drag_indicator).first,
        const Offset(0, 120));
    await settle(tester);

    final rows = (await tester.runAsync(() => testDb.rawQuery(
        'SELECT title, sort_order FROM tasks ORDER BY sort_order')))!;
    expect(rows.map((r) => r['title']).toList(), ['Second task', 'First task']);
  });
}
