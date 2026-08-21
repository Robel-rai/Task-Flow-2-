import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/search/search_results_content.dart';
import '../core/app_navigator.dart';
import '../core/search_controller.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/routines_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'task_dialog.dart';
import '../components/projects/project_dialog.dart';
import '../components/routines/routine_dialog.dart';
import '../models/routine.dart';

Future<void> showGlobalSearch(BuildContext context) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => GlobalSearchOverlay(
      dialogContext: context,
      onClose: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class GlobalSearchOverlay extends StatefulWidget {
  const GlobalSearchOverlay({
    super.key,
    required this.dialogContext,
    required this.onClose,
  });

  final BuildContext dialogContext;
  final VoidCallback onClose;

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final SearchQueryController _search = SearchQueryController();
  final TextEditingController _field = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Command palette commands
  static const _commands = [
    (label: 'Go to Dashboard', icon: Icons.dashboard_outlined, action: 'nav', target: 0),
    (label: 'Go to Tasks', icon: Icons.check_circle_outline, action: 'nav', target: 1),
    (label: 'Go to Calendar', icon: Icons.calendar_today_outlined, action: 'nav', target: 2),
    (label: 'Go to Projects', icon: Icons.folder_outlined, action: 'nav', target: 3),
    (label: 'Go to Focus', icon: Icons.timer_outlined, action: 'nav', target: 4),
    (label: 'Go to Routines', icon: Icons.repeat, action: 'nav', target: 5),
    (label: 'Go to Analytics', icon: Icons.bar_chart_outlined, action: 'nav', target: 6),
    (label: 'Go to Settings', icon: Icons.settings_outlined, action: 'nav', target: 7),
    (label: 'New Task', icon: Icons.add_task, action: 'create_task', target: 0),
    (label: 'New Project', icon: Icons.create_new_folder_outlined, action: 'create_project', target: 0),
    (label: 'New Routine', icon: Icons.repeat, action: 'create_routine', target: 0),
    (label: 'Toggle Theme', icon: Icons.dark_mode_outlined, action: 'theme', target: 0),
  ];

  var _filteredCommands = <({String label, IconData icon, String action, int target})>[];

  void _filterCommands(String query) {
    if (query.isEmpty) {
      _filteredCommands = [];
      return;
    }
    final q = query.toLowerCase();
    _filteredCommands = _commands.where((c) => c.label.toLowerCase().contains(q)).toList();
  }

  void _executeCommand(({String label, IconData icon, String action, int target}) cmd) {
    widget.onClose();
    switch (cmd.action) {
      case 'nav':
        AppNavigator.instance.goTo(cmd.target);
      case 'create_task':
        AppNavigator.instance.goTo(1);
        _createTask();
      case 'create_project':
        _createProject();
      case 'create_routine':
        _createRoutine();
      case 'theme':
        final ctx = widget.dialogContext;
        final brightness = Theme.of(ctx).brightness;
        ctx.read<ThemeProvider>().setThemeMode(
          brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    _search.initialize();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _search.dispose();
    _field.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _search.moveSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _search.moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onSubmitted(String text) {
    final item = _search.selectedItem;
    if (item is Task) {
      _openTask(item);
    } else if (item is Project) {
      _openProject(item);
    } else if (_search.query.isNotEmpty) {
      _search.remember(_search.query);
    }
  }

  void _openTask(Task task) {
    final id = task.id;
    if (id == null) return;
    _search.remember(_search.query);
    AppNavigator.instance.openTaskOnTasksPage(id);
    widget.onClose();
  }

  void _openProject(Project project) {
    final id = project.id;
    if (id == null) return;
    _search.remember(_search.query);
    AppNavigator.instance.openProjectKanban(id);
    widget.onClose();
  }

  void _onSelectResult(int index) {
    if (index < _search.taskResults.length) {
      _openTask(_search.taskResults[index]);
    } else {
      _openProject(_search.projectResults[index - _search.taskResults.length]);
    }
  }

  void _onRecentTap(String query) {
    _field.text = query;
    _field.selection = TextSelection.collapsed(offset: query.length);
    _search.onChanged(query);
  }

  Future<void> _createTask() async {
    final tasksProvider = widget.dialogContext.read<TasksProvider>();
    final future = showDialog<TaskDialogResult>(
      context: widget.dialogContext,
      builder: (_) => TaskDialog(task: Task(title: _search.query)),
    );
    widget.onClose();
    final result = await future;
    if (result == null) return;
    await tasksProvider.createTask(result.task, subtasks: result.subtasks);
  }

  Future<void> _createProject() async {
    final projectsProvider = widget.dialogContext.read<ProjectsProvider>();
    final future = showDialog<ProjectDialogResult>(
      context: widget.dialogContext,
      builder: (_) => ProjectDialog(project: Project(title: _search.query)),
    );
    widget.onClose();
    final result = await future;
    if (result == null) return;
    await projectsProvider.create(result.project);
  }

  Future<void> _createRoutine() async {
    final routinesProvider = widget.dialogContext.read<RoutinesProvider>();
    final future = showDialog<RoutineDialogResult>(
      context: widget.dialogContext,
      builder: (_) => RoutineDialog(routine: Routine(title: _search.query, scheduledTime: '08:00')),
    );
    widget.onClose();
    final result = await future;
    if (result == null) return;
    await routinesProvider.create(result.routine);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Center(
          child: Material(
            key: const Key('global_search_panel'),
            color: colors.surface,
            elevation: 16,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Focus(
                            onKeyEvent: _onKeyEvent,
                            child: TextField(
                              key: const Key('global_search_field'),
                              controller: _field,
                              focusNode: _focusNode,
                              onChanged: (q) {
                                _search.onChanged(q);
                                _filterCommands(q);
                              },
                              onSubmitted: _onSubmitted,
                              textInputAction: TextInputAction.search,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search tasks, projects, or type a command...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                isDense: true,
                                filled: true,
                                fillColor: colors.surfaceVariant.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close search',
                          icon: Icon(Icons.close, color: colors.textSecondary),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListenableBuilder(
                      listenable: _search,
                      builder: (context, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_filteredCommands.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text('COMMANDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: colors.textTertiary)),
                            ),
                            for (int i = 0; i < _filteredCommands.length; i++)
                              ListTile(
                                dense: true,
                                leading: Icon(_filteredCommands[i].icon, size: 20, color: AppTheme.primary),
                                title: Text(_filteredCommands[i].label, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                                onTap: () => _executeCommand(_filteredCommands[i]),
                              ),
                            if (_search.query.isNotEmpty && _search.taskResults.isEmpty && _search.projectResults.isEmpty)
                              const Divider(height: 1),
                          ],
                          SearchResultsContent(
                            searching: _search.searching,
                            query: _search.query,
                            taskResults: _search.taskResults,
                            projectResults: _search.projectResults,
                            selectedIndex: _search.selectedIndex,
                            onSelect: _onSelectResult,
                            onCreateTask: _createTask,
                            onCreateProject: _createProject,
                            showRecents: true,
                            recentQueries: _search.recentQueries,
                            onRecentTap: _onRecentTap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
