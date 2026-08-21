import '../models/focus_session.dart';
import '../models/task.dart';
import '../repositories/focus_session_repository.dart';
import '../repositories/task_repository.dart';

/// Manages focus (pomodoro) sessions and their coupling to task timers.
class FocusService {
  FocusService({
    FocusSessionRepository? sessions,
    TaskRepository? tasks,
    DateTime Function()? now,
  })  : _sessions = sessions ?? FocusSessionRepository(),
        _tasks = tasks ?? TaskRepository(),
        _now = now ?? DateTime.now;

  final FocusSessionRepository _sessions;
  final TaskRepository _tasks;
  final DateTime Function() _now;

  /// Default continuous-work threshold before a break reminder (2 hours).
  static const int breakThresholdSeconds = 7200;

  /// Starts a session; if attached to a task, auto-starts the task timer.
  Future<FocusSession> start(
      {int? taskId, String sessionType = 'pomodoro'}) async {
    final now = _now();
    final session = FocusSession(
      taskId: taskId,
      startedAt: now,
      sessionType: sessionType,
    );
    final id = await _sessions.insert(session);

    if (taskId != null) {
      final task = await _tasks.getById(taskId);
      if (task != null && !task.isTimerRunning) {
        await _tasks.update(
            task.copyWith(timerStartedAt: now, status: 'In Progress'));
      }
    }
    return session.copyWith(id: id);
  }

  /// Pauses [session]: freezes the current running segment's time into
  /// [FocusSession.durationSeconds] and marks it paused. The attached
  /// task timer is banked too, so a break doesn't inflate task time.
  Future<FocusSession> pause(FocusSession session) async {
    if (!session.isRunning || session.isPaused) return session;
    final now = _now();
    final elapsed = now.difference(session.startedAt).inSeconds;
    final updated = session.copyWith(
      durationSeconds: session.durationSeconds + elapsed,
      pausedAt: now,
      startedAt: now,
    );
    await _sessions.update(updated);
    if (session.taskId != null) {
      await _bankTaskTimer(session.taskId!, now);
    }
    return updated;
  }

  /// Resumes a paused [session], restarting its running segment and the
  /// attached task timer.
  Future<FocusSession> resume(FocusSession session) async {
    if (!session.isPaused) return session;
    final now = _now();
    final updated = session.copyWith(
      clearPausedAt: true,
      startedAt: now,
    );
    await _sessions.update(updated);
    if (session.taskId != null) {
      final task = await _tasks.getById(session.taskId!);
      if (task != null && !task.isTimerRunning) {
        await _tasks.update(task.copyWith(
          timerStartedAt: now,
          status: 'In Progress',
        ));
      }
    }
    return updated;
  }

  /// Stops [session], persisting its duration, and banks any running
  /// task-timer time into the attached task. Handles sessions stopped
  /// from either the running or paused state.
  Future<FocusSession> stop(FocusSession session) async {
    final now = _now();
    final duration = session.isRunning
        ? session.durationSeconds +
            (session.isPaused
                ? 0
                : now.difference(session.startedAt).inSeconds)
        : session.durationSeconds;
    final updated = session.copyWith(endedAt: now, durationSeconds: duration);
    await _sessions.update(updated);

    if (session.taskId != null) {
      await _bankTaskTimer(session.taskId!, now);
    }
    return updated;
  }

  /// Banks the task's running timer into `time_spent_seconds` and clears
  /// it, so elapsed wall-clock time is accounted exactly once.
  Future<void> _bankTaskTimer(int taskId, DateTime now) async {
    final task = await _tasks.getById(taskId);
    if (task == null || !task.isTimerRunning) return;
    final elapsed = now.difference(task.timerStartedAt!).inSeconds;
    await _tasks.update(task.copyWith(
      timeSpentSeconds: task.timeSpentSeconds + elapsed,
      clearTimerStartedAt: true,
    ));
  }

  /// Whether a running (or just-finished) session hit the break threshold.
  static bool breakThresholdMet(FocusSession session) =>
      session.currentDurationSeconds >= breakThresholdSeconds;

  static bool taskAtBreakThreshold(Task task) =>
      task.currentTimeSpentSeconds >= breakThresholdSeconds;
}
