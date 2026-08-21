import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Card summarizing time tracking: total hours, avg per task,
/// and the most time-consuming task.
class TimeSummaryCard extends StatelessWidget {
  const TimeSummaryCard({
    super.key,
    required this.totalHours,
    required this.completedTasks,
    required this.mostTimeTaskTitle,
    required this.mostTimeTaskSeconds,
  });

  final double totalHours;
  final int completedTasks;
  final String? mostTimeTaskTitle;
  final int mostTimeTaskSeconds;

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0) return '${m}m';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final avgPerTask =
        completedTasks > 0 ? totalHours / completedTasks : 0.0;

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
              Icon(Icons.hourglass_bottom, size: 18, color: AppTheme.indigo),
              const SizedBox(width: 8),
              Text('Time Tracking',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _TimeMetric(
                label: 'Total',
                value: '${totalHours.toStringAsFixed(1)}h',
                color: AppTheme.indigo,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _TimeMetric(
                label: 'Avg / task',
                value: avgPerTask > 0 ? '${avgPerTask.toStringAsFixed(1)}h' : '—',
                color: AppTheme.blue,
                colors: colors,
              ),
            ],
          ),
          if (mostTimeTaskTitle != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: AppTheme.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most time spent',
                          style: TextStyle(
                              fontSize: 10, color: colors.textTertiary),
                        ),
                        Text(
                          mostTimeTaskTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDuration(mostTimeTaskSeconds),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  final String label;
  final String value;
  final Color color;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
