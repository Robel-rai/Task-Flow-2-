import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';

import '../models/focus_session.dart';
import '../models/routine.dart';
import '../models/task.dart';
import 'focus_service.dart';
import 'ui_sound_service.dart';

/// Notification center: persisted toggles, Windows toasts (best-effort),
/// a per-session break reminder (fires once per session, no leaks),
/// per-day routine reminders (once per routine per day), due-date alerts,
/// pending-task summary alerts, and task-completion confirmations.
class NotificationService {
  NotificationService({bool toasts = true}) : _toasts = toasts;

  final bool _toasts;

  static const prefBreakEnabled = 'notifications_break_enabled';
  static const prefRoutinesEnabled = 'notifications_routines_enabled';
  static const prefDueDateEnabled = 'notifications_duedate_enabled';
  static const prefPendingTasksEnabled = 'notifications_pending_enabled';
  static const prefCompletionEnabled = 'notifications_completion_enabled';
  static const prefPendingStartHour = 'notifications_pending_start_hour';
  static const prefPendingStartMinute = 'notifications_pending_start_minute';
  static const prefPendingIntervalHours = 'notifications_pending_interval_hours';
  static const prefPendingRepeatCount = 'notifications_pending_repeat_count';

  static const prefDueDateStartHour = 'notifications_duedate_start_hour';
  static const prefDueDateStartMinute = 'notifications_duedate_start_minute';
  static const prefDueDateIntervalHours = 'notifications_duedate_interval_hours';
  static const prefDueDateRepeatCount = 'notifications_duedate_repeat_count';
  static const prefDueDateAdvanceMinutes = 'notifications_duedate_advance_minutes';

  WindowsNotification? _toast;
  bool _toastReady = false;

  /// Task ids that already got their due-date reminder (memory only —
  /// a task fires at most once per app session).
  final Set<int> _dueDateReminded = {};

  /// Session ids that already got their break reminder (memory only —
  /// a session lives at most as long as the app does).
  final Set<int> _breakReminded = {};

  // ─── Preference getters / setters ───

  /// Whether the break reminder is enabled. Cached after first read.
  bool? _breakEnabledCache;
  Future<bool> get breakEnabled async {
    if (_breakEnabledCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _breakEnabledCache = prefs.getBool(prefBreakEnabled) ?? true;
    }
    return _breakEnabledCache!;
  }

  /// Whether routine reminders are enabled. Cached after first read.
  bool? _routinesEnabledCache;
  Future<bool> get routinesEnabled async {
    if (_routinesEnabledCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _routinesEnabledCache = prefs.getBool(prefRoutinesEnabled) ?? true;
    }
    return _routinesEnabledCache!;
  }

  /// Whether due-date notification popups are enabled. Cached after first read.
  bool? _dueDateEnabledCache;
  Future<bool> get dueDateEnabled async {
    if (_dueDateEnabledCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _dueDateEnabledCache = prefs.getBool(prefDueDateEnabled) ?? true;
    }
    return _dueDateEnabledCache!;
  }  /// Whether pending-tasks notification popups are enabled. Cached after first read.
  bool? _pendingTasksEnabledCache;
  Future<bool> get pendingTasksEnabled async {
    if (_pendingTasksEnabledCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _pendingTasksEnabledCache =
          prefs.getBool(prefPendingTasksEnabled) ?? true;
    }
    return _pendingTasksEnabledCache!;
  }

  /// Whether task-completion confirmations are enabled. Cached after first read.
  bool? _completionEnabledCache;
  Future<bool> get completionEnabled async {
    if (_completionEnabledCache == null) {
      final prefs = await SharedPreferences.getInstance();
      _completionEnabledCache = prefs.getBool(prefCompletionEnabled) ?? true;
    }
    return _completionEnabledCache!;
  }

  // ─── Pending-task schedule preferences ───

