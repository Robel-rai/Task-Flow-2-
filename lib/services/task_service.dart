import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/subtask_repository.dart';
import '../repositories/task_repository.dart';
import 'project_service.dart';
import 'recurrence_service.dart';

/// Orchestrates task mutations and owns the business rules around them:
/// subtask auto-complete, timer accounting, recurrence spawning, and
/// project status re-evaluation.
class TaskService {
  TaskService({
    TaskRepository? tasks,
    SubtaskRepository? subtasks,
    ProjectService? projects,
  })  : _tasks = tasks ?? TaskRepository(),
        _subtasks = subtasks ?? SubtaskRepository(),
        _projects = projects ?? ProjectService();

  final TaskRepository _tasks;
  final SubtaskRepository _subtasks;
  final ProjectService _projects;

  // ─── CRUD ───

  /// Inserts a new task (id must be null) plus its subtasks.
  Future<Task> create(Task task, {List<Subtask>? subtasks}) async {
    final id = await _tasks.insert(task);
    if (subtasks != null) await _replaceSubtasks(id, subtasks);
    final saved = (await _tasks.getById(id))!;
    await _projects.evaluate(saved.projectId);
    return saved;
  }

  /// Updates a task; optionally reconciles its subtask list.
  Future<Task> update(Task task, {List<Subtask>? subtasks}) async {
    await _tasks.update(task);
    if (subtasks != null) await _replaceSubtasks(task.id!, subtasks);
    final saved = (await _tasks.getById(task.id!))!;
    await _projects.evaluate(saved.projectId);
    return saved;
  }

  Future<Task?> getById(int id) => _tasks.getById(id);

  /// Filtered task list — passthrough to the repository so providers
  /// talk to one service for both queries and mutations.
  Future<List<Task>> fetchAll({
    String? searchQuery,
    int? categoryId,
    int? projectId,
    String? statusFilter,
    String? priorityFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool includeUnscheduled = false,
    String? sortBy,
    bool ascending = true,
    bool includeDeleted = false,
  }) {
    return _tasks.getAll(
      searchQuery: searchQuery,
      categoryId: categoryId,
      projectId: projectId,
      statusFilter: statusFilter,
      priorityFilter: priorityFilter,
      startDate: startDate,
      endDate: endDate,
      includeUnscheduled: includeUnscheduled,
      sortBy: sortBy,
      ascending: ascending,
      includeDeleted: includeDeleted,
    );
  }

  /// Permanent delete (trash "delete forever").
  Future<void> deleteTask(int id) async {
    final task = await _tasks.getById(id);
    await _tasks.delete(id);
    await _projects.evaluate(task?.projectId);
  }

  /// Soft delete → moves to trash.
  Future<void> trashTask(Task task) async {
    await _tasks.trash(task.id!);
    await _projects.evaluate(task.projectId);
  }

  Future<void> restoreTask(Task task) async {
    await _tasks.restore(task.id!);
    await _projects.evaluate(task.projectId);
  }

  /// Returns all soft-deleted (trashed) tasks.
  Future<List<Task>> getTrashed() => _tasks.getTrashed();

  /// Permanently deletes one trashed task.
  Future<void> permanentDelete(int id) async {
    await _tasks.delete(id);
  }

  /// Permanently deletes every trashed task.
  Future<void> emptyTrash() => _tasks.emptyTrash();

  // ─── Status transitions ───

  /// Marks [task] complete, banking any running timer, and spawns the
  /// next recurring occurrence when the task repeats.
  Future<Task> complete(Task task) async {
    var updated = task.copyWith(
      status: 'Completed',
      completedAt: DateTime.now(),
      clearTimerStartedAt: true,
    );
    if (task.isTimerRunning) {
      final elapsed =
          DateTime.now().difference(task.timerStartedAt!).inSeconds;
      updated =
          updated.copyWith(timeSpentSeconds: task.timeSpentSeconds + elapsed);
    }
    await _tasks.update(updated);
    await _projects.evaluate(updated.projectId);
    await _spawnNextOccurrence(task);
    return updated;
  }

