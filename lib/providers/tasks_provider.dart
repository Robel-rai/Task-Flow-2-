import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_change_notifier.dart';
import '../core/event_bus.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/tag_repository.dart';
import '../services/notification_service.dart';
import '../services/task_service.dart';
import '../services/ui_sound_service.dart';

/// Owns the visible task list, its filters, and every task mutation.
///
/// Mutations go through [TaskService] (business rules) and emit
/// [AppEvent]s so other providers can refresh lazily.
class TasksProvider extends AppChangeNotifier {
  TasksProvider({TaskService? taskService, NotificationService? notifications})
      : _taskService = taskService ?? TaskService(),
        _notifications = notifications ?? NotificationService();

  final TaskService _taskService;
  final NotificationService _notifications;
  final UiSoundService _sounds = UiSoundService.instance;

  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;

  List<Task> get runningTasks => _tasks.where((t) => t.isTimerRunning).toList();

  bool _loading = false;
  bool get loading => _loading;

  // ─── Filters ───
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _categoryFilter;
  int? get categoryFilter => _categoryFilter;

  String? _statusFilter;
  String? get statusFilter => _statusFilter;

  String? _priorityFilter;
  String? get priorityFilter => _priorityFilter;

  DateTime? _startDateFilter;
  DateTime? _endDateFilter;
  DateTime? get startDateFilter => _startDateFilter;
  DateTime? get endDateFilter => _endDateFilter;

  int? _tagFilter;
  int? get tagFilter => _tagFilter;

  // ─── Selection ───
  final Set<int> _selectedIds = {};
  Set<int> get selectedIds => _selectedIds;
  bool get hasSelection => _selectedIds.isNotEmpty;

  void initialize() {
    _restoreFilters();
    // Focus sessions auto-start/stop the attached task's timer directly
    // through FocusService — refresh so the Tasks screen stays in sync.
    final bus = EventBus.instance;
    bus.subscribe(AppEvent.focusSessionStarted, refresh);
    bus.subscribe(AppEvent.focusSessionStopped, refresh);
    bus.subscribe(AppEvent.dataReset, refresh);
  }

  /// Restores the persisted date filter. When nothing was saved the
  /// Tasks page defaults to showing all dates.
  Future<void> _restoreFilters() async {
    _loading = true;
    safeNotify();
    await loadPersistedFilters();
    await refresh();
  }

  // ─── Loading ───

  Future<void> refresh() async {
    _loading = true;
    safeNotify();
    _tasks = await _taskService.fetchAll(
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      categoryId: _categoryFilter,
      statusFilter: _statusFilter,
      priorityFilter: _priorityFilter,
      startDate: _startDateFilter,
      endDate: _endDateFilter,
    );
    // Post-filter by tag (many-to-many).
    if (_tagFilter != null) {
      final tagTaskIds = await TagRepository().getTaskIdsForTag(_tagFilter!);
      final idSet = tagTaskIds.toSet();
      _tasks = _tasks.where((t) => t.id != null && idSet.contains(t.id)).toList();
    }
    _loading = false;
    safeNotify();
  }

  // ─── Filter operations ───

  void setSearchQuery(String query) {
    _searchQuery = query;
    refresh();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryFilter = categoryId;
    refresh();
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    refresh();
  }  void setPriorityFilter(String? priority) {
    _priorityFilter = priority;
    refresh();
  }

  void setTagFilter(int? tagId) {
    _tagFilter = tagId;
    refresh();
  }

  Future<void> setDateRangeFilter(DateTime? start, DateTime? end) async {
    _startDateFilter = start;
    _endDateFilter = end;
    final prefs = await SharedPreferences.getInstance();
    if (start != null) {
      await prefs.setString('startDateFilter', start.toIso8601String());
    } else {
      await prefs.remove('startDateFilter');
    }
    if (end != null) {
      await prefs.setString('endDateFilter', end.toIso8601String());
    } else {
      await prefs.remove('endDateFilter');
    }
    refresh();
  }

