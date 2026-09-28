import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/focus_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/focus_actions.dart';

/// Horizontal list row for a task (list view). Shares the scoped ticker
/// approach with [TaskCard].
class ListTaskItem extends StatefulWidget {
  const ListTaskItem({
    super.key,
    required this.task,
    this.categoryName = 'General',
    this.selectionMode = false,
    this.selected = false,
    this.isHighlighted = false,
  });

  final Task task;
  final String categoryName;
  final bool selectionMode;
  final bool selected;

  /// Briefly flashes the row (e.g. after jumping here from a search).
  final bool isHighlighted;

  @override
  State<ListTaskItem> createState() => _ListTaskItemState();
}

class _ListTaskItemState extends State<ListTaskItem> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ListTaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.isTimerRunning != widget.task.isTimerRunning ||
        oldWidget.task.timerStartedAt != widget.task.timerStartedAt) {
      _syncTicker();
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final task = widget.task;
    final isCompleted = task.status == 'Completed';
    // A focus session attached to this task drives the play/stop button
    // (the session also runs the task's own timer).
    final sessionOnTask = context.watch<FocusProvider>().activeSession?.taskId == task.id;

    return Container(
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? colors.primary.withValues(alpha: 0.06)
            : colors.surface,
        borderRadius: BorderRadius.circular(10),
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
        children: [
          Container(width: 4, height: 56, color: AppTheme.getPriorityColor(task.priority)),
          const SizedBox(width: 12),
          widget.selectionMode
              ? Icon(
                  widget.selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: widget.selected
                      ? colors.primary
                      : colors.textTertiary,
                )
              : InkWell(
                  onTap: () => _toggleComplete(task),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color:
                        isCompleted ? AppTheme.emerald : colors.textTertiary,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _metaLine(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          if (task.scheduledDate != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                DateFormat('MMM d').format(task.scheduledDate!),
                style: TextStyle(fontSize: 11, color: colors.textSecondary),
              ),
            ),
          if (task.timeSpentSeconds > 0 || task.isTimerRunning)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                task.isTimerRunning
                    ? _format(task.currentTimeSpentSeconds)
                    : task.formattedTimeFriendly,
                style: TextStyle(
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color:
                      task.isTimerRunning ? AppTheme.emerald : colors.textSecondary,
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: sessionOnTask
                ? 'Stop focus session'
                : 'Start focus session',
            icon: Icon(
              sessionOnTask
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline,
              size: 22,
              color: sessionOnTask ? AppTheme.emerald : colors.textSecondary,
            ),
            onPressed: () => _toggleFocus(task),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _metaLine(Task task) {
    final parts = <String>[widget.categoryName, task.priority, task.status];
    return parts.join(' · ');
  }

  static String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}
