import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'calendar_utils.dart';

/// Agenda view: the viewing month's tasks in a chronological,
/// date-grouped list. Each section is collapsible; tapping a task edits it.
class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.provider,
    required this.onEditTask,
  });

  final CalendarProvider provider;
  final void Function(Task task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = provider.agendaTasks;

    if (tasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks scheduled in ${DateFormat('MMMM yyyy').format(provider.viewingMonth)}',
          style: TextStyle(color: colors.textTertiary),
        ),
      );
    }

    // Group by date, preserving chronological order.
    final grouped = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final date = task.scheduledDate!;
      grouped.putIfAbsent(
          DateTime(date.year, date.month, date.day), () => []).add(task);
    }
    final dates = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final dayTasks = grouped[date]!;
        final isToday = _isSameDay(date, DateTime.now());
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colors.border),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: colors.border),
            ),
            backgroundColor: colors.surface,
            collapsedBackgroundColor: colors.surface,
            leading: Icon(
              isToday ? Icons.today : Icons.event,
              size: 18,
              color: isToday ? colors.primary : colors.textSecondary,
            ),
            title: Text(
              DateFormat('EEEE, MMM d').format(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isToday ? colors.primary : colors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${dayTasks.length} task${dayTasks.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
            children: [
              for (final task in dayTasks)
                _AgendaTaskRow(task: task, onTap: () => onEditTask(task)),
            ],
          ),
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _AgendaTaskRow extends StatelessWidget {
  const _AgendaTaskRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final statusColor = AppTheme.getStatusColor(task.status);
    final time = formatTime(task.scheduledTime);
    final isDone = task.status == 'Completed';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                time.isEmpty ? '—' : time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                ),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
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
                  color: colors.textPrimary,
                  decoration:
                      isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isDone)
              Icon(Icons.check_circle, size: 15, color: AppTheme.emerald),
          ],
        ),
      ),
    );
  }
}
