import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../providers/calendar_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'calendar_utils.dart';

const List<String> _weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Month grid: a 6×7 calendar where each day lists up to three task chips
/// (draggable onto other days to reschedule). Tapping an empty part of a
/// day opens that day's detail view; tapping a chip edits the task.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.provider,
    required this.onReschedule,
    required this.onSelectDay,
    required this.onEditTask,
  });

  final CalendarProvider provider;
  final void Function(Task task, DateTime date) onReschedule;
  final void Function(DateTime date) onSelectDay;
  final void Function(Task task) onEditTask;

  DateTime get _gridStart {
    final first = DateTime(
        provider.viewingMonth.year, provider.viewingMonth.month, 1);
    return first.subtract(Duration(days: first.weekday % 7));
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
              for (final name in _weekdayNames)
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 118,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final date = _gridStart.add(Duration(days: index));
              final tasks = _dayTasks(date);
              return _DayCell(
                date: date,
                inMonth: date.month == provider.viewingMonth.month,
                isToday: _isSameDay(date, DateTime.now()),
                isSelected: _isSameDay(date, provider.selectedDate),
                tasks: tasks,
                onReschedule: onReschedule,
                onSelectDay: onSelectDay,
                onEditTask: onEditTask,
              );
            },
          ),
        ),
      ],
    );
  }

  List<Task> _dayTasks(DateTime date) {
    final tasks = provider.monthTasks[dateKey(date)] ?? const <Task>[];
    final sorted = List<Task>.of(tasks)
      ..sort((a, b) {
        final byTime = (a.scheduledTime ?? '')
            .compareTo(b.scheduledTime ?? '');
        if (byTime != 0) return byTime;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    return sorted;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.tasks,
    required this.onReschedule,
    required this.onSelectDay,
    required this.onEditTask,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<Task> tasks;
  final void Function(Task task, DateTime date) onReschedule;
  final void Function(DateTime date) onSelectDay;
  final void Function(Task task) onEditTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return DragTarget<Task>(
      onAcceptWithDetails: (details) => onReschedule(details.data, date),
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return InkWell(
          onTap: () => onSelectDay(date),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: hovering
                  ? colors.surfaceVariant
                  : (inMonth ? colors.surface : colors.background),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : (hovering
                        ? AppTheme.primary.withValues(alpha: 0.6)
                        : colors.border),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: isSelected
                          ? BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? AppTheme.primary
                                  : (inMonth
                                      ? colors.textPrimary
                                      : colors.textTertiary),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!inMonth)
                      Icon(Icons.circle, size: 4, color: colors.textTertiary),
                  ],
                ),
                const SizedBox(height: 2),
                for (final task in tasks.take(3)) ...[
                  _MonthTaskChip(task: task, onTap: () => onEditTask(task)),
                  const SizedBox(height: 2),
                ],
                if (tasks.length > 3)
                  Text(
                    '+${tasks.length - 3} more',
                    style: TextStyle(
                        fontSize: 9, color: colors.textTertiary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact task chip inside a month cell: draggable to reschedule,
/// tappable to edit.
class _MonthTaskChip extends StatelessWidget {
  const _MonthTaskChip({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final statusColor = AppTheme.getStatusColor(task.status);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: statusColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          if (task.status == 'Completed') ...[
            Icon(Icons.check_circle, size: 9, color: statusColor),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: chip,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}
