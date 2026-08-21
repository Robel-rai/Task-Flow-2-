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
    await tester.tap(find.text('Projects').first);
    await tester.pump();
  }

  /// Drags [from] (a widget finder) onto [to] with a real gesture.
  Future<void> dragOnto(
      WidgetTester tester, Finder from, Finder to) async {
    final gesture = await tester.startGesture(tester.getCenter(from));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(to));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await settle(tester);
  }

  testWidgets('create a project, drag tasks across the kanban',
      (tester) async {
    await bootApp(tester);

    expect(find.text('No projects yet'), findsOneWidget);

    // Create a project through the dialog.
    await tester.tap(find.text('New Project'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .first,
        'Website Redesign');
    await tester.tap(find.text('Create Project'));
    await settle(tester);

    expect(find.text('Website Redesign'), findsOneWidget);

    // Seed two tasks straight into the DB, then open the project detail.
    final projectId = (await tester.runAsync(
        () => testDb.query('projects', limit: 1)))!
        .first['id'] as int;
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      await testDb.insert('tasks',
          {'title': 'Design homepage', 'project_id': projectId, 'status': 'Pending', 'created_at': now});
      await testDb.insert('tasks',
          {'title': 'Write copy', 'project_id': projectId, 'status': 'Pending', 'created_at': now});
    });

    await tester.tap(find.text('Website Redesign'));
    await settle(tester);

    // Both tasks sit in the Pending column.
    expect(find.text('Design homepage'), findsOneWidget);
    expect(find.text('Write copy'), findsOneWidget);
    expect(find.text('0 of 2 tasks done'), findsOneWidget);

    // Drag 'Design homepage' onto the In Progress column.
    await dragOnto(
        tester, find.text('Design homepage'), find.text('In Progress'));

    var rows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Design homepage'")))!;
    expect(rows.single['status'], 'In Progress');

    // Drag it all the way to Completed.
    await dragOnto(
        tester, find.text('Design homepage'), find.text('Completed'));

    rows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Design homepage'")))!;
    expect(rows.single['status'], 'Completed');
    expect(find.text('1 of 2 tasks done'), findsOneWidget);

    // Complete the second task too — the project auto-completes.
    await dragOnto(tester, find.text('Write copy'), find.text('Completed'));

    rows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Write copy'")))!;
    expect(rows.single['status'], 'Completed');
    expect(find.text('2 of 2 tasks done'), findsOneWidget);

    // Back to the list: the project shows the Done chip.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
      'double-clicking a kanban card opens details and toggles subtasks',
      (tester) async {
    await bootApp(tester);

    // Create a project through the dialog.
    await tester.tap(find.text('New Project'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .first,
        'Ship v2');
    await tester.tap(find.text('Create Project'));
    await settle(tester);

    // Seed one task (with description) plus two subtasks into the DB.
    final projectId = (await tester.runAsync(
        () => testDb.query('projects', limit: 1)))!
        .first['id'] as int;
    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Write docs',
        'description': 'Document the API',
        'project_id': projectId,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    final taskId = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Write docs'")))!
        .single['id'] as int;
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      for (final (title, order) in [('Intro', 0), ('Reference', 1)]) {
        await testDb.insert('subtasks', {
          'task_id': taskId,
          'title': title,
          'is_completed': 0,
          'sort_order': order,
          'created_at': now,
        });
      }
    });

    // Open the project detail (reloads kanban from the DB).
    await tester.tap(find.text('Ship v2'));
    await settle(tester);
    expect(find.text('Write docs'), findsOneWidget);

    // Double-click the card to open the details popup.
    await tester.tap(find.text('Write docs'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Write docs'));
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    // The popup shows title, description, and subtasks.
    expect(find.text('Document the API'), findsOneWidget);
    expect(find.text('Subtasks'), findsOneWidget);
    expect(find.text('0/2 done'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Reference'), findsOneWidget);

    // Check the first subtask.
    await tester.tap(find.text('Intro'));
    await settle(tester);
    expect(find.text('1/2 done'), findsOneWidget);

    // Check the second — the task auto-completes.
    await tester.tap(find.text('Reference'));
    await settle(tester);
    expect(find.text('2/2 done'), findsOneWidget);

    // Persisted: the task is Completed and the project auto-completes.
    final taskRows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Write docs'")))!;
    expect(taskRows.single['status'], 'Completed');
    final projectRows = (await tester.runAsync(() => testDb
        .query('projects', where: "title = 'Ship v2'")))!;
    expect(projectRows.single['status'], 'Completed');

    // Close the popup; the board refreshed via subtaskToggled and still
    // shows the (now Completed) card.
    await tester.tap(find.text('Close'));
    await settle(tester);
    expect(find.text('Write docs'), findsOneWidget);
  });

  testWidgets('custom kanban columns: add a status and the board scrolls',
      (tester) async {
    await bootApp(tester);

    // Create a project with one task.
    await tester.tap(find.text('New Project'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .first,
        'Kanban Columns');
    await tester.tap(find.text('Create Project'));
    await settle(tester);
    final projectId = (await tester.runAsync(
        () => testDb.query('projects', limit: 1)))!
        .first['id'] as int;
    await tester.runAsync(() async {
      await testDb.insert('tasks', {
        'title': 'Do the thing',
        'project_id': projectId,
        'status': 'Pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    await tester.tap(find.text('Kanban Columns'));
    await settle(tester);

    // Default columns show ('Pending' also appears in the project status
    // pill in the header, so it matches twice).
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    // Open the column manager and add a custom status.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add status'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .last,
        'Blocked');
    await tester.tap(find.text('Add Status'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Blocked'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    // The new column appears on the board.
    expect(find.text('Blocked'), findsOneWidget);

    // The board is horizontally scrollable to reach extra columns.
    final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
    expect(
      scrollables.any((s) => s.axisDirection == AxisDirection.right),
      isTrue,
    );

    // Persisted for this project.
    final rows = (await tester.runAsync(() => testDb
        .query('project_statuses',
            where: 'project_id = ?', whereArgs: [projectId])))!;
    expect(rows.map((r) => r['name']),
        ['Pending', 'In Progress', 'Completed', 'Blocked']);
  });

  testWidgets('deleting a custom status moves its tasks to the first column',
      (tester) async {
    await bootApp(tester);

    // Create a project, then seed custom columns + matching tasks.
    await tester.tap(find.text('New Project'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .first,
        'Reassign');
    await tester.tap(find.text('Create Project'));
    await settle(tester);
    final projectId = (await tester.runAsync(
        () => testDb.query('projects', limit: 1)))!
        .first['id'] as int;
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      for (final (name, order) in [('Todo', 0), ('Blocked', 1), ('Done', 2)]) {
        await testDb.insert('project_statuses', {
          'project_id': projectId,
          'name': name,
          'color': 'blue',
          'sort_order': order,
          'created_at': now,
        });
      }
      for (final title in ['First', 'Blocked task']) {
        await testDb.insert('tasks', {
          'title': title,
          'project_id': projectId,
          'status': title == 'Blocked task' ? 'Blocked' : 'Todo',
          'created_at': now,
        });
      }
    });

    await tester.tap(find.text('Reassign'));
    await settle(tester);

    // Custom columns render on the board.
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Remove the Blocked column and save. Scope to the dialog so the
    // board's 'Blocked' header behind it isn't matched.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump(const Duration(milliseconds: 300));
    final blockedInDialog = find.descendant(
        of: find.byType(Dialog), matching: find.text('Blocked'));
    final blockedRow = find
        .ancestor(of: blockedInDialog, matching: find.byType(Row))
        .first;
    await tester.tap(find
        .descendant(
            of: blockedRow, matching: find.byIcon(Icons.delete_outline)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Save'));
    await settle(tester);

    // The Blocked task was reassigned to the first column.
    final rows = (await tester.runAsync(() => testDb
        .query('tasks', where: "title = 'Blocked task'")))!;
    expect(rows.single['status'], 'Todo');
    expect(find.text('Blocked'), findsNothing);
  });
}
