import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Horizontal bar chart showing top 5 categories by task count,
/// with completed vs total breakdown.
class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key, required this.performance});

  /// (category name, total tasks, completed tasks), largest first.
  final List<(String, int, int)> performance;

  static const _barColors = [
    AppTheme.primary,
    AppTheme.blue,
    AppTheme.indigo,
    AppTheme.purple,
    AppTheme.sky,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final entries = performance.where((p) => p.$2 > 0).take(5).toList();
    final maxTotal =
        entries.isEmpty ? 1 : entries.map((e) => e.$2).reduce((a, b) => a > b ? a : b);

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
              Icon(Icons.leaderboard_outlined, size: 18, color: AppTheme.blue),
              const SizedBox(width: 8),
              Text('Top Categories',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tasks completed by category',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No categories yet',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryBar(
                  name: entries[i].$1,
                  completed: entries[i].$3,
                  total: entries[i].$2,
                  fraction: maxTotal > 0 ? entries[i].$2 / maxTotal : 0,
                  color: _barColors[i % _barColors.length],
                  colors: colors,
                ),
              ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.name,
    required this.completed,
    required this.total,
    required this.fraction,
    required this.color,
    required this.colors,
  });

  final String name;
  final int completed;
  final int total;
  final double fraction;
  final Color color;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              '$completed / $total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Filled portion
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
