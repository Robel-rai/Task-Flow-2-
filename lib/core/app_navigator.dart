import 'package:flutter/foundation.dart';

/// Global shell navigation plus one-shot intents to focus a specific
/// resource: open a task's editor on the Tasks page, or open a project's
/// kanban detail on the Projects page.
///
/// Screens listen to this (via [addListener]) and consume the intent after
/// acting on it; the shell uses [index] as its source of truth.
class AppNavigator extends ChangeNotifier {
  AppNavigator._();

  static final AppNavigator instance = AppNavigator._();

  /// Index of the visible screen in the shell (see `AppShell._screens`).
  int _index = 0;
  int get index => _index;

  /// Pending task id to open on the Tasks screen, or null.
  int? _taskToOpen;
  int? get taskToOpen => _taskToOpen;

  /// Pending task id to highlight (scroll + glow) on the Tasks screen.
  int? _highlightTaskId;
  int? get highlightTaskId => _highlightTaskId;

  /// Pending project id to open (kanban detail) on the Projects screen.
  int? _projectToOpen;
  int? get projectToOpen => _projectToOpen;

  void goTo(int index) {
    if (_index == index) return;
    _index = index;
    notifyListeners();
  }

  /// Switch to the Tasks screen and open [taskId]'s editor dialog.
  void openTaskOnTasksPage(int taskId) {
    _taskToOpen = taskId;
    _index = 1; // TasksScreen position in AppShell._screens
    notifyListeners();
  }

  /// Switch to the Tasks screen and highlight [taskId] (scroll + glow).
  void highlightTaskOnTasksPage(int taskId) {
    _highlightTaskId = taskId;
    _index = 1;
    notifyListeners();
  }

  /// Switch to the Projects screen and select [projectId] (kanban detail).
  void openProjectKanban(int projectId) {
    _projectToOpen = projectId;
    _index = 3; // ProjectsScreen position in AppShell._screens
    notifyListeners();
  }

  void consumeTaskToOpen() {
    if (_taskToOpen == null) return;
    _taskToOpen = null;
    notifyListeners();
  }

  void consumeHighlightTask() {
    if (_highlightTaskId == null) return;
    _highlightTaskId = null;
    notifyListeners();
  }

  void consumeProjectToOpen() {
    if (_projectToOpen == null) return;
    _projectToOpen = null;
    notifyListeners();
  }

  /// Resets shell state (used between widget tests).
  void reset() {
    _index = 0;
    _taskToOpen = null;
    _projectToOpen = null;
    _highlightTaskId = null;
  }
}
