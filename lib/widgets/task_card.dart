import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/event_bus.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../providers/focus_provider.dart';
import '../providers/tasks_provider.dart';
import '../repositories/subtask_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'focus_actions.dart';

/// Grid card for a task. Runs its own 1-second ticker while the task's
/// timer is active, so only this card rebuilds — never the whole tree.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.categoryName = 'General',
    this.categoryColorKey = 'primary',
    this.selectionMode = false,
    this.selected = false,
    this.isHighlighted = false,
    this.onEdit,
  });

  final Task task;
  final String categoryName;

  /// The task's category color: a preset key ('blue', 'rose', ...) or a
  /// '#RRGGBB' hex value picked from the color wheel. Resolved with
  /// [AppTheme.getRoutineColor] so assigned colors always render.
  final String categoryColorKey;
  final bool selectionMode;
  final bool selected;

  /// Briefly flashes the card (e.g. after jumping here from a search).
  final bool isHighlighted;

  /// Opens the edit dialog for this task (same as tapping the card).
  final VoidCallback? onEdit;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  Timer? _ticker;
  bool _expanded = false;
  bool _loadingSubtasks = false;

  /// Subtask list this card loaded, tagged with the EventBus generation
  /// it was fetched in (see [_invalidateSubtasks]).
  List<Subtask>? _subtasks;
  int _subtasksVersion = 0;
  int _loadedSubtasksVersion = -1;

  @override
  void initState() {
    super.initState();
    _syncTicker();
    // Subtasks can change from anywhere (dialog saves, project kanban,
    // auto-complete rules). Drop the cached list so the next expansion
    // refetches from the database instead of showing stale rows.
    final bus = EventBus.instance;
    bus.subscribe(AppEvent.taskUpdated, _invalidateSubtasks);
    bus.subscribe(AppEvent.taskCreated, _invalidateSubtasks);
    bus.subscribe(AppEvent.subtaskToggled, _invalidateSubtasks);
    bus.subscribe(AppEvent.taskCompleted, _invalidateSubtasks);
    bus.subscribe(AppEvent.taskReopened, _invalidateSubtasks);
  }

  /// EventBus callbacks run synchronously (possibly during dispose of
  /// sibling widgets), so keep them trivial and defer state work.
  void _invalidateSubtasks() {
    _subtasksVersion++;
    if (mounted && _expanded && _subtasks != null && !_loadingSubtasks) {
      scheduleMicrotask(_loadSubtasks);
    }
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.isTimerRunning != widget.task.isTimerRunning ||
        oldWidget.task.timerStartedAt != widget.task.timerStartedAt) {
      _syncTicker();
    }
    if (oldWidget.task.id != widget.task.id) {
      // The element was reused for a different task: forget everything and
      // invalidate any in-flight fetch for the previous task.
      _subtasksVersion++;
      _subtasks = null;
      if (_expanded) _loadSubtasks();
    }
  }

  void _syncTicker() {
    if (widget.task.isTimerRunning && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!widget.task.isTimerRunning && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final bus = EventBus.instance;
    bus.unsubscribe(AppEvent.taskUpdated, _invalidateSubtasks);
    bus.unsubscribe(AppEvent.taskCreated, _invalidateSubtasks);
    bus.unsubscribe(AppEvent.subtaskToggled, _invalidateSubtasks);
    bus.unsubscribe(AppEvent.taskCompleted, _invalidateSubtasks);
    bus.unsubscribe(AppEvent.taskReopened, _invalidateSubtasks);
    super.dispose();
  }

  Future<void> _toggleComplete(Task task) async {
    final provider = context.read<TasksProvider>();
    if (task.status == 'Completed') {
      await provider.reopenTask(task);
    } else {
      await provider.completeTask(task);
    }
  }

  /// The play button starts a focus session on this task (and jumps to
  /// the Focus page); if a session is already running on this task it
  /// stops it. Handles the "another session is running" warning.
  Future<void> _toggleFocus(Task task) {
    return toggleFocusFromTask(
      context,
      taskId: task.id,
      taskTitle: task.title,
    );
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded &&
        !_loadingSubtasks &&
        (_subtasks == null || _loadedSubtasksVersion != _subtasksVersion)) {
      _loadSubtasks();
    }
  }

  Future<void> _loadSubtasks() async {
    final id = widget.task.id;
    final version = _subtasksVersion;
    if (id == null) {
      if (mounted) {
        setState(() {
          _subtasks = const [];
          _loadedSubtasksVersion = version;
        });
      }
      return;
    }
    setState(() => _loadingSubtasks = true);
    final list = await SubtaskRepository().getForTask(id);
    if (!mounted) return;
    if (version != _subtasksVersion) {
      // Subtasks changed (or the card moved to another task) while this
      // fetch was in flight — refetch so we never apply stale rows.
      return _loadSubtasks();
    }
    setState(() {
      _subtasks = list;
      _loadedSubtasksVersion = version;
      _loadingSubtasks = false;
    });
  }

  /// Toggles a subtask's completion. The service auto-completes the task
  /// when all subtasks are done and reopens it when one is un-checked.
  Future<void> _toggleSubtask(Subtask subtask) async {
    final id = subtask.id;
    final taskId = widget.task.id;
    if (id == null || taskId == null) return;
    await context.read<TasksProvider>().toggleSubtask(widget.task, id);
    if (!mounted) return;
    // Keep the dropdown's local state in sync with what we just saved.
    // The subtaskToggled event bumps _subtasksVersion but does not refetch,
    // so only apply this optimistic update when our data is current.
    if (_loadedSubtasksVersion == _subtasksVersion) {
      setState(() {
        _subtasks = _subtasks
            ?.map((s) => s.id == id ? s.copyWith(isCompleted: !s.isCompleted) : s)
            .toList();
      });
    }
  }

  Future<void> _deleteTask() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasksProvider = context.read<TasksProvider>();
    final task = widget.task;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Task'),
        content: Text('Delete "${task.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && task.id != null) {
      await tasksProvider.deleteTask(task.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final task = widget.task;
    final isCompleted = task.status == 'Completed';
    final categoryColor = AppTheme.getRoutineColor(widget.categoryColorKey);
    final priorityColor = AppTheme.getPriorityColor(task.priority);
    // A focus session attached to this task drives the play/stop button
    // (the session also runs the task's own timer).
    final focus = context.watch<FocusProvider>();
    final sessionOnTask = focus.activeSession?.taskId == task.id;

    return Container(
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.selected || widget.isHighlighted
              ? colors.primary
              : colors.border,
          width: widget.selected || widget.isHighlighted ? 2 : 1,
        ),
        boxShadow: widget.isHighlighted
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Category accent bar (left edge)
          Container(width: 5, color: categoryColor),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _badgesRow(
                            colors, categoryColor, priorityColor, isCompleted),
                        const SizedBox(height: 10),
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: colors.textTertiary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.border),
                  _bottomBar(colors, task, sessionOnTask),
                  if (_expanded) ...[
                    Divider(height: 1, color: colors.border),
                    _subtasksSection(colors),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgesRow(AppThemeColors colors, Color categoryColor,
      Color priorityColor, bool isCompleted) {
    return Row(
      children: [
        // Pills share the leftover width and ellipsize, so long category /
        // priority names never overflow the card at any window size.
        Expanded(
          child: Row(
            children: [
              Flexible(child: _pill(categoryColor, widget.categoryName)),
              const SizedBox(width: 6),
              Flexible(child: _pill(priorityColor, widget.task.priority)),
            ],
          ),
        ),
        if (widget.selectionMode)
          Icon(
            widget.selected
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 20,
            color: widget.selected
                ? colors.primary
                : colors.textTertiary,
          )
        else ...[
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: isCompleted ? 'Reopen task' : 'Complete task',
            icon: Icon(
              isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isCompleted ? AppTheme.emerald : colors.textTertiary,
            ),
            onPressed: () => _toggleComplete(widget.task),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit task',
            icon: Icon(Icons.edit_outlined,
                size: 18, color: colors.textSecondary),
            onPressed: widget.onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete task',
            icon: Icon(Icons.delete_outline,
                size: 18, color: colors.textSecondary),
            onPressed: _deleteTask,
          ),
        ],
      ],
    );
  }

  Widget _pill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color.computeLuminance() > 0.6
              ? const Color(0xFF0B1220)
              : Colors.white,
        ),
      ),
    );
  }

  Widget _bottomBar(
      AppThemeColors colors, Task task, bool sessionOnTask) {
    final running = task.isTimerRunning;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            tooltip: sessionOnTask
                ? 'Stop focus session'
                : 'Start focus session',
            icon: Icon(
              sessionOnTask
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 24,
              color: sessionOnTask ? AppTheme.emerald : colors.textSecondary,
            ),
            onPressed: () => _toggleFocus(task),
          ),
          const SizedBox(width: 4),
          Text(
            _format(task.currentTimeSpentSeconds),
            style: TextStyle(
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: running ? AppTheme.emerald : colors.textSecondary,
            ),
          ),
          // Right-aligned status; ellipsizes when the card is narrow so a
          // long custom status never overflows.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                task.status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getStatusColor(task.status),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _toggleExpanded,
            customBorder: const CircleBorder(),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceVariant.withValues(alpha: 0.6),
              ),
              child: Icon(
                _expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtasksSection(AppThemeColors colors) {
    final subtasks = _subtasks;
    final completed =
        subtasks?.where((s) => s.isCompleted).length ?? 0;
    return Container(
      width: double.infinity,
      color: colors.surfaceVariant.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Text(
                  'Subtasks',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                if (subtasks != null && subtasks.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$completed/${subtasks.length} done',
                    style: TextStyle(
                        fontSize: 11, color: colors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (_loadingSubtasks)
            const Padding(
              padding: EdgeInsets.all(10),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (subtasks == null || subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Text('No subtasks',
                  style: TextStyle(
                      fontSize: 12, color: colors.textTertiary)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // All subtask rows render in full; the card's own scroll
              // handles overflow — no nested scroll inside the dropdown.
              child: Column(
                children: [
                  for (final s in subtasks)
                    InkWell(
                      onTap: s.id == null ? null : () => _toggleSubtask(s),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              s.isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color: s.isCompleted
                                  ? AppTheme.emerald
                                  : colors.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.isCompleted
                                      ? colors.textTertiary
                                      : colors.textPrimary,
                                  decoration: s.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }
}
