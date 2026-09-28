import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The five most recently created tasks with quick complete/reopen.
class RecentTasks extends StatelessWidget {
  const RecentTasks({
    super.key,
    required this.tasks,
    this.categoryNames = const {},
  });

  final List<Task> tasks;
  final Map<int, String> categoryNames;

  Future<void> _toggle(BuildContext context, Task task) async {
    final provider = context.read<TasksProvider>();
    if (task.status == 'Completed') {
      await provider.reopenTask(task);
    } else {
      await provider.completeTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Tasks', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No tasks yet — add your first one above',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            ...tasks.map((task) => _TaskRow(
                  task: task,
                  categoryName:
                      task.categoryId != null ? categoryNames[task.categoryId] ?? 'General' : 'General',
                  onToggle: () => _toggle(context, task),
                )),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.categoryName,
    required this.onToggle,
  });

  final Task task;
  final String categoryName;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCompleted = task.status == 'Completed';
    final priorityColor = AppTheme.getPriorityColor(task.priority);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: isCompleted ? AppTheme.emerald : colors.textTertiary,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                _scheduleMeta(colors, task),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _chip(colors, colors.primary, categoryName),
          const SizedBox(width: 6),
          _chip(colors, priorityColor, task.priority),
          if (task.timeSpentSeconds > 0) ...[
            const SizedBox(width: 6),
            _chip(colors, colors.textSecondary, task.formattedTimeFriendly),
          ],
        ],
      ),
    );
  }

  Widget _scheduleMeta(AppThemeColors colors, Task task) {
    final parts = <String>[];
    if (task.scheduledDate != null) {
      parts.add(DateFormat('MMM d').format(task.scheduledDate!));
    }
    if (task.scheduledTime != null) {
      parts.add(task.scheduledTime!);
    }
    if (task.dueDate != null) {
      parts.add('Due ${DateFormat('MMM d').format(task.dueDate!)}');
    }
    return Text(
      parts.isEmpty ? 'No schedule' : parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, color: colors.textTertiary),
    );
  }

  Widget _chip(AppThemeColors colors, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
