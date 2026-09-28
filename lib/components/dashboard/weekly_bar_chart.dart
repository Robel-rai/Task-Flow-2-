import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Bar chart of completed tasks per day of the current week.
/// [data] is keyed 0 = Monday … 6 = Sunday.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.data});

  final Map<int, int> data;

  static const List<String> _dayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final maxValue = data.values.fold<int>(0, (m, v) => v > m ? v : m);
    final maxY = maxValue < 4 ? 4.0 : maxValue * 1.3;

    final groups = [
      for (var i = 0; i < 7; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (data[i] ?? 0).toDouble(),
              color: colors.primary,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4)),
            ),
          ],
        ),
    ];

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
          Text('Weekly Completions',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                barGroups: groups,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colors.border.withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style:
                            TextStyle(fontSize: 10, color: colors.textTertiary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _dayLabels[value.toInt().clamp(0, 6)],
                          style: TextStyle(
                              fontSize: 10, color: colors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.surfaceVariant,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem(
                      '${rod.toY.toInt()} completed',
                      TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
