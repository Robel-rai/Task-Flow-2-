import '../core/app_change_notifier.dart';
import 'package:intl/intl.dart';

import '../core/event_bus.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

enum CalendarViewMode { month, week, day, agenda }

/// Owns calendar navigation state and the tasks shown for the selected
/// month/week/day. Refreshes its caches on task events.
class CalendarProvider extends AppChangeNotifier {
  CalendarProvider({TaskRepository? tasks}) : _tasks = tasks ?? TaskRepository();

  final TaskRepository _tasks;

  DateTime _viewingMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get viewingMonth => _viewingMonth;

  DateTime _selectedDate = DateTime.now();
  DateTime get selectedDate => _selectedDate;

  CalendarViewMode _viewMode = CalendarViewMode.month;
  CalendarViewMode get viewMode => _viewMode;

  List<Task> _selectedDayTasks = [];
  List<Task> get selectedDayTasks => _selectedDayTasks;

  Map<String, List<Task>> _monthTasks = {};
  Map<String, List<Task>> get monthTasks => _monthTasks;

  List<Task> _weekTasks = [];
  List<Task> get weekTasks => _weekTasks;

  /// Sunday-start day of the week containing [_selectedDate].
  DateTime get weekStart {
    final day = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day);
    return day.subtract(Duration(days: day.weekday % 7));
  }

  /// All of the viewing month's tasks, sorted chronologically
  /// (date, then scheduled time) for the agenda view.
  List<Task> get agendaTasks {
    final all = <Task>[
      for (final list in _monthTasks.values) ...list,
    ];
    all.sort((a, b) {
      final da = a.scheduledDate!;
      final db = b.scheduledDate!;
      final byDate = da.compareTo(db);
      if (byDate != 0) return byDate;
      return (a.scheduledTime ?? '').compareTo(b.scheduledTime ?? '');
    });
    return all;
  }

  void initialize() {
    selectDate(_selectedDate);
    loadMonth();
    // Refresh both caches when tasks change anywhere in the app.
    final bus = EventBus.instance;
    for (final event in const [
      AppEvent.taskCreated,
      AppEvent.taskUpdated,
      AppEvent.taskCompleted,
      AppEvent.taskReopened,
      AppEvent.taskDeleted,
      AppEvent.taskRescheduled,
      AppEvent.taskTrashed,
      AppEvent.taskRestored,
      AppEvent.dataReset,
    ]) {
      bus.subscribe(event, _reload);
    }
  }

  void _reload() {
    selectDate(_selectedDate);
    loadMonth();
    loadWeek();
  }

  Future<void> setViewingMonth(DateTime month) async {
    _viewingMonth = DateTime(month.year, month.month);
    safeNotify();
    await loadMonth();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedDayTasks = await _tasks.getForDate(_selectedDate);
    // Keep the viewing month in sync so cross-month day navigation and
    // the agenda view always match.
    if (_selectedDate.year != _viewingMonth.year ||
        _selectedDate.month != _viewingMonth.month) {
      _viewingMonth =
          DateTime(_selectedDate.year, _selectedDate.month);
      await loadMonth();
    }
    safeNotify();
  }

  Future<void> loadMonth() async {
    final start = DateTime(_viewingMonth.year, _viewingMonth.month, 1);
    final end = DateTime(_viewingMonth.year, _viewingMonth.month + 1, 0);
    final tasks = await _tasks.getInRange(start, end);
    final map = <String, List<Task>>{};
    for (final task in tasks) {
      if (task.scheduledDate == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(task.scheduledDate!);
      map.putIfAbsent(key, () => []).add(task);
    }
    _monthTasks = map;
    safeNotify();
  }

  /// Loads the seven days (Sunday-start) around [_selectedDate].
  Future<void> loadWeek() async {
    final start = weekStart;
    final end = start.add(const Duration(days: 6));
    _weekTasks = await _tasks.getInRange(start, end);
    safeNotify();
  }

  void setViewMode(CalendarViewMode mode) {
    _viewMode = mode;
    if (mode == CalendarViewMode.week) {
      loadWeek();
    }
    safeNotify();
  }

  /// Steps the visible range backward/forward depending on the active
  /// view mode (month/agenda: a month; week: a week; day: a day).
  Future<void> navigate(int direction) async {
    switch (_viewMode) {
      case CalendarViewMode.month:
      case CalendarViewMode.agenda:
        await setViewingMonth(
            DateTime(_viewingMonth.year, _viewingMonth.month + direction));
      case CalendarViewMode.week:
        await selectDate(_selectedDate.add(Duration(days: 7 * direction)));
        await loadWeek();
      case CalendarViewMode.day:
        await selectDate(_selectedDate.add(Duration(days: direction)));
    }
  }

  /// Jumps to today in the current view.
  Future<void> goToToday() async {
    final now = DateTime.now();
    await setViewingMonth(DateTime(now.year, now.month));
    await selectDate(now);
    await loadWeek();
  }
}