  Future<void> loadPersistedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final startStr = prefs.getString('startDateFilter');
    final endStr = prefs.getString('endDateFilter');
    if (startStr != null) _startDateFilter = DateTime.tryParse(startStr);
    if (endStr != null) _endDateFilter = DateTime.tryParse(endStr);
  }

  Future<void> clearFilters() async {
    _searchQuery = '';
    _categoryFilter = null;
    _statusFilter = null;
    _priorityFilter = null;
    _startDateFilter = null;
    _endDateFilter = null;
    _tagFilter = null;
    await refresh();
  }

  // ─── Selection ───

  void toggleSelection(int taskId) {
    if (!_selectedIds.remove(taskId)) {
      _selectedIds.add(taskId);
    }
    safeNotify();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    safeNotify();
  }

  // ─── Task mutations ───

  Future<Task> createTask(Task task, {List<Subtask>? subtasks}) async {
    final saved = await _taskService.create(task, subtasks: subtasks);
    await refresh();
    EventBus.instance.emit(AppEvent.taskCreated);
    _sounds.taskSaved();
    return saved;
  }

  Future<Task> updateTask(Task task, {List<Subtask>? subtasks}) async {
    final saved = await _taskService.update(task, subtasks: subtasks);
    await refresh();
    EventBus.instance.emit(AppEvent.taskUpdated);
    _sounds.taskSaved();
    return saved;
  }

  Future<Task> completeTask(Task task) async {
    final updated = await _taskService.complete(task);
    await refresh();
    unawaited(_notifyCompletion([task]));
    EventBus.instance.emitAll([
      AppEvent.taskCompleted,
      if (task.projectId != null) AppEvent.projectStatusChanged,
    ]);
    _sounds.taskCompleted();
    return updated;
  }

  Future<Task> reopenTask(Task task, {bool resumeTimer = false}) async {
    final updated = await _taskService.reopen(task, resumeTimer: resumeTimer);
    await refresh();
    EventBus.instance.emitAll([
      AppEvent.taskReopened,
      if (task.projectId != null) AppEvent.projectStatusChanged,
    ]);
    return updated;
  }

  Future<void> deleteTask(int id) async {
    await _taskService.deleteTask(id);
    _selectedIds.remove(id);
    await refresh();
    EventBus.instance.emit(AppEvent.taskDeleted);
    _sounds.taskDeleted();
  }

  Future<void> trashTask(Task task) async {
    await _taskService.trashTask(task);
    _selectedIds.remove(task.id);
    await refresh();
    EventBus.instance.emit(AppEvent.taskTrashed);
    _sounds.taskDeleted();
  }

  Future<void> restoreTask(Task task) async {
    await _taskService.restoreTask(task);
    await refresh();
    EventBus.instance.emit(AppEvent.taskRestored);
  }

  Future<Task> toggleSubtask(Task task, int subtaskId) async {
    final updated = await _taskService.toggleSubtask(task, subtaskId);
    await refresh();
    EventBus.instance.emit(AppEvent.subtaskToggled);
    return updated;
  }

  Future<Task> startTimer(Task task) async {
    final updated = await _taskService.startTimer(task);
    await refresh();
    EventBus.instance.emit(AppEvent.timerStarted);
    return updated;
  }

  Future<Task> stopTimer(Task task) async {
    final updated = await _taskService.stopTimer(task);
    await refresh();
    EventBus.instance.emit(AppEvent.timerStopped);
    return updated;
  }

  Future<Task> rescheduleTask(Task task, DateTime newDate) async {
    final updated = await _taskService.reschedule(task, newDate);
    await refresh();
    EventBus.instance.emit(AppEvent.taskRescheduled);
    return updated;
  }

  /// Persists a manual ordering of task ids (calendar day view reorder).
  Future<void> reorderTasks(List<int> orderedIds) async {
    await _taskService.reorder(orderedIds);
    await refresh();
    EventBus.instance.emit(AppEvent.taskRescheduled);
  }

  // ─── Bulk actions ───

  /// Completes several tasks in one pass (single refresh + event).
  Future<void> completeTasks(Iterable<Task> tasks) async {
    final completed = List<Task>.from(tasks);
    for (final task in completed) {
      await _taskService.complete(task);
    }
    _selectedIds.clear();
    await refresh();
    unawaited(_notifyCompletion(completed));
    EventBus.instance.emit(AppEvent.taskCompleted);
    _sounds.taskCompleted();
  }

  /// Permanently deletes several tasks in one pass.
  Future<void> deleteTasks(Iterable<Task> tasks) async {
    for (final task in tasks) {
      await _taskService.deleteTask(task.id!);
    }
    _selectedIds.clear();
    await refresh();
    EventBus.instance.emit(AppEvent.taskDeleted);
  }

  /// Moves several tasks to another project.
  Future<void> moveTasksToProject(
      Iterable<Task> tasks, int? projectId) async {
    for (final task in tasks) {
      await _taskService.update(task.copyWith(
        projectId: projectId,
        clearProjectId: projectId == null,
      ));
    }
    _selectedIds.clear();
    await refresh();
    EventBus.instance.emit(AppEvent.taskUpdated);
  }

  // ─── Trash ───

  /// Fires one Windows toast per completed task (best-effort, never
  /// blocks the mutation). Gated by the "completion confirmations"
  /// notification setting.
  Future<void> _notifyCompletion(Iterable<Task> tasks) async {
    try {
      if (!await _notifications.completionEnabled) return;
      for (final task in tasks) {
        await _notifications.showTaskCompletedToast(task);
      }
    } catch (_) {
      // Notifications must never break task completion.
    }
  }

  Future<List<Task>> getTrashed() => _taskService.getTrashed();

  Future<void> permanentDelete(int id) async {
    await _taskService.permanentDelete(id);
    _selectedIds.remove(id);
    await refresh();
    EventBus.instance.emit(AppEvent.taskDeleted);
    _sounds.taskDeleted();
  }

  Future<void> emptyTrash() async {
    await _taskService.emptyTrash();
    _selectedIds.clear();
    await refresh();
    EventBus.instance.emit(AppEvent.taskDeleted);
    _sounds.taskDeleted();
  }
}
