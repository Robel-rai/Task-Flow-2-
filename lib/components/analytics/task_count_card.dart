import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Card showing total / completed / pending task counts with colored badges.
class TaskCountCard extends StatelessWidget {
  const TaskCountCard({
    super.key,
    required this.total,
    required this.completed,
    required this.pending,
  });

  final int total;
  final int completed;
  final int pending;

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
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: AppTheme.indigo),
              const SizedBox(width: 8),
              Text('Task Overview',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _CountPill(
                label: 'Total',
                count: total,
                color: colors.textSecondary,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _CountPill(
                label: 'Done',
                count: completed,
                color: AppTheme.emerald,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _CountPill(
                label: 'Pending',
                count: pending,
                color: AppTheme.amber,
                colors: colors,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? completed / total : 0,
              backgroundColor: colors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppTheme.emerald),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            total > 0
                ? '${(completed / total * 100).round()}% completion rate'
                : 'No tasks yet',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.label,
    required this.count,
    required this.color,
    required this.colors,
  });

  final String label;
  final int count;
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
              '$count',
              style: TextStyle(
                fontSize: 20,
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
