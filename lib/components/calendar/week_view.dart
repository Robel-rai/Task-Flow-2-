import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'calendar_utils.dart';

const List<String> _shortNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Week view: seven day columns (Sunday-first). Tasks appear as chips
/// sorted by scheduled time; dragging a chip onto another column
/// reschedules the task to that day. Tapping a chip edits the task.
class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.provider,
    required this.onReschedule,
    required this.onEditTask,
  });

  final CalendarProvider provider;
  final void Function(Task task, DateTime date) onReschedule;
  final void Function(Task task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final start = provider.weekStart;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _DayColumn(
              date: start.add(Duration(days: i)),
              tasks: _columnTasks(start.add(Duration(days: i))),
              isToday: _isSameDay(start.add(Duration(days: i)), DateTime.now()),
              onReschedule: onReschedule,
              onEditTask: onEditTask,
            ),
          ),
      ],
    );
  }

  List<Task> _columnTasks(DateTime date) {
    final key = dateKey(date);
    final tasks =
        provider.weekTasks.where((t) => dateKey(t.scheduledDate!) == key).toList()
          ..sort((a, b) {
            final byTime = (a.scheduledTime ?? '')
                .compareTo(b.scheduledTime ?? '');
            if (byTime != 0) return byTime;
            return a.sortOrder.compareTo(b.sortOrder);
          });
    return tasks;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.onReschedule,
    required this.onEditTask,
  });

  final DateTime date;
  final List<Task> tasks;
  final bool isToday;
  final void Function(Task task, DateTime date) onReschedule;
  final void Function(Task task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return DragTarget<Task>(
      onAcceptWithDetails: (details) => onReschedule(details.data, date),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hovering
                ? colors.surfaceVariant
                : colors.background.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovering
                  ? AppTheme.primary.withValues(alpha: 0.6)
                  : colors.border,
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _shortNames[date.weekday % 7],
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.textTertiary),
                    ),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppTheme.primary
                            : colors.textPrimary,
                      ),
                    ),
                    Text(
                      '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 9, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Task list
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Text(
                          '—',
                          style: TextStyle(color: colors.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _WeekTaskChip(
                            task: tasks[index],
                            onTap: () => onEditTask(tasks[index]),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekTaskChip extends StatelessWidget {
  const _WeekTaskChip({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final statusColor = AppTheme.getStatusColor(task.status);
    final time = formatTime(task.scheduledTime);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(color: statusColor, width: 2.5),
        ),
      ),
      child: Row(
        children: [
          if (task.status == 'Completed')
            Icon(Icons.check_circle, size: 12, color: statusColor)
          else
            Icon(Icons.circle, size: 7, color: statusColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
                decoration: task.status == 'Completed'
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              time,
              style: TextStyle(fontSize: 9, color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: chip,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
