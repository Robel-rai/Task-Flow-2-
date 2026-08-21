import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Bar chart of focus minutes per day over the last 7 (week) or 30
/// (month) days. [minutesPerDay] is keyed `yyyy-MM-dd`.
class FocusTimeChart extends StatefulWidget {
  const FocusTimeChart({super.key, required this.minutesPerDay});

  final Map<String, int> minutesPerDay;

  @override
  State<FocusTimeChart> createState() => _FocusTimeChartState();
}

class _FocusTimeChartState extends State<FocusTimeChart> {
  bool _monthView = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final today = DateTime.now();
    final days = _monthView ? 30 : 7;
    final start = DateTime(today.year, today.month, today.day - (days - 1));

    final values = <(DateTime, int)>[];
    var hasFocus = false;
    for (var i = 0; i < days; i++) {
      final date = DateTime(start.year, start.month, start.day + i);
      final minutes = widget.minutesPerDay[_dayKey(date)] ?? 0;
      if (minutes > 0) hasFocus = true;
      values.add((date, minutes));
    }
    final maxValue = values.fold<int>(0, (m, v) => v.$2 > m ? v.$2 : m);
    final maxY =
        (maxValue < 30 ? 30.0 : maxValue * 1.2).clamp(10.0, 100000.0).toDouble();

    final groups = [
      for (var i = 0; i < values.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i].$2.toDouble(),
              color: AppTheme.primary,
              width: _monthView ? 6 : 16,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3)),
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
          Row(
            children: [
              Expanded(
                child: Text('Focus Time',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Week')),
                  ButtonSegment(value: true, label: Text('Month')),
                ],
                selected: {_monthView},
                onSelectionChanged: (selection) =>
                    setState(() => _monthView = selection.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasFocus)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No focus sessions in this period',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  barGroups: groups,
                  gridData: const FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 30,
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
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) => Text(
                          '${value.toInt()}m',
                          style: TextStyle(
                              fontSize: 9, color: colors.textTertiary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: _monthView ? 4 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= values.length) {
                            return const SizedBox.shrink();
                          }
                          final date = values[index].$1;
                          final label = _monthView
                              ? '${date.day}'
                              : DateFormat('E').format(date);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: TextStyle(
                                  fontSize: 9, color: colors.textTertiary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => colors.surfaceVariant,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${rod.toY.toInt()}m · '
                        '${DateFormat('MMM d').format(values[groupIndex].$1)}',
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

  static String _dayKey(DateTime d) => d.toIso8601String().split('T').first;
}
