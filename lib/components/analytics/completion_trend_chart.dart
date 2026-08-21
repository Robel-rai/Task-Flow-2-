import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Line chart of tasks completed per day over the last 30 days.
/// [completionPerDay] is keyed `yyyy-MM-dd`.
class CompletionTrendChart extends StatelessWidget {
  const CompletionTrendChart({super.key, required this.completionPerDay});

  final Map<String, int> completionPerDay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day - 29);

    final values = <(DateTime, int)>[];
    var hasData = false;
    for (var i = 0; i < 30; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final count = completionPerDay[_dayKey(date)] ?? 0;
      if (count > 0) hasData = true;
      values.add((date, count));
    }
    final maxValue = values.fold<int>(0, (m, v) => v.$2 > m ? v.$2 : m);
    final maxY = (maxValue < 5 ? 5.0 : (maxValue * 1.3)).toDouble();

    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i].$2.toDouble()),
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
          Row(
            children: [
              Icon(Icons.show_chart, size: 18, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text('Completion Trend',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('Last 30 days',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No completions in this period',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 10 ? (maxY / 4).ceilToDouble() : 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colors.border.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: maxY > 10 ? (maxY / 4).ceilToDouble() : 2,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}',
                          style: TextStyle(
                              fontSize: 9, color: colors.textTertiary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= values.length) {
                            return const SizedBox.shrink();
                          }
                          final date = values[index].$1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                  fontSize: 9, color: colors.textTertiary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => colors.surfaceVariant,
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${s.y.toInt()} task${s.y.toInt() == 1 ? '' : 's'}\n${DateFormat('MMM d').format(values[s.x.toInt()].$1)}',
                                TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary),
                              ))
                          .toList(),
                    ),
                    handleBuiltInTouches: true,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.emerald,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppTheme.emerald,
                          strokeWidth: 1.5,
                          strokeColor: colors.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.emerald.withValues(alpha: 0.3),
                            AppTheme.emerald.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _dayKey(DateTime d) => d.toIso8601String().split('T').first;
}
