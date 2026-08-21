/// A recorded deep-work (pomodoro) session.
///
/// While active, [startedAt] is the start of the *current running segment*
/// (it is reset on pause/resume) and [durationSeconds] is the time
/// accumulated before that segment. [pausedAt] non-null means the session
/// is active but paused (time is frozen); [endedAt] non-null means done.
class FocusSession {
  final int? id;
  final int? taskId; // null = unfocused session
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? pausedAt;
  final int durationSeconds;
  final String sessionType; // pomodoro | manual
  final DateTime createdAt;

  FocusSession({
    this.id,
    this.taskId,
    required this.startedAt,
    this.endedAt,
    this.pausedAt,
    this.durationSeconds = 0,
    this.sessionType = 'pomodoro',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// True while the session is active (running *or* paused).
  bool get isRunning => endedAt == null;

  /// True when the session is paused (active but not counting).
  bool get isPaused => pausedAt != null && endedAt == null;

  /// Duration including the live running time (excluding paused time).
  int get currentDurationSeconds {
    if (endedAt != null || pausedAt != null) return durationSeconds;
    return durationSeconds + DateTime.now().difference(startedAt).inSeconds;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'paused_at': pausedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'session_type': sessionType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'] as int?,
      taskId: map['task_id'] as int?,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.tryParse(map['ended_at'] as String)
          : null,
      pausedAt: map['paused_at'] != null
          ? DateTime.tryParse(map['paused_at'] as String)
          : null,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      sessionType: (map['session_type'] as String?) ?? 'pomodoro',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  FocusSession copyWith({
    int? id,
    int? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? pausedAt,
    int? durationSeconds,
    String? sessionType,
    DateTime? createdAt,
    bool clearEndedAt = false,
    bool clearPausedAt = false,
  }) {
    return FocusSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      sessionType: sessionType ?? this.sessionType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
