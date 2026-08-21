import 'package:flutter/material.dart';

import '../../models/routine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Full routine card: completion toggle (enabled only on scheduled days),
/// day-of-week letter chips, streak, time, and edit/delete actions.
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.activeToday,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final bool activeToday;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const List<String> _dayLabels = [
    'M', 'T', 'W', 'T', 'F', 'S', 'S',
  ];

  /// Formats the routine's scheduled time as e.g. '8:00 AM'.
  static String formatTime(Routine routine) {
    final t = routine.timeOfDay;
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final routineColor = AppTheme.getRoutineColor(routine.color);
    final isCompleted = routine.isCompletedToday;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // Completion toggle — only meaningful on scheduled days.
          InkWell(
            onTap: activeToday ? onToggle : null,
            borderRadius: BorderRadius.circular(20),
            child: Icon(
              isCompleted
                  ? Icons.check_circle
                  : activeToday
                      ? Icons.radio_button_unchecked
                      : Icons.remove_circle_outline,
              size: 22,
              color: isCompleted
                  ? routineColor
                  : activeToday
                      ? colors.textTertiary
                      : colors.textTertiary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          // Color accent bar
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: routineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        routine.title,
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
                    ),
                    if (routine.streak > 0) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department,
                              size: 14, color: AppTheme.amber),
                          const SizedBox(width: 3),
                          Text(
                            '${routine.streak} day streak',
                            style: TextStyle(
                                fontSize: 11, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 13, color: colors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      formatTime(routine),
                      style:
                          TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    // Day letters
                    for (var i = 0; i < 7; i++) ...[
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: routine.daysOfWeek.contains(i + 1)
                              ? routineColor.withValues(alpha: 0.18)
                              : colors.surfaceVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _dayLabels[i],
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: routine.daysOfWeek.contains(i + 1)
                                ? routineColor
                                : colors.textTertiary
                                    .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      if (i < 6) const SizedBox(width: 3),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit routine',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined,
                size: 18, color: colors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete routine',
            visualDensity: VisualDensity.compact,
            icon:
                Icon(Icons.delete_outline, size: 18, color: colors.textTertiary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
