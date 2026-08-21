import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'task_details_dialog.dart';

/// Horizontally scrollable kanban board for the active project. Columns
/// come from the project's custom statuses ([columns], in order) or fall
/// back to [defaultColumns]; tasks are dragged between them and
/// [onMoveTask] persists the status via the provider.
class KanbanBoard extends StatefulWidget {
  const KanbanBoard({
    super.key,
    required this.tasks,
    required this.columns,
    required this.onMoveTask,
  });

  final List<Task> tasks;
  final List<({String name, String colorKey})> columns;
  final void Function(Task task, String status) onMoveTask;

  /// Built-in columns used by projects without custom statuses.
  static const List<({String name, String colorKey})> defaultColumns = [
    (name: 'Pending', colorKey: 'slate'),
    (name: 'In Progress', colorKey: 'blue'),
    (name: 'Completed', colorKey: 'emerald'),
  ];

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _hScroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < columns.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    SizedBox(
                      width: 280,
                      child: _KanbanColumn(
                        status: columns[i].name,
                        accent:
                            AppTheme.getRoutineColor(columns[i].colorKey),
                        tasks: widget.tasks
                            .where((t) => t.status == columns[i].name)
                            .toList(),
                        onDropTask: widget.onMoveTask,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.accent,
    required this.tasks,
    required this.onDropTask,
  });

  final String status;
  final Color accent;
  final List<Task> tasks;
  final void Function(Task task, String status) onDropTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        final task = details.data;
        if (task.status != status) onDropTask(task, status);
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Container(
          height: double.infinity,
          decoration: BoxDecoration(
            color: hovering
                ? colors.surfaceVariant.withValues(alpha: 0.7)
                : colors.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hovering ? accent : colors.border,
              width: hovering ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 12),
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          hovering ? 'Drop here' : 'No tasks',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Draggable<Task>(
                              data: task,
                              dragAnchorStrategy:
                                  pointerDragAnchorStrategy,
                              feedback: _feedback(task),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _KanbanTaskCard(task: task),
                              ),
                              // Double-click opens the task details
                              // popup (title, description, subtasks).
                              child: GestureDetector(
                                onDoubleTap: () =>
                                    _openTaskDetails(context, task),
                                child: _KanbanTaskCard(task: task),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens the task details popup (double-click on a card).
  Future<void> _openTaskDetails(BuildContext context, Task task) {
    return showDialog<void>(
      context: context,
      builder: (_) => TaskDetailsDialog(task: task),
    );
  }

  Widget _feedback(Task task) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary, width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.getPriorityColor(task.priority),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact task card inside a kanban column.
class _KanbanTaskCard extends StatelessWidget {
  const _KanbanTaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.getPriorityColor(task.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.scheduledDate != null) ...[
                      Icon(Icons.event,
                          size: 12, color: colors.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('MMM d').format(task.scheduledDate!),
                        style: TextStyle(
                            fontSize: 11, color: colors.textTertiary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (task.scheduledTime != null)
                      Text(
                        task.scheduledTime!,
                        style: TextStyle(
                            fontSize: 11, color: colors.textTertiary),
                      ),
                    if (task.isTimerRunning) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer,
                          size: 12, color: AppTheme.emerald),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
