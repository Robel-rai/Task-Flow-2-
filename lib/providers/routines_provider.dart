import 'dart:async';

import '../core/app_change_notifier.dart';

import '../core/event_bus.dart';
import '../models/routine.dart';
import '../repositories/routine_repository.dart';
import '../services/notification_service.dart';
import '../services/routine_service.dart';
import '../services/ui_sound_service.dart';

/// Owns the routine list, applying the daily streak reset on refresh.
class RoutinesProvider extends AppChangeNotifier {
  RoutinesProvider({RoutineService? service, RoutineRepository? repository})
      : _service = service ?? RoutineService(),
        _repository = repository ?? RoutineRepository();

  final RoutineService _service;
  final RoutineRepository _repository;
  final NotificationService _notifications = NotificationService();

  List<Routine> _routines = [];
  List<Routine> get routines => _routines;

  bool _loading = false;
  bool get loading => _loading;

  Timer? _reminderTimer;

  Future<void> initialize() async {
    await refresh();
    EventBus.instance.subscribe(AppEvent.dataReset, refresh);
    // Check for due routine reminders every minute while the app runs.
    _reminderTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => _checkRoutineReminders());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  /// Fires a once-per-day reminder when a routine's scheduled time is due.
  Future<void> _checkRoutineReminders() async {
    final now = DateTime.now();
    for (final routine in _routines) {
      if (!routine.isActiveOn(now)) continue;
      if (routine.isCompletedToday || !routine.notificationEnabled) continue;
      final parts = routine.scheduledTime.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
      if (hour == null || minute == null) continue;
      if (now.hour != hour || now.minute != minute) continue;
      if (await _notifications.shouldShowRoutineReminder(routine, now: now)) {
        UiSoundService.instance.reminderFired();
        await _notifications.showToast(
            title: 'Routine reminder', body: routine.title);
      }
    }
  }

  Future<void> refresh() async {
    _loading = true;
    safeNotify();
    // The reset applies the new-day streak logic to every routine.
    _routines = await _service.resetAll(DateTime.now());
    _loading = false;
    safeNotify();
  }

  Future<Routine> create(Routine routine) async {
    final id = await _repository.insert(routine);
    await refresh();
    EventBus.instance.emit(AppEvent.routineCreated);
    return (await _repository.getById(id))!;
  }

  Future<Routine> update(Routine routine) async {
    await _repository.update(routine);
    await refresh();
    EventBus.instance.emit(AppEvent.routineUpdated);
    return (await _repository.getById(routine.id!))!;
  }

  Future<void> delete(int id) async {
    await _repository.delete(id);
    await refresh();
    EventBus.instance.emit(AppEvent.routineDeleted);
  }

  Future<Routine> toggleCompletion(Routine routine) async {
    final updated = await _service.toggleCompletion(routine);
    await refresh();
    EventBus.instance.emit(AppEvent.routineCompleted);
    return updated;
  }
}
