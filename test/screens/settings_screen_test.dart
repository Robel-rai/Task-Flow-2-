import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/widgets/color_wheel_picker.dart';

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

  /// Navigates to Settings and opens the Categories sub-setting.
  Future<void> openCategories(WidgetTester tester) async {
    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await tester.tap(find.text('Categories'));
    await tester.pump();
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
    await openCategories(tester);
  }

  Finder categoryRow(String name) =>
      find.widgetWithText(ListTile, name);

  Finder rowIcon(String name, IconData icon) => find.descendant(
      of: categoryRow(name), matching: find.byIcon(icon));

  testWidgets('settings has a Categories sub-setting that opens its page',
      (tester) async {
    await bootApp(tester);
    await settle(tester);

    // We're on the Categories page now: header + seeded rows.
    expect(find.text('Categories'), findsOneWidget);
    for (final name in ['General', 'Work', 'Study', 'Health', 'Personal',
        'Development', 'Design']) {
      expect(find.text(name), findsOneWidget);
    }

    // The back arrow returns to the settings home.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('App preferences'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Categories'), findsOneWidget);
  });

  testWidgets('add a new category and see it in the list', (tester) async {
    await bootApp(tester);
    await settle(tester);

    await tester.tap(find.text('Add category'));
    await tester.pump(const Duration(milliseconds: 300));

    final nameField = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(nameField, 'Finance');

    await tester.tap(find.text('Add Category'));
    await settle(tester);

    expect(find.text('Finance'), findsOneWidget);
  });

  testWidgets('add a category with a custom color from the color wheel',
      (tester) async {
    await bootApp(tester);
    await settle(tester);

    await tester.tap(find.text('Add category'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(TextField)),
        'Crimson');

    // Drag on the wheel itself to pick a custom color (dragging toward
    // the rim raises saturation; the exact result is read back below).
    final wheelPaint = find
        .descendant(of: find.byType(ColorWheel),
            matching: find.byType(CustomPaint))
        .first;
    await tester.drag(wheelPaint, const Offset(80, 0));
    await tester.pump();

    // The wheel shows the picked color as a #RRGGBB hex label.
    final hex = tester
        .widget<Text>(find.descendant(of: find.byType(ColorWheel),
            matching: find.textContaining('#')))
        .data!;
    expect(hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
    final expected = Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

    await tester.tap(find.text('Add Category'));
    await settle(tester);

    expect(find.text('Crimson'), findsOneWidget);

    // The custom hex (not a preset key) is persisted…
    await tester.runAsync(() async {
      final rows = await testDb.query('categories',
          where: 'name = ?', whereArgs: ['Crimson']);
      expect(rows.single['color'], hex);
    });

    // …and the row's leading color dot renders it.
    final dot = tester.widget<Container>(find
        .descendant(of: categoryRow('Crimson'), matching: find.byType(Container))
        .first);
    final box = dot.decoration! as BoxDecoration;
    expect(box.color, expected);
  });

  testWidgets('duplicate category name shows an error and is not added',
      (tester) async {
    await bootApp(tester);
    await settle(tester);

    await tester.tap(find.text('Add category'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(TextField)),
        'Work');

    await tester.tap(find.text('Add Category'));
    await settle(tester);

    expect(find.text('A category with that name already exists'),
        findsOneWidget);
    expect(find.text('Work'), findsOneWidget); // still only the seed
  });

  testWidgets('rename a category', (tester) async {
    await bootApp(tester);
    await settle(tester);

    await tester.tap(rowIcon('Work', Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(TextField)),
        'Office');

    await tester.tap(find.text('Save Changes'));
    await settle(tester);

    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Work'), findsNothing);
  });

  testWidgets('deleting a category moves its tasks to General',
      (tester) async {
    await tester.runAsync(() async {
      final studyRows = await testDb.query('categories',
          where: 'name = ?', whereArgs: ['Study']);
      final studyId = studyRows.first['id'] as int;
      await testDb.insert('tasks', {
        'title': 'Read docs',
        'category_id': studyId,
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await bootApp(tester);
    await settle(tester);

    await tester.tap(rowIcon('Study', Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.text('Study'), findsNothing);

    await tester.runAsync(() async {
      final generalRows = await testDb.query('categories',
          where: 'name = ?', whereArgs: ['General']);
      final generalId = generalRows.first['id'] as int;
      final taskRows = await testDb.query('tasks',
          where: 'title = ?', whereArgs: ['Read docs']);
      expect(taskRows.single['category_id'], generalId);
    });
  });

  testWidgets('General cannot be deleted', (tester) async {
    await bootApp(tester);
    await settle(tester);

    final deleteButton = tester.widget<IconButton>(find.ancestor(
        of: rowIcon('General', Icons.delete_outline),
        matching: find.byType(IconButton)));
    expect(deleteButton.onPressed, isNull);

    // Tapping the disabled button must not open a confirm dialog.
    await tester.tap(rowIcon('General', Icons.delete_outline),
        warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete Category'), findsNothing);
    expect(find.text('General'), findsOneWidget);
  });

  testWidgets('deleting the active task-filter category clears the filter',
      (tester) async {
    await bootApp(tester);
    await settle(tester);

    // Go to Tasks and filter by Study.
    await tester.tap(find.text('Tasks').first);
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await settle(tester);
    await tester.tap(find.text('Study').last);
    await settle(tester);

    // The closed field now shows the selected category.
    expect(
        find.descendant(of: find.byType(DropdownButtonFormField<int?>),
            matching: find.text('Study')),
        findsOneWidget);

    // Delete Study from the Categories sub-setting (still open — the
    // settings screen keeps its sub-page state in the IndexedStack).
    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await tester.tap(rowIcon('Study', Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await settle(tester);

    // Back to Tasks: no crash and the filter resets to All.
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await settle(tester);

    expect(
        find.descendant(of: find.byType(DropdownButtonFormField<int?>),
            matching: find.text('All')),
        findsOneWidget);
  });
}
