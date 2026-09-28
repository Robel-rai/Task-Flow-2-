import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/analytics/stat_card.dart';
import '../components/tasks/filter_chip_bar.dart';
import '../core/app_navigator.dart';
import '../components/tasks/list_task_item.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../repositories/tag_repository.dart';
import '../repositories/task_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/task_card.dart';
import '../widgets/task_dialog.dart';
import '../components/tasks/trash_panel.dart';

/// Cards never exceed this width: wider windows add grid columns instead
/// of inflating each card.
const double _taskCardMaxWidth = 460;

/// Fixed tile height so card content never overflows and cards keep a
/// constant size at any window size.
const double _taskCardHeight = 250;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _gridView = true;
  bool _showTrash = false;

  final ScrollController _scrollController = ScrollController();

  /// Task id currently flashing after a search jump, plus its grid key.
  int? _highlightedTaskId;
  GlobalObjectKey? _highlightKey;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    AppNavigator.instance.addListener(_handleNavigationIntent);
    AppNavigator.instance.addListener(_handleHighlightIntent);
  }

  @override
  void dispose() {
    AppNavigator.instance.removeListener(_handleNavigationIntent);
    AppNavigator.instance.removeListener(_handleHighlightIntent);
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Handles highlight requests from the notification menu: once the shell
  /// has switched to this screen, flash the target task.
  void _handleHighlightIntent() {
    final taskId = AppNavigator.instance.highlightTaskId;
    if (taskId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (AppNavigator.instance.index != 1) {
        _handleHighlightIntent(); // shell hasn't switched yet; retry
        return;
      }
      AppNavigator.instance.consumeHighlightTask();
      // Clear filters so the task is guaranteed to appear in the list.
      await context.read<TasksProvider>().clearFilters();
      if (!mounted) return;
      _flashHighlight(taskId);
    });
  }

  /// Opens the task requested by a dashboard search result: once the shell
  /// has switched to this screen, fetch it and show its editor dialog.
  void _handleNavigationIntent() {
    final taskId = AppNavigator.instance.taskToOpen;
    if (taskId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppNavigator.instance.index != 1) {
        _handleNavigationIntent(); // shell hasn't switched yet; retry
        return;
      }
      _openTaskById(taskId);
      AppNavigator.instance.consumeTaskToOpen();
    });
  }

  Future<void> _openTaskById(int taskId) async {
    final task = await TaskRepository().getById(taskId);
    if (task == null || !mounted) return;
    // Clear any filters so the task is guaranteed to show once the dialog
    // closes and the list renders.  Await the refresh so the unfiltered
    // list is available before we try to scroll to it.
    await context.read<TasksProvider>().clearFilters();
    if (!mounted) return;
    await _openDialog(task);
    // After the editor closes, flash the card so the user sees exactly
    // where the task landed.
    if (!mounted) return;
    _flashHighlight(taskId);
  }

  /// Briefly highlights [taskId]'s card and scrolls it into view.
  ///
  /// Retries a few times if the card hasn't been built yet (e.g. after
  /// a filter clear the list rebuilds asynchronously).
  void _flashHighlight(int taskId, {int retryCount = 0}) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedTaskId = taskId;
      _highlightKey = GlobalObjectKey(taskId);
    });
    _scrollToTask(taskId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _highlightKey?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          alignment: 0.5,
        );
      } else if (retryCount < 5) {
        // Card not built yet — schedule another attempt after a brief delay
        // to let the list finish rebuilding from the filter clear.
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _flashHighlight(taskId, retryCount: retryCount + 1);
        });
      }
    });
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _highlightedTaskId = null;
        _highlightKey = null;
      });
    });
  }

  /// Rough-scrolls to [taskId]'s row so its lazily-built card gets built
  /// (the subsequent ensureVisible snaps it precisely into view).
  void _scrollToTask(int taskId) {
    final tasks = context.read<TasksProvider>();
    final index = tasks.tasks.indexWhere((t) => t.id == taskId);
    if (index < 0 || !_scrollController.hasClients) return;

    double target;
    if (_gridView) {
      final width = MediaQuery.of(context).size.width;
      const spacing = 16.0;
      final available = width - 64;
      // Mirror SliverGridDelegateWithMaxCrossAxisExtent's layout math so
      // the rough-scroll estimate lands near the target row (slightly
      // under-estimating is fine — ensureVisible snaps precisely after).
      final crossAxisCount = ((available + spacing) /
              (_taskCardMaxWidth + spacing))
          .ceil()
          .clamp(1, 100000)
          .toInt();
      // Tiles use a fixed height, so the row extent is height + gap.
      final itemExtent = _taskCardHeight + spacing;
      target = (index ~/ crossAxisCount) * itemExtent;
    } else {
      target = index * 96.0; // approximate list row height
    }
    _scrollController.jumpTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  Future<void> _openDialog(Task? task) async {
    final result = await showDialog<TaskDialogResult>(
      context: context,
      builder: (_) => TaskDialog(task: task),
    );
    if (result == null) return;
    if (!mounted) return;
    final tasks = context.read<TasksProvider>();
    Task saved;
    if (task == null) {
      saved = await tasks.createTask(result.task, subtasks: result.subtasks);
    } else {
      saved = await tasks.updateTask(result.task, subtasks: result.subtasks);
    }
    // Persist tag associations.
    if (saved.id != null && result.tagIds.isNotEmpty) {
      await TagRepository().setTagsForTask(saved.id!, result.tagIds);
    } else if (saved.id != null && result.tagIds.isEmpty) {
      await TagRepository().setTagsForTask(saved.id!, []);
    }
  }

  String _categoryName(Task task, SettingsProvider settings) {
    return _categoryFor(task, settings)?.name ?? 'General';
  }

  /// The category assigned to [task], or null when unassigned/unknown.
  Category? _categoryFor(Task task, SettingsProvider settings) {
    if (task.categoryId == null) return null;
    for (final c in settings.categoryList) {
      if (c.id == task.categoryId) return c;
    }
    return null;
  }

  Future<void> _bulkComplete(TasksProvider tasks) async {
    final selected =
        tasks.tasks.where((t) => tasks.selectedIds.contains(t.id)).toList();
    await tasks.completeTasks(selected);
  }

  Future<void> _bulkDelete(TasksProvider tasks) async {
    final selected =
        tasks.tasks.where((t) => tasks.selectedIds.contains(t.id)).toList();
    if (selected.isEmpty) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Move to Trash'),
        content: Text(
            'Move ${selected.length} task${selected.length == 1 ? '' : 's'} to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final task in selected) {
        await tasks.trashTask(task);
      }
    }
  }

  Future<void> _bulkMoveProject(TasksProvider tasks) async {
    final projects = context.read<ProjectsProvider>().projectList;
    final selected =
        tasks.tasks.where((t) => tasks.selectedIds.contains(t.id)).toList();
    if (selected.isEmpty) return;

    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final projectId = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: colors.surface,
        title: const Text('Move to project'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('No project'),
          ),
          for (final p in projects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.id),
              child: Text(p.title),
            ),
        ],
      ),
    );
    await tasks.moveTasksToProject(selected, projectId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);
    final tasks = context.watch<TasksProvider>();
    final settings = context.watch<SettingsProvider>();

    if (_showTrash) {
      return TrashPanel(
        onClose: () => setState(() => _showTrash = false),
      );
    }

    final mainArea = Column(
      children: [
        _buildHeader(context, tasks),
        if (tasks.tasks.isNotEmpty) _buildKpiSection(tasks, colors),
        FilterChipBar(
          gridView: _gridView,
          onViewChanged: (value) => setState(() => _gridView = value),
        ),
        const ActiveFilterChipsRow(),
        Expanded(
          child: tasks.loading && tasks.tasks.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : tasks.tasks.isEmpty
                  ? _emptyState(context, colors)
                  : _gridView
                      ? _buildGrid(tasks, settings)
                      : _buildList(tasks, settings),
        ),
      ],
    );

    return isCollapsed
        ? Column(
            children: [
              Expanded(child: mainArea),
              const SizedBox(height: 4),
            ],
          )
        : mainArea;
  }

  Widget _buildKpiSection(TasksProvider tasks, AppThemeColors colors) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final total = tasks.tasks.length;
    final completed = tasks.tasks.where((t) => t.status == 'Completed').length;
    final inProgress = tasks.tasks.where((t) => t.status == 'In Progress').length;
    final pending = tasks.tasks.where((t) => t.status == 'Pending').length;
    final overdue = tasks.tasks.where((t) {
      if (t.dueDate == null || t.status == 'Completed') return false;
      return t.dueDate!.isBefore(today);
    }).length;
    final dueThisWeek = tasks.tasks.where((t) {
      if (t.dueDate == null || t.status == 'Completed') return false;
      return !t.dueDate!.isBefore(today) && t.dueDate!.isBefore(weekEnd);
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          CompactStatCardRow(
            cards: [
              CompactStatCard(
                label: 'Total',
                targetValue: total.toDouble(),
                icon: Icons.list_alt,
                color: AppTheme.blue,
              ),
              CompactStatCard(
                label: 'Completed',
                targetValue: completed.toDouble(),
                icon: Icons.check_circle_outline,
                color: AppTheme.emerald,
              ),
              CompactStatCard(
                label: 'In Progress',
                targetValue: inProgress.toDouble(),
                icon: Icons.play_circle_outline,
                color: AppTheme.sky,
              ),
              CompactStatCard(
                label: 'Pending',
                targetValue: pending.toDouble(),
                icon: Icons.schedule,
                color: AppTheme.amber,
              ),
              CompactStatCard(
                label: 'Overdue',
                targetValue: overdue.toDouble(),
                icon: Icons.warning_amber_rounded,
                color: overdue > 0 ? AppTheme.rose : AppTheme.emerald,
              ),
              CompactStatCard(
                label: 'Due This Week',
                targetValue: dueThisWeek.toDouble(),
                icon: Icons.event_available_outlined,
                color: dueThisWeek > 0 ? AppTheme.amber : AppTheme.emerald,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TasksProvider tasks) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (isCollapsed) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: tasks.hasSelection
                ? Row(
                    children: [
                      Text(
                        '${tasks.selectedIds.length} selected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        tooltip: 'Complete selected',
                        icon: const Icon(Icons.check_circle_outline,
                            color: Color(0xFF10B981)),
                        onPressed: () => _bulkComplete(tasks),
                      ),
                      IconButton(
                        tooltip: 'Move to project',
                        icon: Icon(Icons.drive_file_move_outline,
                            color: colors.textSecondary),
                        onPressed: () => _bulkMoveProject(tasks),
                      ),
                      IconButton(
                        tooltip: 'Delete selected',
                        icon: const Icon(Icons.delete_outline,
                            color: Color(0xFFF43F5E)),
                        onPressed: () => _bulkDelete(tasks),
                      ),
                      IconButton(
                        tooltip: 'Clear selection',
                        icon: Icon(Icons.close, color: colors.textSecondary),
                        onPressed: tasks.clearSelection,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Tasks',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${tasks.tasks.length} task${tasks.tasks.length == 1 ? '' : 's'}',
                        style:
                            TextStyle(fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                  ),
          ),
          IconButton(
            tooltip: 'Open trash',
            icon: Icon(Icons.delete_outline, color: colors.textSecondary),
            onPressed: () => setState(() => _showTrash = true),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: () => _openDialog(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Task'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, AppThemeColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, size: 64, color: colors.textTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first task to get started',
            style: TextStyle(fontSize: 13, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(TasksProvider tasks, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GridView.builder(
        controller: _scrollController,
        // Bounded tile width: cards stay a constant size and the grid adds
        // columns as the window grows instead of inflating each card.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _taskCardMaxWidth,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: _taskCardHeight,
        ),
        itemCount: tasks.tasks.length,
        itemBuilder: (context, index) {
          final task = tasks.tasks[index];
          final highlighted = _highlightedTaskId != null &&
              task.id == _highlightedTaskId;
          final category = _categoryFor(task, settings);
          return GestureDetector(
            // Key by task id so card state (expanded dropdown, subtask
            // cache, highlight timer) is never reused across tasks when
            // the list reorders or the provider refreshes after a save.
            key: ValueKey<int?>(task.id),
            onTap: () => tasks.hasSelection
                ? tasks.toggleSelection(task.id!)
                : _openDialog(task),
            onLongPress: () => tasks.toggleSelection(task.id!),
            child: TaskCard(
              task: task,
              categoryName: _categoryName(task, settings),
              categoryColorKey: category?.color ?? 'primary',
              selectionMode: tasks.hasSelection,
              selected: task.id != null && tasks.selectedIds.contains(task.id),
              isHighlighted: highlighted,
              onEdit: () => _openDialog(task),
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(TasksProvider tasks, SettingsProvider settings) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      itemCount: tasks.tasks.length,
      itemBuilder: (context, index) {
        final task = tasks.tasks[index];
        final highlighted = _highlightedTaskId != null &&
            task.id == _highlightedTaskId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            // Same as the grid: one task = one element state.
            key: ValueKey<int?>(task.id),
            onTap: () => tasks.hasSelection
                ? tasks.toggleSelection(task.id!)
                : _openDialog(task),
            onLongPress: () => tasks.toggleSelection(task.id!),
            child: ListTaskItem(
              task: task,
              categoryName: _categoryName(task, settings),
              selectionMode: tasks.hasSelection,
              selected: task.id != null && tasks.selectedIds.contains(task.id),
              isHighlighted: highlighted,
            ),
          ),
        );
      },
    );
  }
}
