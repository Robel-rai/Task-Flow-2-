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
    await tester.tap(find.text('Routines').first);
    await tester.pump();
  }

  testWidgets('create a routine and complete it from today\'s checklist',
      (tester) async {
    await bootApp(tester);

    expect(find.text('No routines yet — create your first habit.'),
        findsOneWidget);

    // Open the dialog and fill it in (defaults: 8:00 AM, every day).
    await tester.tap(find.text('New Routine'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
        find
            .descendant(
                of: find.byType(Dialog), matching: find.byType(TextField))
            .first,
        'Morning run');

    await tester.tap(find.text('Create Routine'));
    await settle(tester);

    // Lands in both today's checklist and the full schedule.
    expect(find.text('Morning run'), findsNWidgets(2));
    expect(find.text('0 of 1 done today'), findsOneWidget);
    expect(find.text('8:00 AM'), findsWidgets);

    // Complete it from the checklist row (first unchecked circle).
    await tester.tap(find.byIcon(Icons.radio_button_unchecked).first);
    await settle(tester);

    expect(find.text('1 of 1 done today'), findsOneWidget);
    expect(find.text('Best streak: 1'), findsOneWidget);
    expect(find.text('1 day streak'), findsOneWidget);
  });

  testWidgets(
      'routines grouped by time of day as 4:3 cards with descriptions and streaks',
      (tester) async {
    // Seed routines across all four time buckets, each with a description
    // and its own streak.
    await tester.runAsync(() async {
      final now = DateTime.now().toIso8601String();
      for (final (title, time, desc, streak) in [
        ('Morning jog', '06:30', 'Run 5k before work', 12),
        ('Brush teeth', '07:15', 'Two minutes, take your time', 3),
        ('Lunch break', '12:30', 'Eat something green', 1),
        ('Afternoon standup', '15:00', 'Team sync', 5),
        ('Evening reading', '19:30', 'Read 30 pages', 2),
      ]) {
        await testDb.insert('routines', {
          'title': title,
          'description': desc,
          'scheduled_time': time,
          'days_of_week': '1,2,3,4,5,6,7',
          'color': 'primary',
          'streak': streak,
          'is_completed_today': 0,
          'notification_enabled': 1,
          'created_at': now,
        });
      }
    });

    await bootApp(tester);

    // Each group header shows once in Today's Checklist and once in All
    // Routines.
    expect(find.text('Morning'), findsNWidgets(2));
    expect(find.text('Noon'), findsNWidgets(2));
    expect(find.text('Afternoon'), findsNWidgets(2));
    expect(find.text('Evening'), findsNWidgets(2));

    // Descriptions render on the today cards.
    expect(find.text('Run 5k before work'), findsOneWidget);
    expect(find.text('Eat something green'), findsOneWidget);
    expect(find.text('Read 30 pages'), findsOneWidget);

    // Today cards are 4:3.
    final jogCard = find.byKey(const ValueKey('today-card-1'));
    final jogSize = tester.getSize(jogCard);
    expect(jogSize.width / jogSize.height, closeTo(4 / 3, 0.02));

    // Each card carries its own streak counter.
    expect(
      find.descendant(
          of: jogCard,
          matching: find.byIcon(Icons.local_fire_department)),
      findsOneWidget,
    );
    expect(find.descendant(of: jogCard, matching: find.text('12')),
        findsOneWidget);

    // Morning group is sorted by scheduled time: 06:30 before 07:15.
    final teethCard = find.byKey(const ValueKey('today-card-2'));
    expect(tester.getTopLeft(jogCard).dx,
        lessThan(tester.getTopLeft(teethCard).dx));
  });
}
