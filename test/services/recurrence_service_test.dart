import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/services/recurrence_service.dart';

void main() {
  group('nextOccurrence', () {
    test('daily returns the next day', () {
      final next = RecurrenceService.nextOccurrence(
          'FREQ=DAILY', DateTime(2026, 8, 14));
      expect(next, DateTime(2026, 8, 15));
    });

    test('weekly BYDAY skips to the next matching weekday', () {
      // Friday 2026-08-14 -> next Monday is 08-17.
      final next = RecurrenceService.nextOccurrence(
          'FREQ=WEEKLY;BYDAY=MO,WE', DateTime(2026, 8, 14));
      expect(next, DateTime(2026, 8, 17));
    });

    test('respects the end date', () {
      final next = RecurrenceService.nextOccurrence(
        'FREQ=DAILY',
        DateTime(2026, 8, 14),
        endDate: DateTime(2026, 8, 14),
      );
      expect(next, isNull);
    });

    test('unsupported rule returns null', () {
      expect(
          RecurrenceService.nextOccurrence('FREQ=YEARLY', DateTime(2026, 8, 14)),
          isNull);
    });
  });

  group('instancesInRange', () {
    test('daily expands every day in range', () {
      final dates = RecurrenceService.instancesInRange(
        'FREQ=DAILY',
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
      );
      expect(dates, [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
      ]);
    });

    test('weekly BYDAY expands only matching weekdays', () {
      final dates = RecurrenceService.instancesInRange(
        'FREQ=WEEKLY;BYDAY=MO,WE,FR',
        DateTime(2026, 8, 10), // Monday
        DateTime(2026, 8, 16), // Sunday
      );
      expect(dates, [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 14),
      ]);
    });

    test('anchors monthly to the origin day of month', () {
      final dates = RecurrenceService.instancesInRange(
        'FREQ=MONTHLY',
        DateTime(2026, 8, 1),
        DateTime(2026, 10, 31),
        from: DateTime(2026, 7, 15),
      );
      expect(dates, [
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
        DateTime(2026, 10, 15),
      ]);
    });

    test('monthly clamps the 31st into shorter months', () {
      final dates = RecurrenceService.instancesInRange(
        'FREQ=MONTHLY',
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 30),
        from: DateTime(2026, 1, 31),
      );
      expect(dates, [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('endDate trims occurrences beyond the window', () {
      final dates = RecurrenceService.instancesInRange(
        'FREQ=DAILY',
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 14),
        endDate: DateTime(2026, 8, 12),
      );
      expect(dates, [
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 11),
        DateTime(2026, 8, 12),
      ]);
    });
  });
}
