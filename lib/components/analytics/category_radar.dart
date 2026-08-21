import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Radar chart showing each category's completion rate (0–100%). Takes
/// the top 6 categories by task count; at least 3 are required to draw.
class CategoryRadar extends StatelessWidget {
  const CategoryRadar({super.key, required this.performance});

  /// (category name, total tasks, completed tasks), largest first.
  final List<(String, int, int)> performance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final entries =
        performance.where((p) => p.$2 > 0).take(6).toList();
    final canDraw = entries.length >= 3;

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
          Text('Category Performance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Completion rate by category',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 16),
          if (!canDraw)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  entries.isEmpty
                      ? 'No tasks yet'
                      : 'Add tasks in 3+ categories to see the radar',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  dataSets: [
                    RadarDataSet(
                      dataEntries: [
                        for (final p in entries)
                          RadarEntry(value: (p.$3 / p.$2 * 100).clamp(0, 100)),
                      ],
                      fillColor: AppTheme.primary.withValues(alpha: 0.25),
                      borderColor: AppTheme.primary,
                      borderWidth: 2,
                      entryRadius: 3,
                    ),
                  ],
                  tickCount: 4,
                  ticksTextStyle: TextStyle(
                      fontSize: 8, color: colors.textTertiary),
                  gridBorderData: BorderSide(color: colors.border),
                  radarBorderData: BorderSide(color: colors.border),
                  tickBorderData:
                      BorderSide(color: colors.border.withValues(alpha: 0.5)),
                  borderData: FlBorderData(show: false),
                  getTitle: (index, angle) => RadarChartTitle(
                    text: entries[index].$1,
                    angle: angle,
                  ),
                  titleTextStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
