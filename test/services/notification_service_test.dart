import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow/models/focus_session.dart';
import 'package:taskflow/models/routine.dart';
import 'package:taskflow/services/notification_service.dart';

void main() {
  late NotificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    service = NotificationService(toasts: false);
  });

  test('break reminder fires exactly once per session, at the threshold',
      () async {
    final long = FocusSession(
      id: 1,
      startedAt: DateTime(2026, 8, 14, 8),
      endedAt: DateTime(2026, 8, 14, 10, 5), // 2h 5m
      durationSeconds: 7500,
    );
    final short = FocusSession(
      id: 2,
      startedAt: DateTime(2026, 8, 14, 8),
      endedAt: DateTime(2026, 8, 14, 8, 30),
      durationSeconds: 1800,
    );

    expect(await service.shouldShowBreakReminder(short), isFalse);
    expect(await service.shouldShowBreakReminder(long), isTrue);
    // Same session again → already reminded.
    expect(await service.shouldShowBreakReminder(long), isFalse);
  });

  test('break reminder respects the disabled toggle', () async {
    SharedPreferences.setMockInitialValues(
        {NotificationService.prefBreakEnabled: false});
    service = NotificationService(toasts: false);

    final long = FocusSession(
      id: 1,
      startedAt: DateTime(2026, 8, 14, 8),
      endedAt: DateTime(2026, 8, 14, 10, 5),
      durationSeconds: 7500,
    );
    expect(await service.shouldShowBreakReminder(long), isFalse);
  });

  test('routine reminder fires once per routine per day, then resets',
      () async {
    final routine = Routine(id: 1, title: 'Morning run', scheduledTime: '07:00');

    expect(
      await service.shouldShowRoutineReminder(routine,
          now: DateTime(2026, 8, 14, 7, 0)),
      isTrue,
    );
    // Same day → already notified.
    expect(
      await service.shouldShowRoutineReminder(routine,
          now: DateTime(2026, 8, 14, 7, 30)),
      isFalse,
    );
    // Next day → fires again.
    expect(
      await service.shouldShowRoutineReminder(routine,
          now: DateTime(2026, 8, 15, 7, 0)),
      isTrue,
    );
  });

  test('routine reminder respects the disabled toggle', () async {
    SharedPreferences.setMockInitialValues(
        {NotificationService.prefRoutinesEnabled: false});
    service = NotificationService(toasts: false);

    expect(
      await service.shouldShowRoutineReminder(
          Routine(id: 1, title: 'Read', scheduledTime: '07:00'),
          now: DateTime(2026, 8, 14, 7)),
      isFalse,
    );
  });
}
