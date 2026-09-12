import '../core/app_change_notifier.dart';

import '../core/event_bus.dart';
import '../models/focus_session.dart';
import '../repositories/focus_session_repository.dart';
import '../services/focus_service.dart';
import '../services/ui_sound_service.dart';

/// Owns the active focus session and today's session history.
class FocusProvider extends AppChangeNotifier {
  FocusProvider({FocusService? service, FocusSessionRepository? sessions})
      : _service = service ?? FocusService(),
        _sessions = sessions ?? FocusSessionRepository();

  final FocusService _service;
  final FocusSessionRepository _sessions;
  final UiSoundService _sounds = UiSoundService.instance;

  FocusSession? _activeSession;
  FocusSession? get activeSession => _activeSession;

  List<FocusSession> _todaySessions = [];
  List<FocusSession> get todaySessions => _todaySessions;

  int _todaySeconds = 0;
  int get todaySeconds => _todaySeconds;

  // ─── Session-log date range (defaults to today) ───
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? get rangeStart => _rangeStart;
  DateTime? get rangeEnd => _rangeEnd;

  List<FocusSession> _visibleSessions = [];
  List<FocusSession> get visibleSessions => _visibleSessions;

  int _visibleSeconds = 0;
  int get visibleSeconds => _visibleSeconds;

  Future<void> initialize() async {
    await refreshToday();
    // Default the visible range to today without re-querying — the data
    // was just loaded by refreshToday(). (setDateRange still queries
    // whenever the user picks a different range.)
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, now.day);
    _rangeEnd = DateTime(now.year, now.month, now.day);
    _visibleSessions = List.of(_todaySessions);
    _visibleSeconds = _todaySeconds;
    safeNotify();
    EventBus.instance.subscribe(AppEvent.dataReset, _handleDataReset);
  }

  Future<void> _handleDataReset() async {
    await refreshToday();
    await _refreshVisible();
  }

  Future<void> refreshToday() async {
    _todaySessions = await _sessions.getForDate(DateTime.now());
    FocusSession? running;
    for (final session in _todaySessions) {
      if (session.isRunning) {
        running = session;
        break;
      }
    }
    _activeSession = running;
    _todaySeconds = await _sessions.totalSeconds(date: DateTime.now());
    safeNotify();
  }

  /// Sets the session-log date range (null = all dates) and reloads the
  /// sessions shown on the Focus page. Defaults to today on startup.
  Future<void> setDateRange(DateTime? start, DateTime? end) async {
    _rangeStart = start;
    _rangeEnd = end;
    await _refreshVisible();
  }

  Future<void> _refreshVisible() async {
    _visibleSessions = await _sessions.getForRange(_rangeStart, _rangeEnd);
    _visibleSeconds =
        await _sessions.totalSecondsForRange(_rangeStart, _rangeEnd);
    safeNotify();
  }

  /// Permanently deletes every recorded focus session. A running session
  /// is stopped first so its task timer is banked instead of left running.
  Future<void> clearAllSessions() async {
    await stop(); // no-op when nothing is running
    await _sessions.clearAll();
    EventBus.instance.emit(AppEvent.dataReset);
    await refreshToday();
    await _refreshVisible();
  }

  Future<FocusSession> start({int? taskId}) async {
    final session = await _service.start(taskId: taskId);
    EventBus.instance.emit(AppEvent.focusSessionStarted);
    _sounds.focusStarted();
    await refreshToday();
    await _refreshVisible();
    return session;
  }

  Future<FocusSession?> stop() async {
    final session = _activeSession;
    if (session == null) return null;
    final stopped = await _service.stop(session);
    EventBus.instance.emit(AppEvent.focusSessionStopped);
    _sounds.focusStopped();
    await refreshToday();
    await _refreshVisible();
    return stopped;
  }

  /// Stops the session because its target duration was reached — plays
  /// the dedicated completion cue instead of the early-stop one.
  Future<FocusSession?> complete() async {
    final session = _activeSession;
    if (session == null) return null;
    final stopped = await _service.stop(session);
    EventBus.instance.emit(AppEvent.focusSessionStopped);
    _sounds.focusCompleted();
    await refreshToday();
    await _refreshVisible();
    return stopped;
  }

  /// Pauses the active session (time freezes; the session stays active).
  Future<FocusSession?> pause() async {
    final session = _activeSession;
    if (session == null) return null;
    final paused = await _service.pause(session);
    _sounds.focusPaused();
    await refreshToday();
    await _refreshVisible();
    return paused;
  }

  /// Resumes the active paused session.
  Future<FocusSession?> resume() async {
    final session = _activeSession;
    if (session == null || !session.isPaused) return null;
    final resumed = await _service.resume(session);
    _sounds.focusResumed();
    await refreshToday();
    await _refreshVisible();
    return resumed;
  }
}
