import '../models/task.dart';
import '../repositories/project_repository.dart';
import '../repositories/task_repository.dart';

/// Business rules for projects: progress calculation, auto-complete /
/// reopen, and kanban status moves.
class ProjectService {
  ProjectService({ProjectRepository? projects, TaskRepository? tasks})
      : _projects = projects ?? ProjectRepository(),
        _tasks = tasks ?? TaskRepository();

  final ProjectRepository _projects;
  final TaskRepository _tasks;

  /// Returns (completed, total) for the project.
  Future<(int, int)> progress(int projectId) => _projects.progress(projectId);

  double completionRate(int completed, int total) =>
      total > 0 ? (completed / total) * 100 : 0;

  /// Re-evaluates a project's status from its tasks:
  /// all completed → Completed; any in progress → In Progress;
  /// otherwise → Pending. No-op when [projectId] is null.
  Future<void> evaluate(int? projectId) async {
    if (projectId == null) return;
    final project = await _projects.getById(projectId);
    if (project == null) return;
    final tasks = await _tasks.getForProject(projectId);
    if (tasks.isEmpty) return;

    final allCompleted = tasks.every((t) => t.status == 'Completed');
    final anyInProgress = tasks.any((t) => t.status == 'In Progress');
    final String next;
    if (allCompleted) {
      next = 'Completed';
    } else if (anyInProgress) {
      next = 'In Progress';
    } else {
      next = 'Pending';
    }
    if (next != project.status) {
      await _projects.update(project.copyWith(status: next));
    }
  }

  /// Moves a task to [newStatus] (kanban drag) and re-evaluates the project.
  Future<Task?> moveTaskStatus(int taskId, String newStatus) async {
    final task = await _tasks.getById(taskId);
    if (task == null) return null;

    final completed = newStatus == 'Completed';
    final updated = task.copyWith(
      status: newStatus,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
    );
    await _tasks.update(updated);
    await evaluate(updated.projectId);
    return updated;
  }
}
