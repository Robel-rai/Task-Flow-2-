import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../repositories/project_repository.dart';
import '../repositories/task_repository.dart';

/// Debounced task/project search plus keyboard selection and persisted
/// recent queries. Shared by the dashboard dropdown and the global sidebar
/// search panel so both behave identically.
class SearchQueryController extends ChangeNotifier {
  SearchQueryController({TaskRepository? tasks, ProjectRepository? projects})
      : _tasks = tasks ?? TaskRepository(),
        _projects = projects ?? ProjectRepository();

  static const int resultLimit = 6;
  static const int maxRecents = 5;
  static const String recentsPrefsKey = 'recentSearches';

  final TaskRepository _tasks;
  final ProjectRepository _projects;

  Timer? _debounce;

  String _query = '';
  String get query => _query;

  bool _searching = false;
  bool get searching => _searching;

  List<Task> _taskResults = [];
  List<Task> get taskResults => _taskResults;

  List<Project> _projectResults = [];
  List<Project> get projectResults => _projectResults;

  int _selectedIndex = -1;
  int get selectedIndex => _selectedIndex;

  List<String> _recentQueries = [];
  List<String> get recentQueries => _recentQueries;

  /// Total number of result items (tasks, then projects).
  int get resultCount => _taskResults.length + _projectResults.length;

  /// The item at [selectedIndex] in the flattened task-then-project list.
  Object? get selectedItem {
    if (_selectedIndex < 0 || _selectedIndex >= resultCount) return null;
    if (_selectedIndex < _taskResults.length) {
      return _taskResults[_selectedIndex];
    }
    return _projectResults[_selectedIndex - _taskResults.length];
  }

  /// Loads persisted recent searches. Call once when the widget mounts.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _recentQueries = prefs.getStringList(recentsPrefsKey) ?? [];
    notifyListeners();
  }

  void onChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    _query = q;
    _selectedIndex = -1;
    if (q.isEmpty) {
      _taskResults = [];
      _projectResults = [];
      _searching = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final tasks = await _tasks.search(q, limit: resultLimit);
    final projects = await _projects.search(q, limit: resultLimit);
    if (_query != q) return; // stale response
    _taskResults = tasks;
    _projectResults = projects;
    _searching = false;
    _selectedIndex = resultCount > 0 ? 0 : -1;
    notifyListeners();
  }

  /// Moves the keyboard highlight by [delta] (±1), wrapping around.
  void moveSelection(int delta) {
    if (resultCount == 0) return;
    var next = _selectedIndex + delta;
    if (next < 0) next = resultCount - 1;
    if (next >= resultCount) next = 0;
    _selectedIndex = next;
    notifyListeners();
  }

  /// Remembers [q] as a recent search (deduped, capped, persisted).
  Future<void> remember(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;
    _recentQueries.remove(query);
    _recentQueries.insert(0, query);
    if (_recentQueries.length > maxRecents) {
      _recentQueries = _recentQueries.sublist(0, maxRecents);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(recentsPrefsKey, _recentQueries);
  }

  void clear() {
    _debounce?.cancel();
    _query = '';
    _searching = false;
    _taskResults = [];
    _projectResults = [];
    _selectedIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
