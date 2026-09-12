import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/task.dart';
import 'package:taskflow/providers/tasks_provider.dart';
import 'package:taskflow/services/notification_service.dart';

import '../database/test_helpers.dart';

/// In-memory [NotificationService] that records completion toasts so the
/// provider's behavior can be asserted without the Windows toast plugin.
class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService({bool completionEnabled = true}) {
    _completionEnabled = completionEnabled;
  }

  late bool _completionEnabled;
  final List<String> completedTitles = [];

  @override
  Future<bool> get completionEnabled async => _completionEnabled;

  @override
  Future<void> setCompletionEnabled(bool value) async {
    _completionEnabled = value;
  }

  @override
  Future<void> showTaskCompletedToast(Task task) async {
    completedTitles.add(task.title);
  }
}

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

  TasksProvider buildProvider(_RecordingNotificationService notifications) {
    final provider = TasksProvider(notifications: notifications);
    provider.initialize();
    return provider;
  }

  /// Flushes microtasks so the unawaited completion toasts have landed.
  Future<void> pumpToasts() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('completeTask fires a completion toast', () async {
    final notifications = _RecordingNotificationService();
    final provider = buildProvider(notifications);

    final saved =
        await provider.createTask(Task(title: 'Write the report'));
    await provider.completeTask(saved);
    await pumpToasts();

    expect(notifications.completedTitles, ['Write the report']);

    provider.dispose();
  });

  test('completeTasks fires one toast per completed task', () async {
    final notifications = _RecordingNotificationService();
    final provider = buildProvider(notifications);

    final a = await provider.createTask(Task(title: 'First'));
    final b = await provider.createTask(Task(title: 'Second'));
    await provider.completeTasks([a, b]);
    await pumpToasts();

    expect(notifications.completedTitles, ['First', 'Second']);

    provider.dispose();
  });

  test('completion toast respects the disabled setting', () async {
    final notifications = _RecordingNotificationService(
        completionEnabled: false);
    final provider = buildProvider(notifications);

    final saved = await provider.createTask(Task(title: 'Silent'));
    await provider.completeTask(saved);
    await pumpToasts();

    expect(notifications.completedTitles, isEmpty);

    provider.dispose();
  });

  test('reopening then re-completing fires the toast again', () async {
    final notifications = _RecordingNotificationService();
    final provider = buildProvider(notifications);

    final saved = await provider.createTask(Task(title: 'Repeatable'));
    await provider.completeTask(saved);
    await pumpToasts();
    await provider.reopenTask(saved);
    await provider.completeTask(saved);
    await pumpToasts();

    expect(notifications.completedTitles,
        ['Repeatable', 'Repeatable']);

    provider.dispose();
  });
}