  Future<int> get pendingStartHour async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefPendingStartHour) ?? 8;
  }

  Future<int> get pendingStartMinute async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefPendingStartMinute) ?? 0;
  }

  Future<int> get pendingIntervalHours async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefPendingIntervalHours) ?? 1;
  }

  Future<int> get pendingRepeatCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefPendingRepeatCount) ?? 3;
  }

  Future<void> setPendingSchedule({
    required int startHour,
    required int startMinute,
    required int intervalHours,
    required int repeatCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefPendingStartHour, startHour);
    await prefs.setInt(prefPendingStartMinute, startMinute);
    await prefs.setInt(prefPendingIntervalHours, intervalHours);
    await prefs.setInt(prefPendingRepeatCount, repeatCount);
  }

  Future<void> setBreakEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefBreakEnabled, value);
    _breakEnabledCache = value;
  }

  Future<void> setRoutinesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefRoutinesEnabled, value);
    _routinesEnabledCache = value;
  }

  Future<void> setDueDateEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefDueDateEnabled, value);
    _dueDateEnabledCache = value;
  }

  Future<void> setPendingTasksEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefPendingTasksEnabled, value);
    _pendingTasksEnabledCache = value;
  }

  Future<void> setCompletionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefCompletionEnabled, value);
    _completionEnabledCache = value;
  }

  // ─── Due-date schedule preferences ───

  Future<int> get dueDateStartHour async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefDueDateStartHour) ?? 8;
  }

  Future<int> get dueDateStartMinute async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefDueDateStartMinute) ?? 0;
  }

  Future<int> get dueDateIntervalHours async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefDueDateIntervalHours) ?? 1;
  }

  Future<int> get dueDateRepeatCount async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefDueDateRepeatCount) ?? 3;
  }

  /// Advance reminder offset in minutes. 0 = on time, 60 = 1 hour before,
  /// 1440 = 1 day before.
  Future<int> get dueDateAdvanceMinutes async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefDueDateAdvanceMinutes) ?? 0;
  }

  Future<void> setDueDateSchedule({
    required int startHour,
    required int startMinute,
    required int intervalHours,
    required int repeatCount,
    required int advanceMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefDueDateStartHour, startHour);
    await prefs.setInt(prefDueDateStartMinute, startMinute);
    await prefs.setInt(prefDueDateIntervalHours, intervalHours);
    await prefs.setInt(prefDueDateRepeatCount, repeatCount);
    await prefs.setInt(prefDueDateAdvanceMinutes, advanceMinutes);
  }

  // ─── Due-date schedule check ───

  /// Tracks which due-date schedule slots have already fired today.
  final Set<String> _dueDateSlotsFired = {};

  /// Returns the slot index (0-based) that should fire now for due-date
  /// notifications, or -1 if none.
  Future<int> dueDateScheduleSlotNow({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final startH = await dueDateStartHour;
    final startM = await dueDateStartMinute;
    final rawInterval = await dueDateIntervalHours;
    // intervalHours 0 means 30 minutes (the UI stores 30m as 0)
    final intervalMinutes = rawInterval == 0 ? 30 : rawInterval * 60;
    final count = await dueDateRepeatCount;

    final dayKey = _dayKey(n);

    for (var i = 0; i < count; i++) {
      final slotMinutes = startH * 60 + startM + i * intervalMinutes;
      final slotHour = slotMinutes ~/ 60;
      final slotMin = slotMinutes % 60;

      final slotTime = DateTime(n.year, n.month, n.day, slotHour, slotMin);

      final diff = n.difference(slotTime);
      if (diff.inSeconds >= 0 && diff.inSeconds < 120) {
        final slotKey = '${dayKey}_$i';
        if (!_dueDateSlotsFired.contains(slotKey)) {
          _dueDateSlotsFired.add(slotKey);
          return i;
        }
      }
    }
    return -1;
  }

  // ─── Pending-task schedule check ───

  /// Tracks which schedule slots have already fired today (keyed by date + slot index).
  final Set<String> _pendingSlotsFired = {};

  /// Returns the slot index (0-based) that should fire now, or -1 if none.
  ///
  /// The schedule generates `repeatCount` times starting at `startHour:startMinute`
  /// with `intervalHours` between each. A slot fires when the current time is
  /// within the same minute-resolution window.
  Future<int> pendingScheduleSlotNow({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final startH = await pendingStartHour;
    final startM = await pendingStartMinute;
    final interval = await pendingIntervalHours;
    // intervalHours 0 means 30 minutes (the UI stores 30m as 0)
    final intervalMinutes = interval == 0 ? 30 : interval * 60;
    final count = await pendingRepeatCount;

    final dayKey = _dayKey(n);

    for (var i = 0; i < count; i++) {
      final slotMinutes = startH * 60 + startM + i * intervalMinutes;
      final slotHour = slotMinutes ~/ 60;
      final slotMin = slotMinutes % 60;

      final slotTime = DateTime(n.year, n.month, n.day, slotHour, slotMin);

      // Fire within a 120-second window after the scheduled minute.
      final diff = n.difference(slotTime);
      if (diff.inSeconds >= 0 && diff.inSeconds < 120) {
        final slotKey = '${dayKey}_$i';
        if (!_pendingSlotsFired.contains(slotKey)) {
          _pendingSlotsFired.add(slotKey);
          return i;
        }
      }
    }
    return -1;
  }

  // ─── Due-date check ───

  /// Returns the list of tasks whose due date (adjusted by advance offset)
  /// has arrived and which have not yet been reminded in this session,
  /// gated by the schedule. Each task is returned at most once per session.
  Future<List<Task>> checkDueTasks(List<Task> allTasks, {DateTime? now}) async {
    if (!await dueDateEnabled) return [];
    final now_ = now ?? DateTime.now();

    // Check schedule slot
    final slotIndex = await dueDateScheduleSlotNow(now: now_);
    if (slotIndex < 0) return [];

    final advanceMin = await dueDateAdvanceMinutes;
    final due = <Task>[];
    for (final task in allTasks) {
      if (task.id == null) continue;
      if (_dueDateReminded.contains(task.id)) continue;
      if (task.status == 'Completed') continue;
      if (task.dueDate == null) continue;
      final dueAt = task.dueDate!.subtract(Duration(minutes: advanceMin));
      if (now_.isAfter(dueAt) || now_.isAtSameMomentAs(dueAt)) {
        _dueDateReminded.add(task.id!);
        due.add(task);
      }
    }
    return due;
  }

  /// Marks a task as reminded without triggering a popup (used by test button).
  void markTaskReminded(int taskId) {
    _dueDateReminded.add(taskId);
  }

  // ─── Existing checks ───

  /// True exactly once per session when the break threshold is met — the
  /// caller shows the in-app UI. Subsequent calls for the same session
  /// (and sessions under the threshold) return false.
  Future<bool> shouldShowBreakReminder(FocusSession session) async {
    final id = session.id;
    if (id == null) return false;
    if (_breakReminded.contains(id)) return false;
    if (!FocusService.breakThresholdMet(session)) return false;
    if (!await breakEnabled) return false;
    _breakReminded.add(id);
    return true;
  }

  /// True once per routine per day when its reminder is due — the caller
  /// shows the UI. Persisted so a restart doesn't re-fire it.
  Future<bool> shouldShowRoutineReminder(Routine routine,
      {DateTime? now}) async {
    if (!await routinesEnabled) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = 'routine_notified_${routine.id}_${_dayKey(now ?? DateTime.now())}';
    if (prefs.getBool(key) ?? false) return false;
    await prefs.setBool(key, true);
    return true;
  }

  // ─── Windows toasts ───

  /// Best-effort Windows toast; silently ignored when unavailable
  /// (non-Windows, tests, disabled notifications).
  Future<void> showToast({required String title, required String body}) async {
    if (!_toasts || !Platform.isWindows) return;
    try {
      if (!_toastReady) {
        _toast = WindowsNotification(applicationId: 'TaskFlow.App');
        _toastReady = true;
      }
      final id = 'toast_${DateTime.now().microsecondsSinceEpoch}';
      await _toast!.showNotificationPluginTemplate(
        NotificationMessage.fromPluginTemplate(id, title, body),
      );
    } catch (_) {
      // Toasts must never crash the app.
    }
  }

  /// Sends a due-date toast for [task].
  Future<void> showDueDateToast(Task task) async {
    final dueStr = task.dueDate != null
        ? '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}'
        : 'now';
    UiSoundService.instance.reminderFired();
    await showToast(
      title: '📋 Task Due: ${task.title}',
      body: 'This task was due on $dueStr. Tap to open TaskFlow.',
    );
  }

  /// Sends a completion confirmation toast for [task].
  Future<void> showTaskCompletedToast(Task task) async {
    await showToast(
      title: '✅ Task Completed: ${task.title}',
      body: 'Nice work! ${task.title} is marked as done.',
    );
  }

  /// Sends a pending-tasks summary toast.
  Future<void> showPendingTasksToast(int count) async {
    UiSoundService.instance.reminderFired();
    await showToast(
      title: '📌 Pending Tasks: $count',
      body: '$count task${count == 1 ? '' : 's'} still pending. Open TaskFlow to review.',
    );
  }

  static String _dayKey(DateTime d) => d.toIso8601String().split('T').first;

  /// Clears fired-slot tracking at midnight so a new day's schedule works.
  void resetSlotsIfNeeded(DateTime now) {
    final today = _dayKey(now);
    if (_pendingSlotsFired.isNotEmpty && !_pendingSlotsFired.any((s) => s.startsWith(today))) {
      _pendingSlotsFired.clear();
    }
    if (_dueDateSlotsFired.isNotEmpty && !_dueDateSlotsFired.any((s) => s.startsWith(today))) {
      _dueDateSlotsFired.clear();
    }
  }
}