  /// Reopens a completed task as Pending (or In Progress with timer).
  Future<Task> reopen(Task task, {bool resumeTimer = false}) async {
    var updated = task.copyWith(
      status: resumeTimer ? 'In Progress' : 'Pending',
      clearCompletedAt: true,
    );
    if (resumeTimer) {
      updated = updated.copyWith(timerStartedAt: DateTime.now());
    }
    await _tasks.update(updated);
    await _projects.evaluate(updated.projectId);
    return updated;
  }

  // ─── Timer ───

  Future<Task> startTimer(Task task) async {
    final updated =
        task.copyWith(timerStartedAt: DateTime.now(), status: 'In Progress');
    await _tasks.update(updated);
    return updated;
  }

  Future<Task> stopTimer(Task task) async {
    if (!task.isTimerRunning) return task;
    final elapsed = DateTime.now().difference(task.timerStartedAt!).inSeconds;
    final updated = task.copyWith(
      timeSpentSeconds: task.timeSpentSeconds + elapsed,
      clearTimerStartedAt: true,
    );
    await _tasks.update(updated);
    return updated;
  }

  // ─── Subtasks ───

  /// Toggles a subtask; auto-completes (or reopens) the parent task when
  /// all subtasks become done (or one is un-done).
  Future<Task> toggleSubtask(Task task, int subtaskId) async {
    final subtask = await _subtasks.getById(subtaskId);
    if (subtask == null) return task;

    await _subtasks.update(
        subtask.copyWith(isCompleted: !subtask.isCompleted));

    final allDone = await _subtasks.allCompleted(task.id!);
    Task updated = task;
    if (allDone && task.status != 'Completed') {
      updated = task.copyWith(
        status: 'Completed',
        completedAt: DateTime.now(),
        clearTimerStartedAt: true,
      );
      if (task.isTimerRunning) {
        final elapsed =
            DateTime.now().difference(task.timerStartedAt!).inSeconds;
        updated =
            updated.copyWith(timeSpentSeconds: task.timeSpentSeconds + elapsed);
      }
    } else if (!allDone && task.status == 'Completed') {
      updated = task.copyWith(status: 'In Progress', clearCompletedAt: true);
    }

    if (!identical(updated, task)) {
      await _tasks.update(updated);
    }
    await _projects.evaluate(updated.projectId);
    return updated;
  }

  // ─── Scheduling ───

  Future<Task> reschedule(Task task, DateTime newDate) async {
    final updated = task.copyWith(
        scheduledDate: DateTime(newDate.year, newDate.month, newDate.day));
    await _tasks.update(updated);
    return updated;
  }

  /// Persists a manual ordering of task ids (calendar day-view reorder).
  Future<void> reorder(List<int> orderedIds) =>
      _tasks.updateSortOrder(orderedIds);

  // ─── Internals ───

  Future<void> _replaceSubtasks(int taskId, List<Subtask> subtasks) async {
    await _subtasks.deleteForTask(taskId);
    for (var i = 0; i < subtasks.length; i++) {
      final s = subtasks[i];
      await _subtasks.insert(Subtask(
        taskId: taskId,
        title: s.title,
        isCompleted: s.isCompleted,
        sortOrder: i,
      ));
    }
  }

  Future<Task?> _spawnNextOccurrence(Task task) async {
    if (task.recurrenceRule == null || task.recurrenceRule!.isEmpty) {
      return null;
    }
    final next = RecurrenceService.nextOccurrence(
      task.recurrenceRule!,
      DateTime.now(),
      endDate: task.recurrenceEndDate,
    );
    if (next == null) return null;

    final masterId = task.parentTaskId ?? task.id;
    final spawned = Task(
      title: task.title,
      description: task.description,
      categoryId: task.categoryId,
      projectId: task.projectId,
      priority: task.priority,
      status: 'Pending',
      scheduledDate: next,
      scheduledTime: task.scheduledTime,
      dueDate: task.dueDate,
      recurrenceRule: task.recurrenceRule,
      recurrenceEndDate: task.recurrenceEndDate,
      parentTaskId: masterId,
    );
    final id = await _tasks.insert(spawned);
    return _tasks.getById(id);
  }
}
