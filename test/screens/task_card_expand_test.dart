import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/widgets/task_card.dart';

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

  testWidgets('task card shows badges, edit/delete, and expandable subtasks',
      (tester) async {
    await tester.runAsync(() async {
      final taskId = await testDb.insert('tasks', {
        'title': 'Card task',
        'priority': 'High',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 1; i <= 12; i++) {
        await testDb.insert('subtasks', {
          'task_id': taskId,
          'title': 'Subtask $i',
          'is_completed': 0,
          'sort_order': i,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    // Badges, status, and top-right buttons are present.
    expect(find.text('Card task'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.text('Pending')), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.byIcon(Icons.edit_outlined)), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.byIcon(Icons.delete_outline)), findsOneWidget);

    // Expand the card.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);

    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('0/12 done'), findsOneWidget);

    final card = find.byType(TaskCard);

    // The subtask dropdown no longer has its own scroll: there is no
    // nested ListView, and all subtask rows render in full.
    expect(
      find.descendant(of: card, matching: find.byType(ListView)),
      findsNothing,
    );
    for (var i = 1; i <= 12; i++) {
      expect(find.text('Subtask $i'), findsOneWidget);
    }

    // The expanded card's content overflows its fixed grid cell, so the
    // whole card scrolls as a single unit.
    final cardScrollable =
        find.descendant(of: card, matching: find.byType(Scrollable));
    final position = tester.state<ScrollableState>(cardScrollable).position;
    expect(position.maxScrollExtent, greaterThan(0));

    final cardRect = tester.getRect(card);
    expect(tester.getRect(find.text('Subtask 12')).top,
        greaterThan(cardRect.bottom));

    // Scrolling the card itself brings the lower subtasks into view.
    await tester.drag(card, const Offset(0, -300));
    await tester.pump();

    expect(position.pixels, greaterThan(0));
    expect(tester.getRect(find.text('Subtask 12')).top,
        lessThan(cardRect.bottom));
  });

  testWidgets('clicking subtasks toggles them and completes the task when all are done',
      (tester) async {
    late int taskId;
    await tester.runAsync(() async {
      taskId = await testDb.insert('tasks', {
        'title': 'Checklist task',
        'priority': 'Medium',
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
      for (var i = 1; i <= 2; i++) {
        await testDb.insert('subtasks', {
          'task_id': taskId,
          'title': 'Step $i',
          'is_completed': 0,
          'sort_order': i,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    // Expand the card to reveal the subtask dropdown.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await settle(tester);
    expect(find.text('0/2 done'), findsOneWidget);

    // Click the first subtask: it checks off, task stays pending.
    await tester.tap(find.text('Step 1'));
    await settle(tester);
    expect(find.text('1/2 done'), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.text('Pending')), findsOneWidget);

    // Click the second subtask: task auto-completes.
    await tester.tap(find.text('Step 2'));
    await settle(tester);
    expect(find.text('2/2 done'), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.text('Completed')), findsOneWidget);

    // Un-checking one subtask reopens the completed task (as In Progress).
    await tester.tap(find.text('Step 1'));
    await settle(tester);
    expect(find.text('1/2 done'), findsOneWidget);
    expect(find.descendant(of: find.byType(TaskCard), matching: find.text('In Progress')), findsOneWidget);

    // The toggles were persisted.
    final rows = await tester.runAsync(
        () => testDb.query('subtasks', where: 'task_id = ?', whereArgs: [taskId]));
    final completed =
        rows!.where((r) => (r['is_completed'] as int) == 1).length;
    expect(completed, 1);
  });

  testWidgets('task card uses the category assigned color, preset or custom',
      (tester) async {
    await tester.runAsync(() async {
      // Preset key ('indigo') and a custom hex from the color wheel.
      final indigoId = await testDb.insert('categories', {
        'name': 'IndigoCat',
        'color': 'indigo',
        'sort_order': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      final customId = await testDb.insert('categories', {
        'name': 'CustomCat',
        'color': '#FF5733',
        'sort_order': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final (title, catId) in [
        ('Indigo task', indigoId),
        ('Custom task', customId),
      ]) {
        await testDb.insert('tasks', {
          'title': title,
          'category_id': catId,
          'priority': 'Medium',
          'status': 'Pending',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });

    await bootApp(tester);
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    // Container(color: ...) keeps the color in its `color` field (painted
    // via an internal ColoredBox in current Flutter), so match on that.
    Finder accentBar(Color expected) => find.byWidgetPredicate((w) =>
        w is Container &&
        w.constraints?.maxWidth == 5 &&
        w.color == expected);

    // The accent stripe reflects the assigned preset color.
    expect(accentBar(const Color(0xFF6366F1)), findsOneWidget);
    // And the custom hex color picked from the color wheel.
    expect(accentBar(const Color(0xFFFF5733)), findsOneWidget);
    // The category pill is painted with the custom color too.
    final pill = find
        .ancestor(of: find.text('CustomCat'), matching: find.byType(Container))
        .first;
    final pillBox =
        tester.widget<Container>(pill).decoration as BoxDecoration;
    expect(pillBox.color, const Color(0xFFFF5733));
  });
}
