import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Donut chart of task counts per category plus a color legend.
class CategoryDonut extends StatelessWidget {
  const CategoryDonut({super.key, required this.data, required this.total});

  final Map<String, int> data;
  final int total;

  static List<Color> _palette(AppThemeColors colors) => [
    colors.primary,
    AppTheme.blue,
    AppTheme.emerald,
    AppTheme.amber,
    AppTheme.rose,
    AppTheme.purple,
    AppTheme.sky,
    AppTheme.orange,
    AppTheme.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final entries = data.entries.toList();

    final sections = [
      for (var i = 0; i < entries.length; i++)
        PieChartSectionData(
          value: entries[i].value.toDouble(),
          color: _palette(colors)[i % 9],
          radius: 54,
          showTitle: entries.length <= 7 && total > 0,
          title: total > 0
              ? '${(entries[i].value / total * 100).round()}%'
              : '',
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
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
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (total == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No tasks yet',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 150,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 32,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _palette(colors)[i % 9],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entries[i].key,
                        style: TextStyle(
                            fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
