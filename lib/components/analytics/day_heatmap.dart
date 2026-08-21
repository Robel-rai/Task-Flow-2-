import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Horizontal row of 7 circles (Mon–Sun) where color intensity represents
/// how many tasks were completed on that day historically.
class DayHeatmap extends StatelessWidget {
  const DayHeatmap({super.key, required this.dayOfWeekCompletion});

  /// Completed task count per day-of-week (0=Mon … 6=Sun).
  final Map<int, int> dayOfWeekCompletion;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final maxCount = dayOfWeekCompletion.values.isEmpty
        ? 1
        : dayOfWeekCompletion.values.reduce((a, b) => a > b ? a : b);

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
              Icon(Icons.grid_view, size: 18, color: AppTheme.amber),
              const SizedBox(width: 8),
              Text('Weekly Pattern',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Your most productive days',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final count = dayOfWeekCompletion[i] ?? 0;
              final intensity = maxCount > 0 ? count / maxCount : 0.0;
              return _HeatDot(
                label: _dayLabels[i],
                count: count,
                intensity: intensity,
                colors: colors,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _HeatDot extends StatelessWidget {
  const _HeatDot({
    required this.label,
    required this.count,
    required this.intensity,
    required this.colors,
  });

  final String label;
  final int count;
  final double intensity;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    // Interpolate from surfaceVariant (low) to emerald (high).
    final bgColor = Color.lerp(
      colors.surfaceVariant,
      AppTheme.emerald,
      intensity.clamp(0.0, 1.0),
    )!;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: count > 0
                ? Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: intensity > 0.5 ? Colors.white : colors.textSecondary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
