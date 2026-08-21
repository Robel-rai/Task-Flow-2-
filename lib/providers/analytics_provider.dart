import '../core/app_change_notifier.dart';

import '../core/event_bus.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../services/analytics_service.dart';

/// Cached dashboard/analytics aggregates.
///
/// Computed lazily on init and after data-mutating events (never on every
/// frame or rebuild). Carries the dashboard aggregates plus the Phase 5
/// [AnalyticsSummary] (streaks, focus time, productivity score).
class AnalyticsProvider extends AppChangeNotifier {
  AnalyticsProvider({TaskRepository? tasks, AnalyticsService? analytics})
      : _tasks = tasks ?? TaskRepository(),
        _analytics = analytics ?? AnalyticsService();

  final TaskRepository _tasks;
  final AnalyticsService _analytics;

  int _totalTasks = 0;
  int get totalTasks => _totalTasks;

  int _completedTasks = 0;
  int get completedTasks => _completedTasks;

  int _pendingTasks = 0;
  int get pendingTasks => _pendingTasks;

  double _hoursLogged = 0;
  double get hoursLogged => _hoursLogged;

  double get efficiencyRate =>
      _totalTasks > 0 ? (_completedTasks / _totalTasks) * 100 : 0;

  Map<String, int> _categoryDistribution = {};
  Map<String, int> get categoryDistribution => _categoryDistribution;

  Map<int, int> _weeklyCompletionCounts = {};
  Map<int, int> get weeklyCompletionCounts => _weeklyCompletionCounts;

  List<Task> _recentTasks = [];
  List<Task> get recentTasks => _recentTasks;

  List<Task> _todayTasks = [];
  List<Task> get todayTasks => _todayTasks;

  AnalyticsSummary? _summary;
  AnalyticsSummary? get summary => _summary;

  void initialize() {
    refresh();
    final bus = EventBus.instance;
    for (final event in const [
      AppEvent.taskCreated,
      AppEvent.taskUpdated,
      AppEvent.taskCompleted,
      AppEvent.taskReopened,
      AppEvent.taskDeleted,
      AppEvent.taskTrashed,
      AppEvent.taskRestored,
      AppEvent.projectStatusChanged,
      AppEvent.focusSessionStarted,
      AppEvent.focusSessionStopped,
      AppEvent.dataReset,
    ]) {
      bus.subscribe(event, refresh);
    }
  }

  Future<void> refresh() async {
    try {
      _totalTasks = await _tasks.countAll();
      _completedTasks = await _tasks.countByStatus('Completed');
      _pendingTasks = await _tasks.countByStatus('Pending');
      _hoursLogged = (await _tasks.totalTimeSpentSeconds()) / 3600.0;
      _categoryDistribution = await _tasks.categoryDistribution();
      _weeklyCompletionCounts =
          await _tasks.completionCountsForWeek(DateTime.now());
      _recentTasks =
          (await _tasks.getAll(sortBy: 'created_at', ascending: false))
              .take(5)
              .toList();
      _todayTasks = await _tasks.getForDate(DateTime.now());
      _summary = await _analytics.loadSummary();
      safeNotify();
    } on Exception {
      // The database may be closing (app shutdown, test teardown) while a
      // refresh is in flight. Keep the stale cached aggregates instead of
      // crashing the widget tree.
    }
  }
}
