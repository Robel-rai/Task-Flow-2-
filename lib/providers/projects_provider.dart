import '../core/app_change_notifier.dart';

import '../core/event_bus.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../models/task.dart';
import '../repositories/project_repository.dart';
import '../repositories/project_status_repository.dart';
import '../repositories/task_repository.dart';
import '../services/project_service.dart';

/// Owns the project list, the active (detail) project, its kanban tasks,
/// and per-project progress.
class ProjectsProvider extends AppChangeNotifier {
  ProjectsProvider({
    ProjectService? service,
    ProjectRepository? projects,
    TaskRepository? tasks,
    ProjectStatusRepository? statuses,
  })  : _service = service ?? ProjectService(),
        _projects = projects ?? ProjectRepository(),
        _statuses = statuses ?? ProjectStatusRepository(),
        _tasks = tasks ?? TaskRepository();

  final ProjectService _service;
  final ProjectRepository _projects;
  final ProjectStatusRepository _statuses;
  final TaskRepository _tasks;

  List<Project> _projectList = [];
  List<Project> get projectList => _projectList;

  List<Task> _kanbanTasks = [];
  List<Task> get kanbanTasks => _kanbanTasks;

  /// Custom kanban columns of the active project, in order. Empty when the
  /// project uses the built-in defaults.
  List<ProjectStatus> _activeStatuses = [];
  List<ProjectStatus> get activeStatuses => _activeStatuses;

  /// Custom columns of any project (used by the task dialog so tasks can
  /// be assigned to a project's own progress states).
  Future<List<ProjectStatus>> statusesFor(int projectId) =>
      _statuses.getForProject(projectId);

  final Map<int, (int, int)> _progressByProject = {};

  /// (completed, total) for [projectId], or null when unknown.
  (int, int)? progressOf(int? projectId) =>
      projectId == null ? null : _progressByProject[projectId];

  int? _activeProjectId;
  int? get activeProjectId => _activeProjectId;
  Project? get activeProject {
    for (final p in _projectList) {
      if (p.id == _activeProjectId) return p;
    }
    return null;
  }

  void initialize() {
    refresh();
    final bus = EventBus.instance;
    for (final event in const [
      AppEvent.projectStatusChanged,
      AppEvent.projectUpdated,
      AppEvent.projectCreated,
      AppEvent.projectDeleted,
      AppEvent.taskCreated,
      AppEvent.taskUpdated,
      AppEvent.taskCompleted,
      AppEvent.taskReopened,
      AppEvent.taskTrashed,
      AppEvent.taskRestored,
      AppEvent.taskDeleted,
      AppEvent.subtaskToggled,
      AppEvent.dataReset,
    ]) {
      bus.subscribe(event, refresh);
    }
  }

  Future<void> refresh() async {
    _projectList = await _projects.getAll();
    _progressByProject.clear();
    for (final p in _projectList) {
      _progressByProject[p.id!] = await _projects.progress(p.id!);
    }
    await _reloadKanban();
    safeNotify();
  }

  Future<void> _reloadKanban() async {
    if (_activeProjectId == null) {
      _kanbanTasks = [];
      _activeStatuses = [];
      return;
    }
    _kanbanTasks = await _tasks.getForProject(_activeProjectId!);
    _activeStatuses = await _statuses.getForProject(_activeProjectId!);
    _progressByProject[_activeProjectId!] =
        await _projects.progress(_activeProjectId!);
  }

  Future<void> select(int? projectId) async {
    _activeProjectId = projectId;
    await _reloadKanban();
    safeNotify();
  }

  Future<Project> create(Project project) async {
    final id = await _projects.insert(project);
    await refresh();
    EventBus.instance.emit(AppEvent.projectCreated);
    return (await _projects.getById(id))!;
  }

  Future<Project> update(Project project) async {
    await _projects.update(project);
    await refresh();
    EventBus.instance.emit(AppEvent.projectUpdated);
    return (await _projects.getById(project.id!))!;
  }

  Future<void> delete(int id) async {
    await _projects.delete(id);
    await _statuses.deleteForProject(id);
    if (_activeProjectId == id) _activeProjectId = null;
    await refresh();
    EventBus.instance.emit(AppEvent.projectDeleted);
  }

  /// Replaces the active project's custom kanban columns with [statuses]
  /// (order preserved). Tasks whose status no longer exists are moved to
  /// the first column. Returns the number of tasks reassigned, or null
  /// when there is no active project.
  Future<int?> saveStatuses(List<ProjectStatus> statuses) async {
    final projectId = _activeProjectId;
    if (projectId == null) return null;

    final current = await _statuses.getForProject(projectId);
    final newNames = statuses.map((s) => s.name.trim()).toList();
    final removed = current
        .map((s) => s.name)
        .where((name) => !newNames.contains(name))
        .toSet();

    await _statuses.deleteForProject(projectId);
    for (var i = 0; i < statuses.length; i++) {
      await _statuses.insert(ProjectStatus(
        projectId: projectId,
        name: statuses[i].name.trim(),
        color: statuses[i].color,
        sortOrder: i,
      ));
    }

    // Reassign tasks of removed columns so no task gets hidden.
    var reassigned = 0;
    if (removed.isNotEmpty) {
      final fallback = newNames.isNotEmpty ? newNames.first : 'Pending';
      final tasks = await _tasks.getForProject(projectId);
      for (final task in tasks) {
        if (removed.contains(task.status)) {
          await _tasks.update(task.copyWith(status: fallback));
          reassigned++;
        }
      }
    }

    await refresh();
    EventBus.instance.emit(AppEvent.projectUpdated);
    return reassigned;
  }

  /// Kanban move — updates the task's status and re-evaluates the project.
  Future<Task?> moveTaskStatus(int taskId, String newStatus) async {
    final updated = await _service.moveTaskStatus(taskId, newStatus);
    await refresh();
    EventBus.instance.emitAll([
      AppEvent.taskUpdated,
      AppEvent.projectStatusChanged,
    ]);
    return updated;
  }
}
