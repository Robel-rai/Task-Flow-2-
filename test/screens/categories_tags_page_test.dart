import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/tag.dart';
import 'package:taskflow/repositories/tag_repository.dart';
import 'package:taskflow/widgets/tag_pill.dart';

import '../database/test_helpers.dart';

void main() {
  late Database testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {'onboarding_complete': true, 'user_name': 'Test User'});
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

    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await tester.tap(find.text('Categories and Tags'));
    await tester.pump();
    await settle(tester);
  }

  testWidgets('tags section shows created tags as pills and can add one',
      (tester) async {
    await tester.runAsync(() async {
      await TagRepository().insert(Tag(name: 'urgent'));
    });
    await bootApp(tester);

    expect(find.text('Tags'), findsOneWidget);
    expect(find.byType(TagPill), findsOneWidget);
    expect(find.text('urgent'), findsOneWidget);

    // Add a tag via the dialog (name only — no color picker).
    await tester.tap(find.text('Add tag'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Color'), findsNothing); // colors are gone

    await tester.enterText(
        find.descendant(
            of: find.byType(Dialog), matching: find.byType(TextField)),
        'follow-up');
    await tester.tap(find.text('Create Tag'));
    await settle(tester);

    expect(find.byType(TagPill), findsNWidgets(2));
    expect(find.text('follow-up'), findsOneWidget);
  });

  testWidgets('deleting a tag from the page removes it and its task links',
      (tester) async {
    await tester.runAsync(() async {
      final tagId = await TagRepository().insert(Tag(name: 'temp-tag'));
      await testDb.insert('tasks', {
        'title': 'Linked task',
        'created_at': DateTime.now().toIso8601String(),
      });
      final task = await testDb
          .query('tasks', where: 'title = ?', whereArgs: ['Linked task']);
      await testDb
          .insert('task_tags', {'task_id': task.first['id'], 'tag_id': tagId});
    });
    await bootApp(tester);

    // Tap the ✕ inside the pill.
    await tester.tap(find.descendant(
        of: find.byType(TagPill), matching: find.byIcon(Icons.close)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.text('temp-tag'), findsNothing);

    await tester.runAsync(() async {
      // The tag and its task_tags link are both gone.
      expect(await testDb.query('tags', where: "name = 'temp-tag'"), isEmpty);
      expect(await testDb.query('task_tags'), isEmpty);
    });
  });

  testWidgets('deleting a tag clears an active tag filter on Tasks',
      (tester) async {
    await tester.runAsync(() async {
      final tagId = await TagRepository().insert(Tag(name: 'filtered'));
      await testDb.insert('tasks', {
        'title': 'Some task',
        'created_at': DateTime.now().toIso8601String(),
      });
      final task = await testDb
          .query('tasks', where: 'title = ?', whereArgs: ['Some task']);
      await testDb
          .insert('task_tags', {'task_id': task.first['id'], 'tag_id': tagId});
    });
    await bootApp(tester);

    // Go to Tasks and activate the tag filter via the filter panel.
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await settle(tester);

    // Open the unified filter panel and pick the 'filtered' tag chip.
    await tester.tap(find.text('Filters'));
    await settle(tester);
    await tester.tap(find.text('filtered').last);
    await settle(tester);

    // The filter is active — close the panel by tapping outside it
    // (the ✕ has no tooltip: tooltips crash inside the anchored
    // overlay). The barrier would otherwise swallow nav taps.
    await tester.tapAt(const Offset(700, 500));
    await settle(tester);

    // Back to the settings page (still open underneath) and delete the tag.
    await tester.tap(find.text('Settings').first);
    await tester.pump();
    await settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(TagPill), matching: find.byIcon(Icons.close)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Delete'));
    await settle(tester);

    // Back to Tasks: the filter was cleared with the tag, so the task
    // shows again and no tag chip or summary chip remains.
    await tester.tap(find.text('Tasks').first);
    await tester.pump();
    await settle(tester);

    expect(find.text('filtered'), findsNothing);
    expect(find.text('Tag filter active'), findsNothing);
    expect(find.text('Some task'), findsOneWidget);
  });
}
