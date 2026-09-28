import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Tasks scheduled for today with one-click complete/reopen.
class TodayAgenda extends StatelessWidget {
  const TodayAgenda({
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
    final pendingCount = tasks.where((t) => t.status != 'Completed').length;

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
          Row(
            children: [
              Text("Today's Agenda",
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '$pendingCount of ${tasks.length} pending',
                style: TextStyle(fontSize: 12, color: colors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Nothing scheduled for today',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            ...tasks.map((task) => _AgendaRow(
                  task: task,
                  categoryNames: categoryNames,
                  onToggle: () => _toggle(context, task),
                )),
        ],
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({
    required this.task,
    this.categoryNames = const {},
    required this.onToggle,
  });

  final Task task;
  final Map<int, String> categoryNames;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCompleted = task.status == 'Completed';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isCompleted ? AppTheme.emerald : colors.textTertiary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.getPriorityColor(task.priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
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
          ),
          if (task.scheduledTime != null)
            Text(
              task.scheduledTime!,
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            )
          else if (task.scheduledDate != null)
            Text(
              DateFormat('MMM d').format(task.scheduledDate!),
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
          if (task.categoryId != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                categoryNames[task.categoryId] ?? 'General',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
