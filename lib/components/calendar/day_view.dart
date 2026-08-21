import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'calendar_utils.dart';

/// Day view: the selected day's tasks as a reorderable list (drag order
/// persists via sort_order), with quick-complete, edit-on-tap, and an
/// add-task-on-this-day button.
class DayView extends StatefulWidget {
  const DayView({
    super.key,
    required this.date,
    required this.tasks,
    required this.onReorder,
    required this.onToggleComplete,
    required this.onEditTask,
    required this.onAddTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(List<int> orderedIds) onReorder;
  final void Function(Task task) onToggleComplete;
  final void Function(Task task) onEditTask;
  final VoidCallback onAddTask;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late List<Task> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Task>.of(widget.tasks);
  }

  @override
  void didUpdateWidget(DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _items = List<Task>.of(widget.tasks);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final task = _items.removeAt(oldIndex);
      _items.insert(newIndex, task);
    });
    widget.onReorder([for (final t in _items) t.id!]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(widget.date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${_items.length} task${_items.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onAddTask,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add task on this day'),
            ),
          ),
        ),
        Expanded(
          child: _items.isEmpty
              ? Center(
                  child: Text(
                    'No tasks scheduled for this day',
                    style: TextStyle(color: colors.textTertiary),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final task = _items[index];
                    return Padding(
                      key: ValueKey(task.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TaskRow(
                        index: index,
                        task: task,
                        onEdit: () => widget.onEditTask(task),
                        onToggleComplete: () =>
                            widget.onToggleComplete(task),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.index,
    required this.task,
    required this.onEdit,
    required this.onToggleComplete,
  });

  final int index;
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final statusColor = AppTheme.getStatusColor(task.status);
    final time = formatTime(task.scheduledTime);
    final isDone = task.status == 'Completed';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              // Drag handle (desktop: mouse-draggable, no long-press).
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator,
                        size: 18, color: colors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onToggleComplete,
                borderRadius: BorderRadius.circular(12),
                child: Icon(
                  isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isDone ? AppTheme.emerald : colors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.description.isNotEmpty)
                      Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: colors.textTertiary),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  time.isEmpty ? '—' : time,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
