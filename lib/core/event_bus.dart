import 'package:flutter/foundation.dart';

/// Application-level events used to invalidate caches across providers.
///
/// Providers emit events after mutating data; other providers (e.g.
/// Analytics) subscribe and refresh lazily. This replaces v1's pattern
/// of refreshing everything after every mutation.
enum AppEvent {
  taskCreated,
  taskUpdated,
  taskCompleted,
  taskReopened,
  taskDeleted,
  taskTrashed,
  taskRestored,
  taskRescheduled,
  subtaskToggled,
  timerStarted,
  timerStopped,
  projectCreated,
  projectUpdated,
  projectDeleted,
  projectStatusChanged,
  routineCreated,
  routineUpdated,
  routineDeleted,
  routineCompleted,
  focusSessionStarted,
  focusSessionStopped,
  categoriesChanged,
  dataReset,
}

/// Simple singleton pub/sub for [AppEvent]s.
class EventBus {
  EventBus._();

  static final EventBus instance = EventBus._();

  final Map<AppEvent, List<VoidCallback>> _listeners = {};

  void subscribe(AppEvent event, VoidCallback callback) {
    _listeners.putIfAbsent(event, () => []).add(callback);
  }

  void unsubscribe(AppEvent event, VoidCallback callback) {
    _listeners[event]?.remove(callback);
  }

  void emit(AppEvent event) {
    for (final callback in List<VoidCallback>.of(_listeners[event] ?? const [])) {
      callback();
    }
  }

  /// Emits several events at once (e.g. a completion that also changes
  /// a project's status).
  void emitAll(Iterable<AppEvent> events) {
    for (final event in events) {
      emit(event);
    }
  }
}
